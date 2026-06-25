from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field, field_validator


class FormField(BaseModel):
    key: str
    label: str
    field_type: str = "text"  # text, password, select, checkbox, textarea, number
    required: bool = True
    placeholder: str = ""
    default_value: str = ""
    options: list[str] = Field(default_factory=list)  # for select type
    description: str = ""

    @field_validator("options", mode="before")
    @classmethod
    def coerce_options(cls, v: Any) -> list[str]:
        if not isinstance(v, list):
            return []
        result: list[str] = []
        for item in v:
            if isinstance(item, str):
                result.append(item)
            elif isinstance(item, dict):
                # {'label': '...', 'value': '...'} → "value (label)"
                label = item.get("label", "")
                value = item.get("value", str(item))
                result.append(f"{value} ({label})" if label else str(value))
            else:
                result.append(str(item))
        return result


class FormSchema(BaseModel):
    title: str
    description: str = ""
    fields: list[FormField] = Field(default_factory=list)


class Endpoint(BaseModel):
    url: str
    method: str
    description: str = ""
    request_headers: dict[str, str] = Field(default_factory=dict)
    request_body_schema: dict | list | None = None
    response_body_schema: dict | list | None = None
    auth_required: bool = False


class DataPattern(BaseModel):
    name: str
    description: str
    example: dict | str | None = None


class AnalysisResult(BaseModel):
    session_id: str
    endpoints: list[Endpoint] = Field(default_factory=list)
    auth_method: str = "none"  # none, bearer_token, cookie, api_key, oauth2
    auth_details: dict = Field(default_factory=dict)
    data_patterns: list[DataPattern] = Field(default_factory=list)
    form_schema: FormSchema = Field(default_factory=lambda: FormSchema(title=""))
    summary: str = ""
