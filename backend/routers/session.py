from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from models.session import Session, SessionStatus
from services.browser_service import BrowserService
from services.session_manager import SessionManager
from services.traffic_recorder import TrafficRecorder

router = APIRouter(prefix="/api/session", tags=["session"])

_session_mgr: SessionManager | None = None
_browser: BrowserService | None = None
_recorder: TrafficRecorder | None = None
_active_session_id: str | None = None


def init(
    session_mgr: SessionManager,
    browser: BrowserService,
    recorder: TrafficRecorder,
) -> None:
    global _session_mgr, _browser, _recorder
    _session_mgr = session_mgr
    _browser = browser
    _recorder = recorder


class CreateSessionRequest(BaseModel):
    name: str = ""
    target_url: str


class SessionSummary(BaseModel):
    id: str
    name: str
    target_url: str
    status: str
    created_at: str
    traffic_count: int
    api_call_count: int


@router.post("/create")
async def create_session(req: CreateSessionRequest) -> dict:
    if _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    session = _session_mgr.create_session(req.name, req.target_url)
    return {"session_id": session.id, "name": session.name}


@router.post("/start/{session_id}")
async def start_recording(session_id: str) -> dict:
    global _active_session_id

    if _session_mgr is None or _recorder is None or _browser is None:
        raise HTTPException(500, "Services not initialized")

    session = _session_mgr.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    if not _browser.is_running:
        raise HTTPException(400, "Browser is not running. Launch browser first.")

    _recorder.clear()
    _recorder.start_recording()
    _session_mgr.update_status(session_id, SessionStatus.RECORDING)
    _active_session_id = session_id

    return {"status": "recording", "session_id": session_id}


@router.post("/stop")
async def stop_recording() -> dict:
    global _active_session_id

    if _session_mgr is None or _recorder is None or _browser is None:
        raise HTTPException(500, "Services not initialized")

    if _active_session_id is None:
        raise HTTPException(400, "No active recording session")

    _recorder.stop_recording()

    session = _session_mgr.get_session(_active_session_id)
    if session:
        # Transfer recorded data to session
        for entry in _recorder.get_entries():
            _session_mgr.add_traffic_entry(_active_session_id, entry)
        for entry in _recorder.get_console_entries():
            _session_mgr.add_console_entry(_active_session_id, entry)

        # Collect JS sources (may fail if page context changed)
        if _browser.is_running:
            try:
                sources = await _browser.get_page_sources()
                _session_mgr.set_js_sources(_active_session_id, sources)
            except Exception:
                pass

        _session_mgr.update_status(_active_session_id, SessionStatus.STOPPED)
        _session_mgr.save(_active_session_id)

    result = {
        "status": "stopped",
        "session_id": _active_session_id,
        "total_entries": len(_recorder.get_entries()),
        "api_entries": len(_recorder.get_api_entries()),
        "console_entries": len(_recorder.get_console_entries()),
    }
    _active_session_id = None
    return result


@router.get("/{session_id}")
async def get_session(session_id: str) -> dict:
    if _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    session = _session_mgr.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    return session.model_dump(mode="json")


@router.get("s/")
async def list_sessions() -> list[SessionSummary]:
    if _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    sessions = _session_mgr.list_sessions()
    return [
        SessionSummary(
            id=s.id,
            name=s.name,
            target_url=s.target_url,
            status=s.status.value,
            created_at=s.created_at.isoformat(),
            traffic_count=len(s.traffic_entries),
            api_call_count=len(s.api_entries),
        )
        for s in sessions
    ]


@router.delete("/{session_id}")
async def delete_session(session_id: str) -> dict:
    if _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    if _session_mgr.delete_session(session_id):
        return {"status": "deleted"}
    raise HTTPException(404, "Session not found")
