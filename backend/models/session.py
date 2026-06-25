from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from .traffic import ConsoleEntry, TrafficEntry


class SessionStatus(str, Enum):
    IDLE = "idle"
    RECORDING = "recording"
    GUIDING = "guiding"
    STOPPED = "stopped"
    ANALYZING = "analyzing"
    ANALYZED = "analyzed"
    GENERATING = "generating"
    COMPLETED = "completed"


class HtmlSnapshot(BaseModel):
    id: str
    timestamp: datetime = Field(default_factory=datetime.now)
    url: str = ""
    title: str = ""
    html: str = ""


class Session(BaseModel):
    id: str
    name: str = ""
    target_url: str = ""
    status: SessionStatus = SessionStatus.IDLE
    created_at: datetime = Field(default_factory=datetime.now)
    traffic_entries: list[TrafficEntry] = Field(default_factory=list)
    console_entries: list[ConsoleEntry] = Field(default_factory=list)
    js_sources: dict[str, str] = Field(default_factory=dict)  # url -> source
    html_snapshots: list[HtmlSnapshot] = Field(default_factory=list)

    @property
    def api_entries(self) -> list[TrafficEntry]:
        return [e for e in self.traffic_entries if e.is_api_call]
