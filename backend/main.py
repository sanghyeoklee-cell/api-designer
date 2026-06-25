from __future__ import annotations

import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path

# Ensure backend directory is in path
sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from security import host_allowed, origin_allowed
from routers import analysis, browser, codegen, manual, session
from routers import project as project_router
from routers import settings as settings_router
from services.browser_service import BrowserService
from services.claude_analyzer import claude_analyzer
from services.code_generator import code_generator
from services.project_manager import ProjectManager
from services.session_manager import SessionManager
from services.traffic_recorder import TrafficRecorder
from ws.stream import ws_manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Shared service instances
browser_service = BrowserService()
traffic_recorder = TrafficRecorder()
session_manager = SessionManager()
project_manager = ProjectManager()
code_generator.set_ws(ws_manager)


@asynccontextmanager
async def lifespan(app: FastAPI):  # type: ignore[type-arg]
    # Startup
    logger.info("API Designer backend starting...")
    logger.info("API key configured: %s", settings.is_api_key_set)
    logger.info("Claude model: %s", settings.claude_model)

    # Initialize routers with shared services
    project_router.init(project_manager, session_manager)
    browser.init(browser_service, traffic_recorder)
    session.init(session_manager, browser_service, traffic_recorder)
    analysis.init(session_manager, claude_analyzer)
    codegen.init(session_manager, code_generator, project_manager)
    manual.init(browser_service, traffic_recorder, session_manager, ws_manager)

    yield

    # Shutdown
    if browser_service.is_running:
        await browser_service.close()
    logger.info("API Designer backend stopped.")


app = FastAPI(
    title="API Designer Backend",
    description="웹사이트 API 트래픽 수동 녹화 및 분석·서버 코드 생성 도구",
    version="0.3.0",
    lifespan=lifespan,
)

# CORS — the Flutter desktop shell sends no Origin; only same-host browser
# origins are permitted. Never pair "*" with credentials.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def localhost_guard(request: Request, call_next):  # type: ignore[no-untyped-def]
    """Reject cross-origin browser requests and non-local Host headers.

    The backend is unauthenticated by design (single-user, 127.0.0.1). This
    stops a web page the user visits from reading the local API, and defeats
    DNS-rebinding via the Host check.
    """
    if not host_allowed(request.headers.get("host")):
        return JSONResponse({"detail": "Forbidden host"}, status_code=403)
    if not origin_allowed(request.headers.get("origin")):
        return JSONResponse(
            {"detail": "Cross-origin requests are not allowed"}, status_code=403
        )
    return await call_next(request)

# Register REST routers
app.include_router(project_router.router)
app.include_router(browser.router)
app.include_router(session.router)
app.include_router(analysis.router)
app.include_router(codegen.router)
app.include_router(settings_router.router)
app.include_router(manual.router)


# WebSocket endpoints
@app.websocket("/ws/traffic")
async def ws_traffic(websocket: WebSocket) -> None:
    if not await ws_manager.connect("traffic", websocket):
        return
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect("traffic", websocket)


@app.websocket("/ws/analysis")
async def ws_analysis(websocket: WebSocket) -> None:
    if not await ws_manager.connect("analysis", websocket):
        return
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect("analysis", websocket)


@app.websocket("/ws/codegen")
async def ws_codegen(websocket: WebSocket) -> None:
    if not await ws_manager.connect("codegen", websocket):
        return
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect("codegen", websocket)


@app.websocket("/ws/manual")
async def ws_manual(websocket: WebSocket) -> None:
    if not await ws_manager.connect("manual", websocket):
        return
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect("manual", websocket)


@app.get("/api/health")
async def health_check() -> dict:
    return {
        "status": "ok",
        "browser_running": browser_service.is_running,
        "recording": traffic_recorder.is_recording,
        "active_project_id": session_manager.project_id,
        "sessions_count": len(session_manager.list_sessions()),
        "api_key_set": settings.is_api_key_set,
        "claude_model": settings.claude_model,
    }


def start() -> None:
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
    )


if __name__ == "__main__":
    start()
