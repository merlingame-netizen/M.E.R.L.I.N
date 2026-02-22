const http = require("http");

function collect(req, cb) {
  let data = "";
  req.on("data", (c) => (data += c));
  req.on("end", () => cb(data));
}

const TARGET_HOST = "127.0.0.1";
const TARGET_PORT = 11434;

http.createServer((req, res) => {
  const headers = { ...req.headers };
  if (!headers["anthropic-version"]) headers["anthropic-version"] = "2023-06-01";

  // Map Authorization -> x-api-key (Ollama)
  if (!headers["x-api-key"] && headers["authorization"]) {
    headers["x-api-key"] = headers["authorization"].replace(/^Bearer\s+/i, "");
  }

  const isMessages = req.method === "POST" && req.url && req.url.startsWith("/v1/messages");

  if (isMessages) {
    collect(req, (body) => {
      try {
        const json = JSON.parse(body || "{}");

        // Strip tool calling fields
        delete json.tools;
        delete json.tool_choice;

        const out = JSON.stringify(json);

        const fwd = http.request(
          {
            host: TARGET_HOST,
            port: TARGET_PORT,
            path: req.url, // keep querystring if any
            method: req.method,
            headers: { ...headers, "content-length": Buffer.byteLength(out) },
          },
          (r) => {
            res.writeHead(r.statusCode || 500, r.headers);
            r.pipe(res);
          }
        );

        fwd.on("error", (e) => {
          res.writeHead(502, { "content-type": "text/plain" });
          res.end("Proxy error: " + e.message);
        });

        fwd.write(out);
        fwd.end();
      } catch (e) {
        res.writeHead(400, { "content-type": "text/plain" });
        res.end("Bad JSON: " + e.message);
      }
    });
    return;
  }

  // Default passthrough
  const fwd = http.request(
    { host: TARGET_HOST, port: TARGET_PORT, path: req.url, method: req.method, headers },
    (r) => {
      res.writeHead(r.statusCode || 500, r.headers);
      r.pipe(res);
    }
  );

  fwd.on("error", (e) => {
    res.writeHead(502, { "content-type": "text/plain" });
    res.end("Proxy error: " + e.message);
  });

  req.pipe(fwd);
}).listen(11435, "127.0.0.1", () => {
  console.log("Proxy strip-tools on http://127.0.0.1:11435 -> http://127.0.0.1:11434");
});
