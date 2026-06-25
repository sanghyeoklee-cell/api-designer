from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from models.session import HtmlSnapshot, SessionStatus
from security import validate_target_url
from services.browser_service import BrowserService
from services.session_manager import SessionManager
from services.traffic_recorder import TrafficRecorder
from ws.stream import ConnectionManager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/manual", tags=["manual"])

_browser: BrowserService | None = None
_recorder: TrafficRecorder | None = None
_session_mgr: SessionManager | None = None
_ws: ConnectionManager | None = None

_active_session_id: str | None = None
_snapshot_task: asyncio.Task[None] | None = None
_snapshots: list[HtmlSnapshot] = []
_last_snapshot_html: str = ""


def init(
    browser: BrowserService,
    recorder: TrafficRecorder,
    session_mgr: SessionManager,
    ws: ConnectionManager,
) -> None:
    global _browser, _recorder, _session_mgr, _ws
    _browser = browser
    _recorder = recorder
    _session_mgr = session_mgr
    _ws = ws


class ManualStartRequest(BaseModel):
    target_url: str
    name: str = ""


async def _capture_snapshot() -> HtmlSnapshot | None:
    """Capture current DOM snapshot if content changed."""
    global _last_snapshot_html
    if not _browser or not _browser.is_running:
        return None

    ctx = await _browser.get_page_context()
    html = ctx.get("html", "")

    # Skip if identical to last snapshot
    if html == _last_snapshot_html:
        return None

    _last_snapshot_html = html
    snapshot = HtmlSnapshot(
        id=str(uuid.uuid4()),
        timestamp=datetime.now(),
        url=ctx.get("url", ""),
        title=ctx.get("title", ""),
        html=html,
    )
    _snapshots.append(snapshot)
    return snapshot


async def _periodic_snapshot_loop() -> None:
    """Background task: capture DOM snapshots every 3 seconds."""
    while True:
        try:
            snapshot = await _capture_snapshot()
            if snapshot and _ws:
                await _ws.broadcast("manual", {
                    "type": "snapshot",
                    "data": {
                        "id": snapshot.id,
                        "timestamp": snapshot.timestamp.isoformat(),
                        "url": snapshot.url,
                        "title": snapshot.title,
                        "html": snapshot.html,
                    },
                })
        except asyncio.CancelledError:
            break
        except Exception:
            logger.exception("Error in periodic snapshot capture")
        await asyncio.sleep(3)


@router.post("/start")
async def start_manual(req: ManualStartRequest) -> dict:
    global _active_session_id, _snapshot_task, _snapshots, _last_snapshot_html

    if not _browser or not _recorder or not _session_mgr or not _ws:
        raise HTTPException(500, "Services not initialized")

    if _browser.is_running:
        raise HTTPException(400, "Browser is already running. Close it first.")

    if _active_session_id:
        raise HTTPException(400, "Manual recording already active")

    try:
        target_url = validate_target_url(req.target_url)
    except ValueError as e:
        raise HTTPException(400, str(e))

    # Reset state
    _snapshots = []
    _last_snapshot_html = ""

    # Wire up recorder to browser events
    _browser.on_request(_recorder.handle_request)
    _browser.on_response(_recorder.handle_response)
    _browser.on_console(_recorder.handle_console)

    # Manual mode: delay dialog auto-accept so user can read them
    _browser.set_dialog_delay(5.0)

    # Wire up dialog broadcasting
    async def stream_dialog(data: dict) -> None:
        await _ws.broadcast("manual", {
            "type": "dialog",
            "data": data,
        })

    _browser.on_dialog(stream_dialog)

    # Wire up WebSocket streaming for real-time traffic
    async def stream_traffic(entry: object) -> None:
        await _ws.broadcast("manual", {
            "type": "traffic",
            "data": entry.model_dump(mode="json") if hasattr(entry, "model_dump") else {},
        })

    async def stream_console(entry: object) -> None:
        await _ws.broadcast("manual", {
            "type": "console",
            "data": entry.model_dump(mode="json") if hasattr(entry, "model_dump") else {},
        })

    _recorder.on_traffic(stream_traffic)
    _recorder.on_console_log(stream_console)

    # Launch browser
    await _browser.launch(target_url)

    # Create session
    session = _session_mgr.create_session(
        req.name or f"Manual - {req.target_url[:50]}",
        req.target_url,
    )
    _active_session_id = session.id

    # Start recording
    _recorder.clear()
    _recorder.start_recording()
    _session_mgr.update_status(session.id, SessionStatus.RECORDING)

    # Start periodic DOM capture
    _snapshot_task = asyncio.create_task(_periodic_snapshot_loop())

    # Capture initial snapshot
    await asyncio.sleep(1)  # Wait for page to render
    snapshot = await _capture_snapshot()
    if snapshot:
        await _ws.broadcast("manual", {
            "type": "snapshot",
            "data": {
                "id": snapshot.id,
                "timestamp": snapshot.timestamp.isoformat(),
                "url": snapshot.url,
                "title": snapshot.title,
                "html": snapshot.html,
            },
        })

    logger.info("Manual recording started: %s", session.id)
    return {
        "status": "recording",
        "session_id": session.id,
        "name": session.name,
    }


@router.post("/stop")
async def stop_manual() -> dict:
    global _active_session_id, _snapshot_task

    if not _browser or not _recorder or not _session_mgr:
        raise HTTPException(500, "Services not initialized")

    if not _active_session_id:
        raise HTTPException(400, "No active manual recording")

    # Stop periodic snapshot capture
    if _snapshot_task:
        _snapshot_task.cancel()
        try:
            await _snapshot_task
        except asyncio.CancelledError:
            pass
        _snapshot_task = None

    # Capture final snapshot
    await _capture_snapshot()

    # Stop recording
    _recorder.stop_recording()

    # Transfer data to session
    session = _session_mgr.get_session(_active_session_id)
    if session:
        for entry in _recorder.get_entries():
            _session_mgr.add_traffic_entry(_active_session_id, entry)
        for entry in _recorder.get_console_entries():
            _session_mgr.add_console_entry(_active_session_id, entry)

        # Save HTML snapshots
        session.html_snapshots = list(_snapshots)

        # Collect JS sources (may fail if page context changed, e.g. popups)
        if _browser.is_running:
            try:
                sources = await _browser.get_page_sources()
                _session_mgr.set_js_sources(_active_session_id, sources)
            except Exception:
                logger.warning("Failed to collect JS sources (page context may have changed)")

        _session_mgr.update_status(_active_session_id, SessionStatus.STOPPED)
        _session_mgr.save(_active_session_id)

    result = {
        "status": "stopped",
        "session_id": _active_session_id,
        "total_entries": len(_recorder.get_entries()),
        "api_entries": len(_recorder.get_api_entries()),
        "snapshot_count": len(_snapshots),
    }

    sid = _active_session_id
    _active_session_id = None
    logger.info("Manual recording stopped: %s", sid)
    return result


@router.post("/snapshot")
async def trigger_snapshot() -> dict:
    """Manually trigger a DOM snapshot capture."""
    if not _browser or not _browser.is_running:
        raise HTTPException(400, "Browser is not running")

    if not _active_session_id:
        raise HTTPException(400, "No active manual recording")

    snapshot = await _capture_snapshot()
    if snapshot and _ws:
        await _ws.broadcast("manual", {
            "type": "snapshot",
            "data": {
                "id": snapshot.id,
                "timestamp": snapshot.timestamp.isoformat(),
                "url": snapshot.url,
                "title": snapshot.title,
                "html": snapshot.html,
            },
        })
        return {"status": "captured", "snapshot_id": snapshot.id}

    return {"status": "skipped", "reason": "No changes detected"}


@router.get("/state")
async def get_state() -> dict:
    return {
        "active": _active_session_id is not None,
        "session_id": _active_session_id,
        "snapshot_count": len(_snapshots),
        "traffic_count": len(_recorder.get_entries()) if _recorder else 0,
        "api_traffic_count": len(_recorder.get_api_entries()) if _recorder else 0,
    }
