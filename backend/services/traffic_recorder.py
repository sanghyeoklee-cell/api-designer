from __future__ import annotations

import logging
import uuid
from datetime import datetime
from typing import Any, Callable, Coroutine

from models.traffic import ConsoleEntry, TrafficEntry

logger = logging.getLogger(__name__)

TrafficCallback = Callable[[TrafficEntry], Coroutine[Any, Any, None]]
ConsoleLogCallback = Callable[[ConsoleEntry], Coroutine[Any, Any, None]]


class TrafficRecorder:
    def __init__(self) -> None:
        self._entries: list[TrafficEntry] = []
        self._console_entries: list[ConsoleEntry] = []
        self._pending_requests: dict[str, dict[str, Any]] = {}
        self._recording = False
        self._traffic_callbacks: list[TrafficCallback] = []
        self._console_callbacks: list[ConsoleLogCallback] = []

    @property
    def is_recording(self) -> bool:
        return self._recording

    def on_traffic(self, callback: TrafficCallback) -> None:
        self._traffic_callbacks.append(callback)

    def on_console_log(self, callback: ConsoleLogCallback) -> None:
        self._console_callbacks.append(callback)

    def start_recording(self) -> None:
        self._recording = True
        logger.info("Traffic recording started")

    def stop_recording(self) -> None:
        self._recording = False
        logger.info(
            "Traffic recording stopped. Captured %d entries (%d API calls)",
            len(self._entries),
            len(self.get_api_entries()),
        )

    def clear(self) -> None:
        self._entries.clear()
        self._console_entries.clear()
        self._pending_requests.clear()

    async def handle_request(self, data: dict[str, Any]) -> None:
        if not self._recording:
            return

        request_id = f"{data['method']}:{data['url']}:{datetime.now().timestamp()}"
        self._pending_requests[data["url"]] = {
            "id": request_id,
            "timestamp": datetime.now(),
            "request_url": data["url"],
            "request_method": data["method"],
            "request_headers": data.get("headers", {}),
            "request_body": data.get("body"),
        }

    async def handle_response(self, data: dict[str, Any]) -> None:
        if not self._recording:
            return

        url = data.get("request_url", data.get("url", ""))
        pending = self._pending_requests.pop(url, None)

        entry = TrafficEntry(
            id=str(uuid.uuid4()),
            timestamp=pending["timestamp"] if pending else datetime.now(),
            request_url=url,
            request_method=data.get("request_method", pending["request_method"] if pending else "GET"),
            request_headers=data.get("request_headers", pending.get("request_headers", {}) if pending else {}),
            request_body=data.get("request_body", pending.get("request_body") if pending else None),
            response_status=data.get("status", 0),
            response_headers=data.get("headers", {}),
            response_body=data.get("body"),
            content_type=data.get("headers", {}).get("content-type", ""),
            duration_ms=(
                (datetime.now() - pending["timestamp"]).total_seconds() * 1000
                if pending
                else 0.0
            ),
        )

        self._entries.append(entry)

        for cb in self._traffic_callbacks:
            try:
                await cb(entry)
            except Exception:
                logger.exception("Error in traffic callback")

    async def handle_console(self, data: dict[str, Any]) -> None:
        if not self._recording:
            return

        location = data.get("location", {})
        entry = ConsoleEntry(
            level=data.get("level", "log"),
            message=data.get("text", ""),
            source=location.get("url", ""),
            line_number=location.get("lineNumber", 0),
        )
        self._console_entries.append(entry)

        for cb in self._console_callbacks:
            try:
                await cb(entry)
            except Exception:
                logger.exception("Error in console callback")

    def get_entries(self) -> list[TrafficEntry]:
        return list(self._entries)

    def get_api_entries(self) -> list[TrafficEntry]:
        return [e for e in self._entries if e.is_api_call]

    def get_console_entries(self) -> list[ConsoleEntry]:
        return list(self._console_entries)

    def export_har(self) -> dict:
        """Export captured traffic in HAR-like format."""
        return {
            "log": {
                "version": "1.2",
                "entries": [
                    {
                        "startedDateTime": e.timestamp.isoformat(),
                        "request": {
                            "method": e.request_method,
                            "url": e.request_url,
                            "headers": [
                                {"name": k, "value": v}
                                for k, v in e.request_headers.items()
                            ],
                            "postData": {
                                "text": e.request_body or "",
                            },
                        },
                        "response": {
                            "status": e.response_status,
                            "headers": [
                                {"name": k, "value": v}
                                for k, v in e.response_headers.items()
                            ],
                            "content": {
                                "text": e.response_body or "",
                                "mimeType": e.content_type,
                            },
                        },
                        "time": e.duration_ms,
                    }
                    for e in self._entries
                ],
            }
        }
