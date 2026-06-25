from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class Project(BaseModel):
    id: str
    name: str = ""
    description: str = ""
    target_url: str = ""
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
