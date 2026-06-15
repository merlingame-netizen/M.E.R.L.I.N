"use strict";
// Self-contained integration test: spawns the backend as a child process, loads the
// browser firebase-shim.js in this Node process (polyfilling globals), and exercises
// the RTDB/Auth/Storage surface the app relies on. Run: node --experimental-sqlite shimtest.js
const { spawn } = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");

const PORT = 8799;
const BASE = "http://127.0.0.1:" + PORT;
const tmpDb = path.join(os.tmpdir(), "shimtest-" + Date.now() + ".db");
const tmpStore = path.join(os.tmpdir(), "shimtest-store-" + Date.now());

const results = [];
function check(name, cond) { results.push([name, !!cond]); console.log((cond ? "  PASS  " : "  FAIL  ") + name); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitHealthy(tries) {
  for (let i = 0; i < tries; i++) {
    try { const r = await fetch(BASE + "/health"); if (r.ok) return true; } catch (e) {}
    await sleep(150);
  }
  return false;
}

async function main() {
  const srv = spawn(process.execPath, ["--experimental-sqlite", path.join(__dirname, "server.js")], {
    env: { ...process.env, PORT: String(PORT), DB_FILE: tmpDb, STORAGE_DIR: tmpStore },
    stdio: ["ignore", "pipe", "pipe"],
  });
  srv.stdout.on("data", (d) => process.stdout.write("[srv] " + d));
  srv.stderr.on("data", (d) => { const s = String(d); if (!/ExperimentalWarning|trace-warnings/.test(s)) process.stderr.write("[srv!] " + s); });

  const ok = await waitHealthy(40);
  if (!ok) { console.error("server never became healthy"); srv.kill("SIGKILL"); process.exit(1); }

  // polyfill browser globals the shim expects
  globalThis.WebSocket = require("ws").WebSocket;
  globalThis.AIA_BACKEND = BASE;
  const mem = {}; globalThis.localStorage = { getItem: (k) => (k in mem ? mem[k] : null), setItem: (k, v) => { mem[k] = String(v); } };

  // load the shim (defines globalThis.firebase)
  require(path.join(__dirname, "..", "web", "firebase-shim.js"));
  const firebase = globalThis.firebase;
  firebase.initializeApp({});
  const db = firebase.database();

  try {
    // 1) on('value'): initial null then live update. Wait for the WS-delivered initial
    // event before writing, so the assertion doesn't race the WS handshake.
    let liveVal = "UNSET";
    let initialVal = "UNSET";
    let firstFired = false;
    const ref1 = db.ref("test/live");
    const cb = ref1.on("value", (snap) => { if (!firstFired) { firstFired = true; initialVal = snap.val(); } else { liveVal = snap.val(); } });
    for (let i = 0; i < 40 && !firstFired; i++) await sleep(50);
    check("on(value) initial null", firstFired && initialVal === null);
    await db.ref("test/live").set({ name: "Zoe", xp: 5 });
    await sleep(400);
    check("on(value) live update received", liveVal && liveVal.name === "Zoe" && liveVal.xp === 5);
    ref1.off("value", cb);

    // 2) push().key + awaitable
    const pushed = db.ref("test/msgs").push({ text: "hi" });
    check("push().key present", typeof pushed.key === "string" && pushed.key.length === 20);
    await pushed; // awaitable like firebase
    const back = await db.ref("test/msgs/" + pushed.key).once("value");
    check("push value readable", back.val() && back.val().text === "hi");

    // 3) transaction increment (CAS)
    await db.ref("test/counter").set({ points: 0 });
    const tx = await db.ref("test/counter").transaction((cur) => { cur = cur || { points: 0 }; cur.points++; return cur; });
    check("transaction committed", tx.committed === true);
    const c2 = await db.ref("test/counter").once("value");
    check("transaction value persisted", c2.val() && c2.val().points === 1);

    // 4) storage roundtrip
    const sref = firebase.storage().ref("avatars/zoe.txt");
    await sref.put("hello-bytes");
    const urlp = await sref.getDownloadURL();
    const got = await (await fetch(urlp)).text();
    check("storage roundtrip", got === "hello-bytes");

    // 5) query orderByChild.equalTo.limitToLast
    await db.ref("test/players").set({
      a: { name: "A", level: 7 }, b: { name: "B", level: 7 }, c: { name: "C", level: 3 },
    });
    const qs = await db.ref("test/players").orderByChild("level").equalTo(7).limitToLast(5).once("value");
    const qv = qs.val() || {};
    check("query equalTo filters", Object.keys(qv).length === 2 && qv.a && qv.b && !qv.c);

    // 6) auth anonymous uid stable
    const auth = firebase.auth();
    const u1 = (await auth.signInAnonymously()).user;
    check("auth anonymous uid", u1 && typeof u1.uid === "string" && u1.uid.length > 0);
    check("auth currentUser matches", auth.currentUser && auth.currentUser.uid === u1.uid);

    // 7) child_added stream
    const adds = [];
    const ref7 = db.ref("test/stream");
    await db.ref("test/stream").set({ one: { v: 1 } });
    const cb7 = ref7.on("child_added", (snap) => adds.push(snap.key));
    await sleep(300);
    await db.ref("test/stream/two").set({ v: 2 });
    await sleep(400);
    check("child_added existing+new", adds.includes("one") && adds.includes("two"));
    ref7.off("child_added", cb7);

    // 8) update() merges
    await db.ref("test/merge").set({ a: 1, b: 2 });
    await db.ref("test/merge").update({ b: 3, c: 4 });
    const mv = (await db.ref("test/merge").once("value")).val();
    check("update merges keys", mv.a === 1 && mv.b === 3 && mv.c === 4);

    // 9) remove()
    await db.ref("test/merge/c").remove();
    const mv2 = (await db.ref("test/merge").once("value")).val();
    check("remove deletes key", mv2.c === undefined && mv2.a === 1);

  } catch (e) {
    check("no exception thrown: " + (e && e.message), false);
    console.error(e);
  }

  const failed = results.filter((r) => !r[1]);
  console.log("\n" + (results.length - failed.length) + "/" + results.length + " passed");
  srv.kill("SIGKILL");
  try { fs.rmSync(tmpDb, { force: true }); fs.rmSync(tmpStore, { recursive: true, force: true }); } catch (e) {}
  console.log(failed.length === 0 ? "ALL PASS" : "SOME FAIL");
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
