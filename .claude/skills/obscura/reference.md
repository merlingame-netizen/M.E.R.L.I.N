# OBSCURA — Full CLI & MCP Reference

Source: <https://github.com/h4ckf0r0day/obscura> (Apache-2.0). Rust headless browser
embedding V8 + Chrome DevTools Protocol. Requires Rust 1.75+ to build from source.

## Installation

### Binary (preferred — what `scripts/install.sh` automates)

```bash
# Linux x86_64
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-x86_64-linux.tar.gz
# Linux ARM64
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-linux.tar.gz
# macOS Apple Silicon
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
# macOS Intel
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-x86_64-macos.tar.gz

tar xzf obscura-*.tar.gz
```

Arch Linux: `yay -S obscura-browser`

### Docker

```bash
docker run -d --name obscura -p 127.0.0.1:9222:9222 h4ckf0r0day/obscura
```

Image ~57 MB compressed (distroless/cc, no shell, no package manager).

### Build from source

```bash
git clone https://github.com/h4ckf0r0day/obscura.git
cd obscura
cargo build --release
cargo build --release --features stealth   # with anti-detection
```

## Global flags

| Flag | Purpose |
|------|---------|
| `--proxy <URL>` | HTTP/SOCKS5 proxy (placed before the subcommand) |
| `--v8-flags "<flags>"` | Pass raw V8 flags, e.g. `--v8-flags "--max-old-space-size=4096"` |

## `obscura fetch <URL>`

Renders a single page and extracts data.

| Flag | Default | Purpose |
|------|---------|---------|
| `--dump` | `html` | Output: `html`, `text`, `links`, `markdown`, `assets` (NDJSON), `original` (raw response bytes) |
| `--eval` | — | JavaScript expression to evaluate; arrays/objects are JSON-serialized |
| `--wait-until` | `load` | `load`, `domcontentloaded`, or `networkidle0` |
| `--timeout` | `30` | Max navigation time (seconds) |
| `--selector` | — | Wait for a CSS selector before extracting |
| `--stealth` | off | Anti-detection + tracker blocking |
| `--output` | — | Write results to a file instead of stdout |
| `--quiet` | off | Suppress banner |
| `--proxy` | — | HTTP/SOCKS5 proxy URL |

Examples:
```bash
obscura fetch https://example.com --eval "document.title"
obscura fetch https://example.com --dump links
obscura fetch https://example.com --dump text --output page.txt
obscura fetch https://picsum.photos/200/300 --dump original > photo.jpg
obscura fetch https://example.com --dump assets
obscura fetch https://example.com --wait-until networkidle0 --timeout 10
```

## `obscura scrape <URL...>`

Scrapes multiple URLs in parallel.

| Flag | Default | Purpose |
|------|---------|---------|
| `--concurrency` | `10` | Parallel workers |
| `--eval` | — | JS expression run per page |
| `--format` | `json` | `json` or `text` |
| `--quiet` | off | Suppress progress on stderr |
| `--proxy` | — | HTTP/SOCKS5 proxy for all workers |

```bash
obscura scrape url1 url2 url3 --concurrency 25 \
  --eval "document.querySelector('h1').textContent" --format json
```

## `obscura serve`

Long-lived CDP WebSocket server (attach Puppeteer/Playwright via CDP).

| Flag | Default | Purpose |
|------|---------|---------|
| `--port` | `9222` | WebSocket port |
| `--proxy` | — | HTTP/SOCKS5 proxy URL |
| `--stealth` | off | Anti-detection + tracker blocking |
| `--workers` | `1` | Parallel worker processes |
| `--obey-robots` | off | Respect robots.txt |

```bash
obscura serve --port 9222 --stealth
```

## `obscura mcp`

MCP server exposing browser tools to AI agents.

```bash
obscura mcp                      # stdio
obscura mcp --http --port 8080   # HTTP at http://127.0.0.1:8080/mcp
```

Optional (both transports): `--proxy <URL>`, `--user-agent <UA>`, `--stealth`.

### MCP browser tools

| Tool | Parameters | Purpose |
|------|-----------|---------|
| `browser_navigate` | `url`, optional `waitUntil` | Navigate to URL |
| `browser_snapshot` | — | Return URL, title, body text |
| `browser_click` | CSS selector | Click element |
| `browser_fill` | input value | Set input value (fires events) |
| `browser_type` | text | Append text to input |
| `browser_press_key` | `key`, optional `selector` | Keyboard event |
| `browser_select_option` | value or text | Select dropdown option |
| `browser_evaluate` | JS expression | Execute code, return result |
| `browser_wait_for` | `selector`, optional `timeout` | Wait for element |
| `browser_network_requests` | — | List network requests |
| `browser_console_messages` | — | Return console logs |
| `browser_close` | — | Reset browser state |

## Puppeteer-style extraction patterns (via `serve` + CDP)

```javascript
// Multiple elements
const stories = await page.evaluate(() =>
  Array.from(document.querySelectorAll('.titleline > a'))
    .map(a => ({ title: a.textContent, url: a.href }))
);

// Login + form submit
await page.goto('https://quotes.toscrape.com/login');
await page.evaluate(() => {
  document.querySelector('#username').value = 'admin';
  document.querySelector('#password').value = 'admin';
  document.querySelector('form').submit();
});
```
