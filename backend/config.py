from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from pydantic import BaseModel

logger = logging.getLogger(__name__)

SETTINGS_FILE = Path(__file__).parent / "storage" / "settings.json"


class Settings(BaseModel):
    anthropic_api_key: str = ""
    claude_model: str = "claude-sonnet-4-6"
    host: str = "127.0.0.1"
    port: int = 8000
    storage_dir: Path = Path(__file__).parent / "storage" / "sessions"
    output_dir: Path = Path(__file__).parent.parent / "output"

    def model_post_init(self, __context: object) -> None:
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def save(self) -> None:
        """Save user-configurable settings to settings.json."""
        SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "anthropic_api_key": self.anthropic_api_key,
            "claude_model": self.claude_model,
        }
        SETTINGS_FILE.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        # The API key is stored in cleartext; restrict to owner read/write so
        # other local users cannot read it. (Best-effort; no-op on Windows.)
        try:
            os.chmod(SETTINGS_FILE, 0o600)
        except OSError:
            pass
        logger.info("Settings saved to %s", SETTINGS_FILE)

    def load(self) -> None:
        """Load user-configurable settings from settings.json."""
        if SETTINGS_FILE.exists():
            try:
                data = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
                if data.get("anthropic_api_key"):
                    self.anthropic_api_key = data["anthropic_api_key"]
                if data.get("claude_model"):
                    self.claude_model = data["claude_model"]
                logger.info("Settings loaded from %s", SETTINGS_FILE)
            except Exception:
                logger.warning("Failed to load settings file, using defaults")

        # Env var overrides file (if set)
        env_key = os.getenv("ANTHROPIC_API_KEY", "")
        if env_key:
            self.anthropic_api_key = env_key

    @property
    def is_api_key_set(self) -> bool:
        return bool(self.anthropic_api_key)

    @property
    def masked_api_key(self) -> str:
        key = self.anthropic_api_key
        if not key:
            return ""
        # Reveal only the constant, non-secret prefix; never the trailing chars.
        return (key[:8] + "*" * 8) if len(key) >= 8 else "*" * len(key)


settings = Settings()
settings.load()
