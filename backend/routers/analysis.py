from __future__ import annotations

from fastapi import APIRouter, HTTPException

from models.form_schema import AnalysisResult
from models.session import SessionStatus
from services.claude_analyzer import ClaudeAnalyzer
from services.session_manager import SessionManager
from ws.stream import ws_manager

router = APIRouter(prefix="/api/analysis", tags=["analysis"])

_session_mgr: SessionManager | None = None
_analyzer: ClaudeAnalyzer | None = None
_results: dict[str, AnalysisResult] = {}


def init(session_mgr: SessionManager, analyzer: ClaudeAnalyzer) -> None:
    global _session_mgr, _analyzer
    _session_mgr = session_mgr
    _analyzer = analyzer


@router.post("/run/{session_id}")
async def run_analysis(session_id: str) -> dict:
    if _session_mgr is None or _analyzer is None:
        raise HTTPException(500, "Services not initialized")

    session = _session_mgr.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    api_entries = session.api_entries
    if not api_entries:
        raise HTTPException(400, "No API traffic found in this session")

    _session_mgr.update_status(session_id, SessionStatus.ANALYZING)

    await ws_manager.broadcast("analysis", {
        "type": "progress",
        "session_id": session_id,
        "message": f"Analyzing {len(api_entries)} API calls...",
    })

    try:
        result = await _analyzer.analyze_traffic(api_entries, session_id)
        _results[session_id] = result
        _session_mgr.update_status(session_id, SessionStatus.ANALYZED)

        await ws_manager.broadcast("analysis", {
            "type": "complete",
            "session_id": session_id,
            "summary": result.summary,
            "endpoint_count": len(result.endpoints),
            "auth_method": result.auth_method,
        })

        return result.model_dump(mode="json")

    except Exception as e:
        _session_mgr.update_status(session_id, SessionStatus.STOPPED)
        await ws_manager.broadcast("analysis", {
            "type": "error",
            "session_id": session_id,
            "message": str(e),
        })
        raise HTTPException(500, f"Analysis failed: {e}")


@router.get("/{session_id}")
async def get_analysis(session_id: str) -> dict:
    result = _results.get(session_id)
    if not result:
        raise HTTPException(404, "Analysis not found for this session")
    return result.model_dump(mode="json")
