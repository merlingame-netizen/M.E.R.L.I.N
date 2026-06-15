"use strict";
// Load a Firebase RTDB JSON export into the tree store (kv table).
// Run: node --experimental-sqlite import-rtdb.js <export.json> [out-tree.db]
const fs = require("fs");
const path = require("path");
const { Store } = require("./store");

const src = process.argv[2];
const out = process.argv[3] || path.join(process.env.HOME || ".", "atelier-idrac-tree.db");
if (!src) { console.error("usage: import-rtdb.js <export.json> [out-tree.db]"); process.exit(1); }

const data = JSON.parse(fs.readFileSync(src, "utf8"));
const s = new Store(out);
s.db.exec("BEGIN");          // one transaction = fast bulk insert
try { s.set("", data); s.db.exec("COMMIT"); }
catch (e) { s.db.exec("ROLLBACK"); throw e; }

const roots = Object.keys(data || {});
console.log(`imported ${roots.length} root nodes into ${out}`);
console.log("roots:", roots.join(", "));
