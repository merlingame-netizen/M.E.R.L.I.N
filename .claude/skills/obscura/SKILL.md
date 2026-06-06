---
name: obscura
description: Scrape web pages and extract elements with OBSCURA — a Rust headless browser (V8 + Chrome DevTools Protocol) for AI agents. Use whenever the user wants to scrape a URL, extract DOM elements / links / tables / text / markdown, render JavaScript-heavy pages, run a CSS/XPath query against a live page, crawl many URLs in parallel, or stand up a browser-automation MCP server. Handles JS-rendered SPAs that plain HTTP fetch cannot.
---

# OBSCURA — Headless Browser Scraping

OBSCURA (`h4ckf0r0day/obscura`) is a single-binary headless browser written in Rust. It
embeds V8 and speaks the Chrome DevTools Protocol, so it renders JavaScript like real
Chrome but with no Chrome, no Node.js, and no dependencies. It is a drop-in scraping
engine and ships an MCP server exposing 12 browser tools.

Reach for OBSCURA over a plain HTTP fetch whenever the page needs JavaScript to render,
you must wait for a selector, you want clean markdown/text instead of raw HTML, or you
need to crawl many URLs concurrently.

## Step 0 — Ensure the binary is installed (do this FIRST)

The skill bundles an installer. Run it once per environment; it is idempotent.

```bash
bash "$(dirname "$0")/scripts/install.sh"   # or: bash .claude/skills/obscura/scripts/install.sh
obscura --version                            # verify
```

`install.sh` detects OS/arch, downloads the matching release tarball, and drops `obscura`
into `~/.local/bin` (added to PATH for the session). If a network policy blocks the
GitHub release download, fall back to Docker:

```bash
docker run -d --name obscura -p 127.0.0.1:9222:9222 h4ckf0r0day/obscura
```

## Decision guide — pick the right mode

| You want to…                                              | Use                                  |
|-----------------------------------------------------------|--------------------------------------|
| Grab one page's text/markdown/HTML/links                  | `obscura fetch <URL> --dump <type>`  |
| Pull specific elements via a JS expression                | `obscura fetch <URL> --eval "<js>"`  |
| Crawl many URLs in parallel                               | `obscura scrape <URL...> --eval ...` |
| Download a raw asset (image, PDF, JSON)                   | `obscura fetch <URL> --dump original`|
| Give Claude live point-and-click browser control          | MCP server (`obscura mcp`)           |
| Keep a long-lived CDP endpoint for Puppeteer/Playwright   | `obscura serve --port 9222`          |

## Common recipes

**Clean article text / markdown (strips nav, header, footer, aside):**
```bash
obscura fetch https://example.com --dump markdown
obscura fetch https://example.com --dump text --output page.txt
```

**Every link on the page:**
```bash
obscura fetch https://example.com --dump links
```

**Extract structured elements with a CSS selector (the core "scrap d'éléments" case):**
```bash
obscura fetch https://news.ycombinator.com --eval \
  "Array.from(document.querySelectorAll('.titleline > a')).map(a => ({title: a.textContent, url: a.href}))"
```
The `--eval` result is serialized to JSON automatically when it returns an array/object.

**Wait for a JS-rendered element before scraping (SPAs):**
```bash
obscura fetch https://app.example.com --selector ".results-loaded" --wait-until networkidle0 \
  --eval "Array.from(document.querySelectorAll('.result')).map(e => e.innerText)"
```

**Crawl many URLs in parallel, same extractor each:**
```bash
obscura scrape https://a.com https://b.com https://c.com \
  --concurrency 25 --format json \
  --eval "({title: document.title, h1: document.querySelector('h1')?.textContent})"
```

**Download a binary asset:**
```bash
obscura fetch https://picsum.photos/200/300 --dump original > photo.jpg
```

**Behind a proxy / with anti-detection:**
```bash
obscura --proxy socks5://127.0.0.1:1080 fetch https://example.com --dump text
obscura fetch https://example.com --stealth --dump markdown
```

## MCP mode (interactive browser tools for the agent)

When the task needs multi-step navigation (click → fill → submit → read), run the MCP
server instead of one-shot CLI calls:

```bash
obscura mcp                       # stdio transport (for Claude Code / Desktop)
obscura mcp --http --port 8080    # HTTP transport at http://127.0.0.1:8080/mcp
```

Register it in an MCP client config:
```json
{ "mcpServers": { "obscura": { "command": "obscura", "args": ["mcp"] } } }
```

It exposes: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_fill`,
`browser_type`, `browser_press_key`, `browser_select_option`, `browser_evaluate`,
`browser_wait_for`, `browser_network_requests`, `browser_console_messages`,
`browser_close`.

## Guardrails

- **Respect the target.** Prefer `--obey-robots` on `serve`, throttle `--concurrency`,
  and only scrape sites the user is authorized to scrape. Decline mass-targeting,
  credential abuse, or anything that looks like an attack.
- **Stealth is dual-use.** Use `--stealth` for legitimate anti-bot friction on
  authorized targets, not to evade defenses maliciously.
- **Verify, don't assume.** A page that returns empty `--eval` often needs `--selector`
  / `--wait-until networkidle0` because content is rendered late.

## Full reference

Exhaustive flag tables, all CLI subcommands, V8 tuning, and Docker/build-from-source
details live in `reference.md` — load it when you need a flag not covered above.
