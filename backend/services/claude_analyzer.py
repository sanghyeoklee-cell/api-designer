from __future__ import annotations

import json
import logging

import anthropic

from config import settings
from models.form_schema import AnalysisResult, DataPattern, Endpoint, FormField, FormSchema
from models.traffic import TrafficEntry
from security import mask_sensitive_headers

logger = logging.getLogger(__name__)

ANALYSIS_SYSTEM_PROMPT = """\
You are an expert API reverse-engineer. You analyze HTTP traffic captured from a web application
and identify API endpoints, authentication methods, and data patterns.

You MUST respond in valid JSON matching this exact schema:
{
  "endpoints": [
    {
      "url": "string (base path without query params)",
      "method": "string (GET/POST/PUT/DELETE/PATCH)",
      "description": "string (what this endpoint does)",
      "request_headers": {"key": "value"},
      "request_body_schema": null or {},
      "response_body_schema": null or {},
      "auth_required": true/false
    }
  ],
  "auth_method": "none|bearer_token|cookie|api_key|oauth2",
  "auth_details": {
    "description": "string",
    "token_location": "header|cookie|query",
    "token_name": "string"
  },
  "data_patterns": [
    {"name": "string", "description": "string", "example": any}
  ],
  "form_schema": {
    "title": "string (name of the service)",
    "description": "string (what info is needed from user)",
    "fields": [
      {
        "key": "string (variable name)",
        "label": "string (display label)",
        "field_type": "text|password|select|checkbox|textarea|number",
        "required": true/false,
        "placeholder": "string",
        "default_value": "string",
        "options": [],
        "description": "string (help text)"
      }
    ]
  },
  "summary": "string (overall analysis summary in Korean)"
}

For form_schema.fields: include fields for any credentials, API keys, tokens, or
configuration values that a user would need to provide to use these APIs independently.
Always include fields for authentication credentials if auth is detected.

Respond ONLY with the JSON. No markdown, no explanation.\
"""


class ClaudeAnalyzer:
    def __init__(self) -> None:
        self._client: anthropic.Anthropic | None = None
        self._init_client()

    def _init_client(self) -> None:
        if settings.is_api_key_set:
            self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        else:
            self._client = None

    def reload(self) -> None:
        """Re-initialize client with current settings."""
        self._init_client()
        logger.info("ClaudeAnalyzer reloaded (key set: %s, model: %s)",
                     settings.is_api_key_set, settings.claude_model)

    def _prepare_traffic_summary(self, entries: list[TrafficEntry]) -> str:
        """Prepare a concise, deduplicated summary of traffic for Claude.

        Strategy:
        - Filter out static resources (images, CSS, fonts, JS bundles)
        - Group by URL pattern, keep first occurrence with full detail
        - Limit body sizes and total output to stay within token budget
        """
        MAX_TOTAL_CHARS = 120_000  # ~40K tokens budget for traffic
        MAX_BODY_CHARS = 500       # per request/response body
        MAX_ENTRIES = 80           # hard cap on entries

        # Filter to API-relevant entries only
        api_entries = [e for e in entries if e.is_api_call]
        if not api_entries:
            # Fallback: include non-static entries
            skip_types = {
                "image", "font", "stylesheet", "media", "manifest",
            }
            skip_exts = {
                ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff",
                ".woff2", ".ttf", ".eot", ".css", ".map",
            }
            api_entries = [
                e for e in entries
                if e.content_type
                and not any(t in e.content_type for t in skip_types)
                and not any(e.request_url.lower().endswith(ext) for ext in skip_exts)
            ]

        # Deduplicate: group by (method, url_path) and keep first + count
        from urllib.parse import urlparse
        seen: dict[str, dict] = {}  # key -> {entry, count}
        for e in api_entries:
            parsed = urlparse(e.request_url)
            key = f"{e.request_method} {parsed.scheme}://{parsed.netloc}{parsed.path}"
            if key not in seen:
                seen[key] = {"entry": e, "count": 1}
            else:
                seen[key]["count"] += 1

        unique_entries = list(seen.values())[:MAX_ENTRIES]

        lines: list[str] = []
        lines.append(f"Total captured: {len(entries)} requests, "
                      f"API-relevant: {len(api_entries)}, "
                      f"Unique endpoints: {len(unique_entries)}")
        lines.append("")

        total_chars = 0
        for i, item in enumerate(unique_entries):
            entry = item["entry"]
            count = item["count"]

            block: list[str] = []
            block.append(f"--- #{i + 1} (x{count}) ---")
            block.append(f"{entry.request_method} {entry.request_url}")
            block.append(f"Status: {entry.response_status} | Type: {entry.content_type}")

            if entry.request_headers:
                relevant = {
                    k: v
                    for k, v in entry.request_headers.items()
                    if k.lower() in {
                        "authorization", "content-type", "cookie",
                        "x-api-key", "x-csrf-token", "x-requested-with",
                    }
                }
                # Mask credential VALUES before sending to the Claude API — the
                # analysis only needs to know which auth headers exist, not the
                # live token values.
                relevant = mask_sensitive_headers(relevant)
                if relevant:
                    block.append(f"Headers: {json.dumps(relevant, ensure_ascii=False)}")

            if entry.request_body:
                body = entry.request_body[:MAX_BODY_CHARS]
                if len(entry.request_body) > MAX_BODY_CHARS:
                    body += "...(truncated)"
                block.append(f"Req Body: {body}")

            if entry.response_body:
                body = entry.response_body[:MAX_BODY_CHARS]
                if len(entry.response_body) > MAX_BODY_CHARS:
                    body += "...(truncated)"
                block.append(f"Res Body: {body}")

            block.append("")
            block_text = "\n".join(block)

            if total_chars + len(block_text) > MAX_TOTAL_CHARS:
                lines.append(f"... ({len(unique_entries) - i} more endpoints omitted due to size limit)")
                break

            lines.append(block_text)
            total_chars += len(block_text)

        return "\n".join(lines)

    async def analyze_traffic(
        self,
        entries: list[TrafficEntry],
        session_id: str,
    ) -> AnalysisResult:
        """Analyze captured traffic using Claude API."""
        traffic_summary = self._prepare_traffic_summary(entries)

        logger.info(
            "Sending %d traffic entries to Claude for analysis (session: %s)",
            len(entries),
            session_id,
        )

        if self._client is None:
            raise RuntimeError("Anthropic API key is not configured. Go to Settings.")

        message = self._client.messages.create(
            model=settings.claude_model,
            max_tokens=8192,
            system=ANALYSIS_SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"다음은 웹사이트에서 캡처한 {len(entries)}개의 HTTP 트래픽입니다. "
                        "이를 분석하여 API 엔드포인트, 인증 방식, 데이터 패턴을 파악하고, "
                        "사용자가 입력해야 할 정보의 폼 스키마를 생성해주세요.\n\n"
                        f"{traffic_summary}"
                    ),
                }
            ],
        )

        response_text = message.content[0].text.strip()

        # Parse JSON response
        try:
            data = json.loads(response_text)
        except json.JSONDecodeError:
            # Try to extract JSON from possible markdown code block
            if "```" in response_text:
                json_str = response_text.split("```")[1]
                if json_str.startswith("json"):
                    json_str = json_str[4:]
                data = json.loads(json_str.strip())
            else:
                raise

        return AnalysisResult(
            session_id=session_id,
            endpoints=[Endpoint(**ep) for ep in data.get("endpoints", [])],
            auth_method=data.get("auth_method", "none"),
            auth_details=data.get("auth_details", {}),
            data_patterns=[
                DataPattern(**dp) for dp in data.get("data_patterns", [])
            ],
            form_schema=FormSchema(
                title=data.get("form_schema", {}).get("title", ""),
                description=data.get("form_schema", {}).get("description", ""),
                fields=[
                    FormField(**f)
                    for f in data.get("form_schema", {}).get("fields", [])
                ],
            ),
            summary=data.get("summary", ""),
        )


# Module-level singleton
claude_analyzer = ClaudeAnalyzer()
