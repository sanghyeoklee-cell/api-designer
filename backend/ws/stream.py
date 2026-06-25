from __future__ import annotations

import json
import logging
from typing import Any

from fastapi import WebSocket, WebSocketDisconnect

from security import origin_allowed

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections for real-time streaming."""

    def __init__(self) -> None:
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, channel: str, websocket: WebSocket) -> bool:
        """Accept a local WebSocket connection. Returns False (and closes) if
        the handshake Origin is a non-local browser page — captured traffic
        contains live credentials and must not stream to arbitrary sites."""
        if not origin_allowed(websocket.headers.get("origin")):
            await websocket.close(code=1008)
            logger.warning("Rejected WebSocket from disallowed origin: %s",
                           websocket.headers.get("origin"))
            return False
        await websocket.accept()
        if channel not in self._connections:
            self._connections[channel] = []
        self._connections[channel].append(websocket)
        logger.info("WebSocket connected: %s (total: %d)", channel, len(self._connections[channel]))
        return True

    def disconnect(self, channel: str, websocket: WebSocket) -> None:
        if channel in self._connections:
            self._connections[channel] = [
                ws for ws in self._connections[channel] if ws is not websocket
            ]
            logger.info("WebSocket disconnected: %s", channel)

    async def broadcast(self, channel: str, data: dict[str, Any]) -> None:
        if channel not in self._connections:
            return

        message = json.dumps(data, default=str, ensure_ascii=False)
        dead: list[WebSocket] = []

        for ws in self._connections[channel]:
            try:
                await ws.send_text(message)
            except Exception:
                dead.append(ws)

        for ws in dead:
            self._connections[channel] = [
                w for w in self._connections[channel] if w is not ws
            ]


ws_manager = ConnectionManager()
