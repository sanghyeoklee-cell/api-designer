from __future__ import annotations

import asyncio
import logging
from typing import Any, Callable, Coroutine

from playwright.async_api import Browser, BrowserContext, Page, async_playwright

logger = logging.getLogger(__name__)

RequestCallback = Callable[[dict[str, Any]], Coroutine[Any, Any, None]]
ResponseCallback = Callable[[dict[str, Any]], Coroutine[Any, Any, None]]
ConsoleCallback = Callable[[dict[str, Any]], Coroutine[Any, Any, None]]
DialogCallback = Callable[[dict[str, Any]], Coroutine[Any, Any, None]]


class BrowserService:
    def __init__(self) -> None:
        self._playwright: Any = None
        self._browser: Browser | None = None
        self._context: BrowserContext | None = None
        self._page: Page | None = None
        self._request_callbacks: list[RequestCallback] = []
        self._response_callbacks: list[ResponseCallback] = []
        self._console_callbacks: list[ConsoleCallback] = []
        self._dialog_callbacks: list[DialogCallback] = []
        self._is_running = False
        self._dialog_delay: float = 0.0  # seconds to wait before accepting dialogs

    @property
    def is_running(self) -> bool:
        return self._is_running

    @property
    def page(self) -> Page | None:
        return self._page

    def on_request(self, callback: RequestCallback) -> None:
        self._request_callbacks.append(callback)

    def on_response(self, callback: ResponseCallback) -> None:
        self._response_callbacks.append(callback)

    def on_console(self, callback: ConsoleCallback) -> None:
        self._console_callbacks.append(callback)

    def on_dialog(self, callback: DialogCallback) -> None:
        self._dialog_callbacks.append(callback)

    def set_dialog_delay(self, seconds: float) -> None:
        """Set delay before auto-accepting dialogs (for manual mode)."""
        self._dialog_delay = seconds

    async def launch(self, url: str) -> None:
        if self._is_running:
            raise RuntimeError("Browser is already running")

        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(
            headless=False,
            args=["--disable-blink-features=AutomationControlled"],
        )
        self._context = await self._browser.new_context(
            viewport={"width": 1280, "height": 900},
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/131.0.0.0 Safari/537.36"
            ),
        )
        self._page = await self._context.new_page()

        # Register event listeners on the page
        self._attach_page_listeners(self._page)

        # Capture popup windows (window.open) and attach listeners to them too
        self._context.on("page", self._handle_new_page)

        await self._page.goto(url, wait_until="domcontentloaded")
        self._is_running = True
        logger.info("Browser launched: %s", url)

    def _attach_page_listeners(self, page: Any) -> None:
        """Attach request/response/console/dialog listeners to a page."""
        page.on("request", self._handle_request)
        page.on("response", self._handle_response)
        page.on("console", self._handle_console)
        page.on("dialog", self._handle_dialog)

    async def _handle_new_page(self, page: Any) -> None:
        """Handle popup windows opened via window.open()."""
        self._attach_page_listeners(page)
        self._page = page  # Switch active page to the popup
        logger.info("Popup window captured: %s", page.url)

    async def _handle_request(self, request: Any) -> None:
        data = {
            "url": request.url,
            "method": request.method,
            "headers": await request.all_headers(),
            "body": request.post_data,
            "resource_type": request.resource_type,
        }
        for cb in self._request_callbacks:
            try:
                await cb(data)
            except Exception:
                logger.exception("Error in request callback")

    async def _handle_response(self, response: Any) -> None:
        body: str | None = None
        try:
            body = await response.text()
        except Exception:
            pass

        data = {
            "url": response.url,
            "status": response.status,
            "headers": await response.all_headers(),
            "body": body,
            "request_method": response.request.method,
            "request_url": response.request.url,
            "request_headers": await response.request.all_headers(),
            "request_body": response.request.post_data,
        }
        for cb in self._response_callbacks:
            try:
                await cb(data)
            except Exception:
                logger.exception("Error in response callback")

    async def _handle_console(self, msg: Any) -> None:
        data = {
            "level": msg.type,
            "text": msg.text,
            "location": msg.location,
        }
        for cb in self._console_callbacks:
            try:
                await cb(data)
            except Exception:
                logger.exception("Error in console callback")

    async def _handle_dialog(self, dialog: Any) -> None:
        data = {
            "type": dialog.type,  # alert, confirm, prompt, beforeunload
            "message": dialog.message,
            "default_value": dialog.default_value,
        }
        logger.info("Dialog appeared: [%s] %s", dialog.type, dialog.message)

        # Notify callbacks (e.g. broadcast to WebSocket)
        for cb in self._dialog_callbacks:
            try:
                await cb(data)
            except Exception:
                logger.exception("Error in dialog callback")

        # Wait before accepting so user can read the dialog
        if self._dialog_delay > 0:
            await asyncio.sleep(self._dialog_delay)

        try:
            await dialog.accept()
        except Exception:
            logger.debug("Dialog already handled")

    # --- Automation methods for AI agent ---

    async def click(self, selector: str) -> str:
        if not self._page:
            return "Error: No page open"
        try:
            await self._page.click(selector, timeout=5000)
            await self._page.wait_for_timeout(500)
            return f"Clicked: {selector}"
        except Exception as e:
            return f"Error clicking '{selector}': {e}"

    async def type_text(self, selector: str, text: str) -> str:
        if not self._page:
            return "Error: No page open"
        try:
            await self._page.fill(selector, text)
            return f"Typed into: {selector}"
        except Exception as e:
            return f"Error typing into '{selector}': {e}"

    async def press_key(self, key: str) -> str:
        if not self._page:
            return "Error: No page open"
        try:
            await self._page.keyboard.press(key)
            await self._page.wait_for_timeout(300)
            return f"Pressed: {key}"
        except Exception as e:
            return f"Error pressing '{key}': {e}"

    async def scroll(self, direction: str = "down", amount: int = 500) -> str:
        if not self._page:
            return "Error: No page open"
        try:
            delta = amount if direction == "down" else -amount
            await self._page.mouse.wheel(0, delta)
            await self._page.wait_for_timeout(300)
            return f"Scrolled {direction} by {amount}px"
        except Exception as e:
            return f"Error scrolling: {e}"

    async def get_page_context(self) -> dict[str, str]:
        """Get current page context — rich DOM tree similar to Chrome DevTools Elements tab."""
        if not self._page:
            return {"url": "", "title": "", "html": ""}

        try:
            url = self._page.url
            title = await self._page.title()

            # Get a rich DOM tree: deeper traversal, more attributes, visible text
            html = await self._page.evaluate("""
                () => {
                    const SKIP = new Set(['script','style','svg','noscript','path','g','defs',
                                          'clippath','lineargradient','stop','symbol','use']);
                    const SELF_CLOSING = new Set(['input','img','br','hr','meta','link']);
                    const MAX_LEN = 15000;
                    let out = '';

                    const walk = (el, depth) => {
                        if (out.length > MAX_LEN) return;
                        if (depth > 10) return;
                        const tag = el.tagName?.toLowerCase();
                        if (!tag) return;
                        if (SKIP.has(tag)) return;

                        // Skip hidden elements
                        const style = window.getComputedStyle(el);
                        if (style.display === 'none' && depth > 1) return;

                        const indent = '  '.repeat(depth);
                        const attrs = [];

                        // Comprehensive attributes for selector building
                        if (el.id) attrs.push('id="' + el.id + '"');
                        if (el.className && typeof el.className === 'string' && el.className.trim())
                            attrs.push('class="' + el.className.trim().slice(0, 80) + '"');
                        if (el.name) attrs.push('name="' + el.name + '"');
                        if (el.type) attrs.push('type="' + el.type + '"');
                        if (el.value && ['input','select','textarea'].includes(tag))
                            attrs.push('value="' + String(el.value).slice(0, 40) + '"');
                        if (el.placeholder) attrs.push('placeholder="' + el.placeholder + '"');
                        if (el.href) attrs.push('href="' + el.href.slice(0, 100) + '"');
                        if (el.src) attrs.push('src="' + el.src.slice(0, 100) + '"');
                        if (el.action) attrs.push('action="' + el.action + '"');
                        if (el.method) attrs.push('method="' + el.method + '"');
                        if (el.getAttribute('role')) attrs.push('role="' + el.getAttribute('role') + '"');
                        if (el.getAttribute('aria-label')) attrs.push('aria-label="' + el.getAttribute('aria-label') + '"');
                        if (el.getAttribute('data-id')) attrs.push('data-id="' + el.getAttribute('data-id') + '"');
                        if (el.getAttribute('onclick')) attrs.push('onclick="..."');
                        if (el.disabled) attrs.push('disabled');
                        if (el.checked) attrs.push('checked');
                        if (el.selected) attrs.push('selected');

                        const attrStr = attrs.length ? ' ' + attrs.join(' ') : '';

                        // Get direct text content (not from children)
                        let text = '';
                        for (const node of el.childNodes) {
                            if (node.nodeType === 3) {
                                const t = node.textContent?.trim();
                                if (t) text += t + ' ';
                            }
                        }
                        text = text.trim().slice(0, 100);

                        if (SELF_CLOSING.has(tag)) {
                            out += indent + '<' + tag + attrStr + '/>' + '\\n';
                            return;
                        }

                        // Check if it only has text (leaf node)
                        if (el.children.length === 0) {
                            if (text) {
                                out += indent + '<' + tag + attrStr + '>' + text + '</' + tag + '>\\n';
                            } else if (attrs.length > 0) {
                                out += indent + '<' + tag + attrStr + '/>' + '\\n';
                            }
                            return;
                        }

                        // Has children — recurse
                        out += indent + '<' + tag + attrStr + '>';
                        if (text) out += text;
                        out += '\\n';

                        for (const child of el.children) {
                            walk(child, depth + 1);
                        }

                        out += indent + '</' + tag + '>\\n';
                    };

                    walk(document.body, 0);
                    return out;
                }
            """)

            return {"url": url, "title": title, "html": html or ""}
        except Exception:
            logger.exception("Error getting page context")
            return {"url": "", "title": "", "html": ""}

    async def get_page_sources(self) -> dict[str, str]:
        """Collect JavaScript sources from the page via CDP."""
        if not self._page:
            return {}

        sources: dict[str, str] = {}
        cdp = await self._page.context.new_cdp_session(self._page)

        try:
            await cdp.send("Debugger.enable")
            # Get all loaded scripts
            # Note: We collect sources that were already parsed
            result = await cdp.send("Runtime.evaluate", {
                "expression": """
                    (() => {
                        const scripts = document.querySelectorAll('script[src]');
                        return Array.from(scripts).map(s => s.src).filter(Boolean);
                    })()
                """,
                "returnByValue": True,
            })
            script_urls = result.get("result", {}).get("value", [])

            for script_url in script_urls[:20]:  # Limit to 20 scripts
                try:
                    resp = await self._page.request.get(script_url)
                    if resp.ok:
                        sources[script_url] = await resp.text()
                except Exception:
                    logger.debug("Failed to fetch script: %s", script_url)

        except Exception:
            logger.exception("Error collecting page sources")
        finally:
            try:
                await cdp.detach()
            except Exception:
                pass

        return sources

    async def close(self) -> None:
        if self._page:
            try:
                await self._page.close()
            except Exception:
                pass
        if self._context:
            try:
                await self._context.close()
            except Exception:
                pass
        if self._browser:
            try:
                await self._browser.close()
            except Exception:
                pass
        if self._playwright:
            try:
                await self._playwright.stop()
            except Exception:
                pass

        self._page = None
        self._context = None
        self._browser = None
        self._playwright = None
        self._is_running = False
        self._request_callbacks.clear()
        self._response_callbacks.clear()
        self._console_callbacks.clear()
        self._dialog_callbacks.clear()
        self._dialog_delay = 0.0
        logger.info("Browser closed")
