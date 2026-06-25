from __future__ import annotations

import json
import logging
import uuid
from pathlib import Path

from models.session import Session, SessionStatus
from models.traffic import ConsoleEntry, TrafficEntry

logger = logging.getLogger(__name__)


class SessionManager:
    """Project-scoped session manager.

    Call set_project() to switch the active project context.
    All load/save operations target the current project's sessions directory.
    """

    def __init__(self) -> None:
        self._sessions: dict[str, Session] = {}
        self._sessions_dir: Path | None = None
        self._project_id: str | None = None

    @property
    def project_id(self) -> str | None:
        return self._project_id

    def set_project(self, project_id: str, sessions_dir: Path) -> None:
        """Switch to a different project context, loading its sessions."""
        if self._project_id == project_id:
            return
        self._project_id = project_id
        self._sessions_dir = sessions_dir
        self._sessions_dir.mkdir(parents=True, exist_ok=True)
        self._sessions.clear()
        self._load_existing()
        logger.info("SessionManager switched to project %s (%s)", project_id, sessions_dir)

    def _load_existing(self) -> None:
        if not self._sessions_dir:
            return
        for file in self._sessions_dir.glob("*.json"):
            try:
                data = json.loads(file.read_text(encoding="utf-8"))
                session = Session.model_validate(data)
                self._sessions[session.id] = session
            except Exception:
                logger.warning("Failed to load session: %s", file)

    def _save_session(self, session: Session) -> None:
        if not self._sessions_dir:
            return
        path = self._sessions_dir / f"{session.id}.json"
        path.write_text(
            session.model_dump_json(indent=2),
            encoding="utf-8",
        )

    def create_session(self, name: str, target_url: str) -> Session:
        session = Session(
            id=str(uuid.uuid4()),
            name=name or f"Session {len(self._sessions) + 1}",
            target_url=target_url,
            status=SessionStatus.IDLE,
        )
        self._sessions[session.id] = session
        self._save_session(session)
        logger.info("Created session: %s (%s)", session.name, session.id)
        return session

    def get_session(self, session_id: str) -> Session | None:
        return self._sessions.get(session_id)

    def list_sessions(self) -> list[Session]:
        return sorted(
            self._sessions.values(),
            key=lambda s: s.created_at,
            reverse=True,
        )

    def update_status(self, session_id: str, status: SessionStatus) -> Session | None:
        session = self._sessions.get(session_id)
        if session:
            session.status = status
            self._save_session(session)
        return session

    def add_traffic_entry(self, session_id: str, entry: TrafficEntry) -> None:
        session = self._sessions.get(session_id)
        if session:
            session.traffic_entries.append(entry)

    def add_console_entry(self, session_id: str, entry: ConsoleEntry) -> None:
        session = self._sessions.get(session_id)
        if session:
            session.console_entries.append(entry)

    def set_js_sources(self, session_id: str, sources: dict[str, str]) -> None:
        session = self._sessions.get(session_id)
        if session:
            session.js_sources = sources

    def save(self, session_id: str) -> None:
        session = self._sessions.get(session_id)
        if session:
            self._save_session(session)
            logger.info("Saved session: %s", session_id)

    def delete_session(self, session_id: str) -> bool:
        session = self._sessions.pop(session_id, None)
        if session and self._sessions_dir:
            path = self._sessions_dir / f"{session_id}.json"
            path.unlink(missing_ok=True)
            return True
        return False
