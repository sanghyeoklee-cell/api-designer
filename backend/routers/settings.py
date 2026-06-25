from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from config import settings

router = APIRouter(prefix="/api/settings", tags=["settings"])


class SettingsResponse(BaseModel):
    anthropic_api_key_masked: str
    anthropic_api_key_set: bool
    claude_model: str
    available_models: list[str]


class SettingsUpdateRequest(BaseModel):
    anthropic_api_key: str | None = None
    claude_model: str | None = None


AVAILABLE_MODELS = [
    # Current
    "claude-opus-4-8",
    "claude-opus-4-7",
    "claude-sonnet-4-6",
    "claude-haiku-4-5-20251001",
    # Legacy
    "claude-opus-4-6",
    "claude-opus-4-5-20251101",
    "claude-sonnet-4-5-20250929",
]


@router.get("/")
async def get_settings() -> SettingsResponse:
    return SettingsResponse(
        anthropic_api_key_masked=settings.masked_api_key,
        anthropic_api_key_set=settings.is_api_key_set,
        claude_model=settings.claude_model,
        available_models=AVAILABLE_MODELS,
    )


@router.put("/")
async def update_settings(req: SettingsUpdateRequest) -> SettingsResponse:
    if req.anthropic_api_key is not None:
        settings.anthropic_api_key = req.anthropic_api_key
    if req.claude_model is not None:
        settings.claude_model = req.claude_model

    settings.save()

    # Re-initialize Claude services with new settings
    from services.claude_analyzer import claude_analyzer
    from services.code_generator import code_generator
    claude_analyzer.reload()
    code_generator.reload()

    return SettingsResponse(
        anthropic_api_key_masked=settings.masked_api_key,
        anthropic_api_key_set=settings.is_api_key_set,
        claude_model=settings.claude_model,
        available_models=AVAILABLE_MODELS,
    )
