"""Localhost-only request guards.

API Designer's backend binds to 127.0.0.1 and is unauthenticated by design
(single-user desktop tool). These helpers prevent a malicious web page the user
happens to visit from reaching the local API via the browser (cross-origin
fetch / WebSocket / DNS-rebinding), and reject non-HTTP navigation targets that
could turn the driven browser into a local-file / SSRF primitive.
"""
from __future__ import annotations

from urllib.parse import urlparse

# Hosts the backend legitimately answers to.
LOCAL_HOSTS = {"127.0.0.1", "localhost", "::1"}


def host_allowed(host_header: str | None) -> bool:
    """Validate the HTTP Host header (DNS-rebinding defense)."""
    if not host_header:
        return False
    # Strip port; handle bracketed IPv6 (e.g. "[::1]:8000").
    host = host_header.rsplit(":", 1)[0] if "]" not in host_header else host_header.split("]")[0].lstrip("[")
    return host in LOCAL_HOSTS


def origin_allowed(origin: str | None) -> bool:
    """Validate a browser Origin header.

    Non-browser clients (the Flutter desktop shell, curl) send no Origin, which
    is allowed. A browser page always sends its page Origin on cross-origin
    requests and WebSocket handshakes, so anything non-local is rejected.
    """
    if not origin:
        return True
    try:
        return urlparse(origin).hostname in LOCAL_HOSTS
    except Exception:
        return False


_SENSITIVE_HEADERS = {
    "authorization",
    "proxy-authorization",
    "cookie",
    "set-cookie",
    "x-api-key",
    "x-csrf-token",
    "x-xsrf-token",
    "x-auth-token",
}
_REDACTED = "***REDACTED***"


def mask_sensitive_headers(headers: dict[str, str] | None) -> dict[str, str]:
    """Replace the VALUES of credential-bearing headers with a placeholder,
    keeping header names/structure. Used before sending captured traffic to the
    Claude API so live tokens/cookies are not transmitted off-box."""
    if not headers:
        return {}
    return {
        k: (_REDACTED if k.lower() in _SENSITIVE_HEADERS else v)
        for k, v in headers.items()
    }


def validate_target_url(url: str) -> str:
    """Reject navigation targets that aren't plain web URLs.

    Blocks file://, about:, data:, chrome:// etc. so the driven browser cannot
    be pointed at local files. Returns the URL unchanged when valid.
    """
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise ValueError(
            f"지원하지 않는 URL 스킴입니다: '{parsed.scheme or '(없음)'}'. "
            "http:// 또는 https:// 주소만 사용할 수 있습니다."
        )
    if not parsed.netloc:
        raise ValueError("유효한 호스트가 없는 URL입니다.")
    return url
