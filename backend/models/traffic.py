from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class TrafficEntry(BaseModel):
    id: str = Field(default_factory=lambda: "")
    timestamp: datetime = Field(default_factory=datetime.now)
    request_url: str
    request_method: str
    request_headers: dict[str, str] = Field(default_factory=dict)
    request_body: str | None = None
    response_status: int = 0
    response_headers: dict[str, str] = Field(default_factory=dict)
    response_body: str | None = None
    content_type: str = ""
    duration_ms: float = 0.0

    # Filtering helpers
    @property
    def is_api_call(self) -> bool:
        """Filter out static resources (images, CSS, fonts, etc.)."""
        skip_extensions = {
            ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".webp",
            ".css", ".woff", ".woff2", ".ttf", ".eot", ".otf",
            ".mp4", ".mp3", ".webm", ".ogg",
        }
        skip_content_types = {
            "image/", "font/", "text/css", "audio/", "video/",
        }
        url_lower = self.request_url.lower().split("?")[0]
        if any(url_lower.endswith(ext) for ext in skip_extensions):
            return False
        if any(self.content_type.startswith(ct) for ct in skip_content_types):
            return False
        return True


class ConsoleEntry(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.now)
    level: str  # "log", "warn", "error", "info", "debug"
    message: str
    source: str = ""
    line_number: int = 0
