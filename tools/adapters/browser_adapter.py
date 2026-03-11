"""Browser adapter — Edge/Chromium automation via Playwright.

Actions:
  open          Open a URL and return page title + status
  screenshot    Capture a screenshot of a URL (kwargs: url, out=None, fullpage=False)
  scrape        Get text content of a URL (kwargs: url, selector=None)
  pdf           Export a page to PDF (kwargs: url, out=None)
  click         Click an element (kwargs: url, selector)
  fill          Fill a form field (kwargs: url, selector, value)
  run-script    Execute JavaScript on a page (kwargs: url, script)
  search        Open Edge with a search query (kwargs: query, engine=bing)
  status        Check if Playwright browsers are installed
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

_PYTHON = sys.executable
_PLAYWRIGHT_BROWSER = "chromium"  # or "msedge" if installed via playwright install msedge


def _try_import_playwright():
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
        return True
    except ImportError:
        return False


class BrowserAdapter(BaseAdapter):

    def __init__(self):
        super().__init__("browser")

    def list_actions(self) -> dict[str, str]:
        return {
            "open": "Open URL and return title + HTTP status (kwargs: url)",
            "screenshot": "Capture screenshot (kwargs: url, out=<path>, fullpage=False)",
            "scrape": "Extract text content (kwargs: url, selector=None)",
            "pdf": "Export page to PDF (kwargs: url, out=<path>)",
            "click": "Click element on page (kwargs: url, selector)",
            "fill": "Fill form field (kwargs: url, selector, value)",
            "run-script": "Execute JavaScript (kwargs: url, script)",
            "search": "Search via Edge (kwargs: query, engine=bing)",
            "status": "Check Playwright installation status",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        if action == "status":
            return self._status()
        if action == "search":
            return self._search(**kwargs)
        # All other actions require Playwright
        if not _try_import_playwright():
            return self.error(
                "Playwright not installed. Run: pip install playwright && python -m playwright install chromium"
            )
        handlers = {
            "open": self._open,
            "screenshot": self._screenshot,
            "scrape": self._scrape,
            "pdf": self._pdf,
            "click": self._click,
            "fill": self._fill,
            "run-script": self._run_script,
        }
        if action not in handlers:
            raise NotImplementedError
        return handlers[action](**kwargs)

    # ── Status ───────────────────────────────────────────────────────────────

    def _status(self, **_: Any) -> dict:
        installed = _try_import_playwright()
        if not installed:
            return self.ok({
                "playwright": False,
                "instructions": "pip install playwright && python -m playwright install chromium",
            })
        # Check if browser binaries are installed
        try:
            from playwright.sync_api import sync_playwright
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True)
                version = browser.version
                browser.close()
            return self.ok({"playwright": True, "browser": _PLAYWRIGHT_BROWSER, "version": version})
        except Exception as exc:
            return self.ok({
                "playwright": True,
                "browser_installed": False,
                "error": str(exc),
                "instructions": "python -m playwright install chromium",
            })

    # ── Search (no Playwright needed) ────────────────────────────────────────

    def _search(self, query: str = "", engine: str = "bing", **_: Any) -> dict:
        if not query:
            return self.error("Missing required argument: query")
        engines = {
            "bing": f"https://www.bing.com/search?q={query.replace(' ', '+')}",
            "google": f"https://www.google.com/search?q={query.replace(' ', '+')}",
            "ddg": f"https://duckduckgo.com/?q={query.replace(' ', '+')}",
        }
        url = engines.get(engine.lower(), engines["bing"])
        self.log(f"Opening browser search: {url}")
        try:
            import webbrowser
            webbrowser.open(url)
            return self.ok({"url": url, "engine": engine, "query": query})
        except Exception as exc:
            return self.error(f"Failed to open browser: {exc}")

    # ── Playwright-based actions ──────────────────────────────────────────────

    def _open(self, url: str = "", **_: Any) -> dict:
        if not url:
            return self.error("Missing required argument: url")
        from playwright.sync_api import sync_playwright
        self.log(f"Opening: {url}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            response = page.goto(url, timeout=30000)
            title = page.title()
            status = response.status if response else None
            browser.close()
        return self.ok({"url": url, "title": title, "status": status})

    def _screenshot(self, url: str = "", out: str = "", fullpage: bool = False, **_: Any) -> dict:
        if not url:
            return self.error("Missing required argument: url")
        out_path = out or f"screenshot_{url.replace('://', '_').replace('/', '_')[:50]}.png"
        from playwright.sync_api import sync_playwright
        self.log(f"Screenshot: {url} -> {out_path}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            page.screenshot(path=out_path, full_page=bool(fullpage))
            browser.close()
        size = Path(out_path).stat().st_size if Path(out_path).exists() else 0
        return self.ok({"url": url, "out": out_path, "size_bytes": size})

    def _scrape(self, url: str = "", selector: str = "", **_: Any) -> dict:
        if not url:
            return self.error("Missing required argument: url")
        from playwright.sync_api import sync_playwright
        self.log(f"Scraping: {url}" + (f" [{selector}]" if selector else ""))
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            if selector:
                text = page.locator(selector).all_inner_texts()
            else:
                text = page.inner_text("body")
            browser.close()
        return self.ok({"url": url, "selector": selector or "body", "text": text})

    def _pdf(self, url: str = "", out: str = "", **_: Any) -> dict:
        if not url:
            return self.error("Missing required argument: url")
        out_path = out or f"page_{url.replace('://', '_').replace('/', '_')[:50]}.pdf"
        from playwright.sync_api import sync_playwright
        self.log(f"PDF export: {url} -> {out_path}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            page.pdf(path=out_path)
            browser.close()
        size = Path(out_path).stat().st_size if Path(out_path).exists() else 0
        return self.ok({"url": url, "out": out_path, "size_bytes": size})

    def _click(self, url: str = "", selector: str = "", **_: Any) -> dict:
        if not url or not selector:
            return self.error("Missing required arguments: url, selector")
        from playwright.sync_api import sync_playwright
        self.log(f"Click: {selector} on {url}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            page.click(selector, timeout=10000)
            title = page.title()
            browser.close()
        return self.ok({"url": url, "selector": selector, "page_title_after": title})

    def _fill(self, url: str = "", selector: str = "", value: str = "", **_: Any) -> dict:
        if not url or not selector:
            return self.error("Missing required arguments: url, selector")
        from playwright.sync_api import sync_playwright
        self.log(f"Fill: {selector} = <value> on {url}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            page.fill(selector, value, timeout=10000)
            browser.close()
        return self.ok({"url": url, "selector": selector, "filled": True})

    def _run_script(self, url: str = "", script: str = "", **_: Any) -> dict:
        if not url or not script:
            return self.error("Missing required arguments: url, script")
        from playwright.sync_api import sync_playwright
        self.log(f"Run script on {url}")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=30000)
            result = page.evaluate(script)
            browser.close()
        return self.ok({"url": url, "result": result})
