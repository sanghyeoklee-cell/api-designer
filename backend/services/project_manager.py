from __future__ import annotations

import json
import logging
import shutil
import uuid
from datetime import datetime
from pathlib import Path

from config import settings
from models.project import Project

logger = logging.getLogger(__name__)

PROJECTS_DIR = Path(__file__).parent.parent / "storage" / "projects"


class ProjectManager:
    def __init__(self) -> None:
        PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
        self._projects: dict[str, Project] = {}
        self._load_existing()

    def _project_dir(self, project_id: str) -> Path:
        return PROJECTS_DIR / project_id

    def _project_file(self, project_id: str) -> Path:
        return self._project_dir(project_id) / "project.json"

    def sessions_dir(self, project_id: str) -> Path:
        d = self._project_dir(project_id) / "sessions"
        d.mkdir(parents=True, exist_ok=True)
        return d

    def output_dir(self, project_id: str) -> Path:
        d = self._project_dir(project_id) / "output"
        d.mkdir(parents=True, exist_ok=True)
        return d

    def _load_existing(self) -> None:
        for project_file in PROJECTS_DIR.glob("*/project.json"):
            try:
                data = json.loads(project_file.read_text(encoding="utf-8"))
                project = Project.model_validate(data)
                self._projects[project.id] = project
            except Exception:
                logger.warning("Failed to load project: %s", project_file)

    def _save_project(self, project: Project) -> None:
        d = self._project_dir(project.id)
        d.mkdir(parents=True, exist_ok=True)
        self._project_file(project.id).write_text(
            project.model_dump_json(indent=2),
            encoding="utf-8",
        )

    def create_project(self, name: str, target_url: str = "", description: str = "") -> Project:
        project = Project(
            id=str(uuid.uuid4()),
            name=name or "Untitled Project",
            description=description,
            target_url=target_url,
        )
        self._projects[project.id] = project
        # Create subdirectories
        self.sessions_dir(project.id)
        self.output_dir(project.id)
        self._save_project(project)
        logger.info("Created project: %s (%s)", project.name, project.id)
        return project

    def get_project(self, project_id: str) -> Project | None:
        return self._projects.get(project_id)

    def list_projects(self) -> list[Project]:
        return sorted(
            self._projects.values(),
            key=lambda p: p.updated_at,
            reverse=True,
        )

    def update_project(
        self,
        project_id: str,
        name: str | None = None,
        description: str | None = None,
        target_url: str | None = None,
    ) -> Project | None:
        project = self._projects.get(project_id)
        if not project:
            return None
        if name is not None:
            project.name = name
        if description is not None:
            project.description = description
        if target_url is not None:
            project.target_url = target_url
        project.updated_at = datetime.now()
        self._save_project(project)
        return project

    def touch(self, project_id: str) -> None:
        """Update the updated_at timestamp."""
        project = self._projects.get(project_id)
        if project:
            project.updated_at = datetime.now()
            self._save_project(project)

    def delete_project(self, project_id: str) -> bool:
        project = self._projects.pop(project_id, None)
        if project:
            d = self._project_dir(project_id)
            if d.exists():
                shutil.rmtree(d)
            logger.info("Deleted project: %s", project_id)
            return True
        return False
