"""IRIS Data Copilot - web portal (FastAPI).

The portal is thin: it signs the user in to IRIS and forwards actions to
Copilot.API.Facade, where the AI (AI Hub), SQL and dashboards live.
"""
from __future__ import annotations

import secrets
import threading
import time
from pathlib import Path

from fastapi import Body, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .iris_bridge import IrisError, IrisSession

STATIC = Path(__file__).resolve().parent.parent / "static"
COOKIE = "copilot_session"
IDLE_SECONDS = 8 * 3600

ALLOWED_ACTIONS = {
    "status", "schemas", "catalog", "catalog.refresh", "run",
    "ask", "explain", "fix", "insight", "suggest", "agent",
    "dashboards.list", "dashboards.get", "dashboards.save", "dashboards.delete", "dashboards.generate",
    "widgets.save", "widgets.delete", "widgets.reorder",
    "views.list", "views.create", "views.drop",
    "glossary.list", "glossary.save", "glossary.delete",
    "history",
}

app = FastAPI(title="IRIS Data Copilot", docs_url="/api/docs", openapi_url="/api/openapi.json")
sessions: dict[str, IrisSession] = {}
sessions_lock = threading.Lock()


def _msg(request: Request, pt: str, en: str) -> str:
    """Message in the UI language (X-Copilot-Lang header: pt | en)."""
    return pt if request.headers.get("x-copilot-lang", "en").lower().startswith("pt") else en


def _session(request: Request) -> IrisSession:
    token = request.cookies.get(COOKIE)
    s = sessions.get(token or "")
    if not s:
        raise HTTPException(status_code=401, detail=_msg(request, "Sessão expirada. Faça login novamente.", "Session expired. Please sign in again."))
    return s


def _reap():
    while True:
        time.sleep(300)
        now = time.time()
        with sessions_lock:
            stale = [t for t, s in sessions.items() if now - s.last_used > IDLE_SECONDS]
            for t in stale:
                sessions.pop(t).close()


threading.Thread(target=_reap, daemon=True).start()


@app.post("/api/login")
def login(request: Request, response: Response, body: dict = Body(...)):
    user = (body.get("username") or "").strip()
    pwd = body.get("password") or ""
    if not user:
        raise HTTPException(status_code=400, detail=_msg(request, "Informe o usuário.", "Enter the user name."))
    try:
        s = IrisSession(user, pwd)
        status = s.call("status", {"lang": "pt" if request.headers.get("x-copilot-lang", "en").lower().startswith("pt") else "en"})
    except IrisError as exc:
        msg = str(exc)
        if "Access Denied" in msg or "authentication" in msg.lower() or "password" in msg.lower():
            msg = _msg(request, "Usuário ou senha inválidos no IRIS.", "Invalid IRIS user name or password.")
        raise HTTPException(status_code=401, detail=msg)
    token = secrets.token_urlsafe(32)
    with sessions_lock:
        sessions[token] = s
    response.set_cookie(COOKIE, token, httponly=True, samesite="strict", max_age=IDLE_SECONDS)
    return status


@app.post("/api/logout")
def logout(request: Request, response: Response):
    token = request.cookies.get(COOKIE)
    with sessions_lock:
        s = sessions.pop(token or "", None)
    if s:
        s.close()
    response.delete_cookie(COOKIE)
    return {"ok": True}


@app.post("/api/call/{action}")
def call(action: str, request: Request, payload: dict = Body(default={})):
    if action not in ALLOWED_ACTIONS:
        raise HTTPException(status_code=404, detail=_msg(request, "Ação desconhecida: ", "Unknown action: ") + action)
    s = _session(request)
    if "lang" not in payload:
        payload["lang"] = "pt" if request.headers.get("x-copilot-lang", "en").lower().startswith("pt") else "en"
    try:
        result = s.call(action, payload)
    except IrisError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    if isinstance(result, dict) and result.get("error") and not result.get("sqlError"):
        return JSONResponse(status_code=422, content={"detail": result["error"]})
    return result


@app.get("/api/health")
def health():
    return {"status": "ok", "sessions": len(sessions)}


app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html", headers={"Cache-Control": "no-cache"})
