from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from models.session import SessionStatus
from services.code_generator import CodeGenerator
from services.project_manager import ProjectManager
from services.session_manager import SessionManager
from ws.stream import ws_manager

router = APIRouter(prefix="/api/codegen", tags=["codegen"])

_session_mgr: SessionManager | None = None
_code_gen: CodeGenerator | None = None
_project_mgr: ProjectManager | None = None
_generated: dict[str, dict[str, str]] = {}

# Import analysis results storage from analysis router
from routers.analysis import _results as _analysis_results


def init(session_mgr: SessionManager, code_gen: CodeGenerator, project_mgr: ProjectManager | None = None) -> None:
    global _session_mgr, _code_gen, _project_mgr
    _session_mgr = session_mgr
    _code_gen = code_gen
    _project_mgr = project_mgr


class GenerateRequest(BaseModel):
    session_id: str
    user_inputs: dict[str, str]
    project_name: str = "generated_api"


@router.post("/generate")
async def generate_code(req: GenerateRequest) -> dict:
    if _session_mgr is None or _code_gen is None:
        raise HTTPException(500, "Services not initialized")

    session = _session_mgr.get_session(req.session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    analysis = _analysis_results.get(req.session_id)
    if not analysis:
        raise HTTPException(400, "No analysis found. Run analysis first.")

    _session_mgr.update_status(req.session_id, SessionStatus.GENERATING)

    await ws_manager.broadcast("analysis", {
        "type": "progress",
        "session_id": req.session_id,
        "message": "Generating API server code...",
    })

    # Determine output directory based on active project
    output_dir = None
    if _project_mgr and _session_mgr and _session_mgr.project_id:
        output_dir = _project_mgr.output_dir(_session_mgr.project_id)

    try:
        files = await _code_gen.generate(
            analysis=analysis,
            user_inputs=req.user_inputs,
            entries=session.api_entries,
            project_name=req.project_name,
            output_dir=output_dir,
        )
        _generated[req.session_id] = files
        _session_mgr.update_status(req.session_id, SessionStatus.COMPLETED)

        await ws_manager.broadcast("analysis", {
            "type": "codegen_complete",
            "session_id": req.session_id,
            "files": list(files.keys()),
        })

        return {
            "status": "generated",
            "project_name": req.project_name,
            "files": list(files.keys()),
        }

    except Exception as e:
        _session_mgr.update_status(req.session_id, SessionStatus.ANALYZED)
        raise HTTPException(500, f"Code generation failed: {e}")


@router.get("/{session_id}/files")
async def get_generated_files(session_id: str) -> dict:
    files = _generated.get(session_id)
    if not files:
        raise HTTPException(404, "No generated code found for this session")
    return {"files": files}


@router.get("/{session_id}/files/{filename}")
async def get_generated_file(session_id: str, filename: str) -> dict:
    files = _generated.get(session_id)
    if not files:
        raise HTTPException(404, "No generated code found for this session")
    content = files.get(filename)
    if content is None:
        raise HTTPException(404, f"File not found: {filename}")
    return {"filename": filename, "content": content}
