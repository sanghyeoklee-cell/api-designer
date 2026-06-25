from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from security import validate_target_url
from services.browser_service import BrowserService
from services.traffic_recorder import TrafficRecorder
from ws.stream import ws_manager

router = APIRouter(prefix="/api/browser", tags=["browser"])

# Shared instances (injected from main.py via app.state)
_browser: BrowserService | None = None
_recorder: TrafficRecorder | None = None


def init(browser: BrowserService, recorder: TrafficRecorder) -> None:
    global _browser, _recorder
    _browser = browser
    _recorder = recorder


class LaunchRequest(BaseModel):
    url: str


class BrowserStatus(BaseModel):
    is_running: bool
    is_recording: bool


@router.post("/launch")
async def launch_browser(req: LaunchRequest) -> dict:
    if _browser is None or _recorder is None:
        raise HTTPException(500, "Services not initialized")

    if _browser.is_running:
        raise HTTPException(400, "Browser is already running")

    try:
        target_url = validate_target_url(req.url)
    except ValueError as e:
        raise HTTPException(400, str(e))

    # Wire up recorder to browser events
    _browser.on_request(_recorder.handle_request)
    _browser.on_response(_recorder.handle_response)
    _browser.on_console(_recorder.handle_console)

    # Wire up WebSocket streaming for real-time traffic
    async def stream_traffic(entry: object) -> None:
        await ws_manager.broadcast("traffic", {
            "type": "traffic",
            "data": entry.model_dump(mode="json") if hasattr(entry, "model_dump") else {},
        })

    async def stream_console(entry: object) -> None:
        await ws_manager.broadcast("traffic", {
            "type": "console",
            "data": entry.model_dump(mode="json") if hasattr(entry, "model_dump") else {},
        })

    _recorder.on_traffic(stream_traffic)
    _recorder.on_console_log(stream_console)

    await _browser.launch(target_url)
    return {"status": "launched", "url": target_url}


@router.post("/close")
async def close_browser() -> dict:
    if _browser is None:
        raise HTTPException(500, "Services not initialized")

    if not _browser.is_running:
        raise HTTPException(400, "Browser is not running")

    await _browser.close()
    return {"status": "closed"}


@router.get("/status")
async def get_status() -> BrowserStatus:
    return BrowserStatus(
        is_running=_browser.is_running if _browser else False,
        is_recording=_recorder.is_recording if _recorder else False,
    )


@router.get("/sources")
async def get_sources() -> dict:
    if _browser is None:
        raise HTTPException(500, "Services not initialized")
    if not _browser.is_running:
        raise HTTPException(400, "Browser is not running")

    sources = await _browser.get_page_sources()
    return {"sources": {url: src[:5000] for url, src in sources.items()}}
