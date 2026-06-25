from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.project_manager import ProjectManager
from services.session_manager import SessionManager

router = APIRouter(prefix="/api/project", tags=["project"])

_project_mgr: ProjectManager | None = None
_session_mgr: SessionManager | None = None


def init(project_mgr: ProjectManager, session_mgr: SessionManager) -> None:
    global _project_mgr, _session_mgr
    _project_mgr = project_mgr
    _session_mgr = session_mgr


class CreateProjectRequest(BaseModel):
    name: str
    target_url: str = ""
    description: str = ""


class UpdateProjectRequest(BaseModel):
    name: str | None = None
    target_url: str | None = None
    description: str | None = None


class ProjectSummary(BaseModel):
    id: str
    name: str
    description: str
    target_url: str
    created_at: str
    updated_at: str
    session_count: int


@router.post("/create")
async def create_project(req: CreateProjectRequest) -> dict:
    if _project_mgr is None:
        raise HTTPException(500, "Services not initialized")

    project = _project_mgr.create_project(
        name=req.name,
        target_url=req.target_url,
        description=req.description,
    )
    return {
        "id": project.id,
        "name": project.name,
    }


@router.get("s/")
async def list_projects() -> list[ProjectSummary]:
    if _project_mgr is None or _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    projects = _project_mgr.list_projects()
    result = []
    for p in projects:
        # Count sessions by checking the project's sessions directory
        sessions_dir = _project_mgr.sessions_dir(p.id)
        session_count = len(list(sessions_dir.glob("*.json")))
        result.append(ProjectSummary(
            id=p.id,
            name=p.name,
            description=p.description,
            target_url=p.target_url,
            created_at=p.created_at.isoformat(),
            updated_at=p.updated_at.isoformat(),
            session_count=session_count,
        ))
    return result


@router.get("/{project_id}")
async def get_project(project_id: str) -> dict:
    if _project_mgr is None:
        raise HTTPException(500, "Services not initialized")

    project = _project_mgr.get_project(project_id)
    if not project:
        raise HTTPException(404, "Project not found")
    return project.model_dump(mode="json")


@router.put("/{project_id}")
async def update_project(project_id: str, req: UpdateProjectRequest) -> dict:
    if _project_mgr is None:
        raise HTTPException(500, "Services not initialized")

    project = _project_mgr.update_project(
        project_id,
        name=req.name,
        description=req.description,
        target_url=req.target_url,
    )
    if not project:
        raise HTTPException(404, "Project not found")
    return project.model_dump(mode="json")


@router.delete("/{project_id}")
async def delete_project(project_id: str) -> dict:
    if _project_mgr is None:
        raise HTTPException(500, "Services not initialized")

    if _project_mgr.delete_project(project_id):
        return {"status": "deleted"}
    raise HTTPException(404, "Project not found")


@router.post("/{project_id}/activate")
async def activate_project(project_id: str) -> dict:
    """Switch session manager to this project's context."""
    if _project_mgr is None or _session_mgr is None:
        raise HTTPException(500, "Services not initialized")

    project = _project_mgr.get_project(project_id)
    if not project:
        raise HTTPException(404, "Project not found")

    sessions_dir = _project_mgr.sessions_dir(project_id)
    _session_mgr.set_project(project_id, sessions_dir)
    _project_mgr.touch(project_id)

    return {
        "status": "activated",
        "project_id": project_id,
        "sessions_dir": str(sessions_dir),
    }
