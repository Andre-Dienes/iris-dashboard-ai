"""Bridge between the web portal and IRIS through the Native API (superserver, port 1972).

Each signed-in user gets a small pool of connections authenticated with their own IRIS
credentials, so IRIS SQL privileges keep applying inside the portal.
All the logic (AI, SQL, dashboards) runs inside IRIS in Copilot.API.Facade.Dispatch.
"""
from __future__ import annotations

import json
import os
import threading
import time

import iris

FACADE = "Copilot.API.Facade"
POOL_SIZE = int(os.getenv("IRIS_POOL_SIZE", "4"))


class IrisError(Exception):
    pass


class _Conn:
    def __init__(self, conn):
        self.conn = conn
        self.irispy = iris.createIRIS(conn)
        self.lock = threading.Lock()


class IrisSession:
    def __init__(self, username: str, password: str):
        self.username = username
        self._password = password
        self.host = os.getenv("IRIS_HOST", "localhost")
        self.port = int(os.getenv("IRIS_PORT", "1972"))
        self.namespace = os.getenv("IRIS_NAMESPACE", "COPILOT")
        self._pool: list[_Conn] = []
        self._pool_lock = threading.Lock()
        self.last_used = time.time()
        # validate the credentials right at sign-in
        self._pool.append(self._open())

    def _open(self) -> _Conn:
        try:
            conn = iris.connect(self.host, self.port, self.namespace, self.username, self._password, timeout=10000)
        except Exception as exc:  # invalid credentials, IRIS down...
            raise IrisError(str(exc)) from exc
        return _Conn(conn)

    def _acquire(self) -> _Conn:
        with self._pool_lock:
            for c in self._pool:
                if c.lock.acquire(blocking=False):
                    return c
            if len(self._pool) < POOL_SIZE:
                c = self._open()
                c.lock.acquire()
                self._pool.append(c)
                return c
            c = self._pool[0]
        c.lock.acquire()
        return c

    def _drop(self, c: _Conn):
        with self._pool_lock:
            if c in self._pool:
                self._pool.remove(c)
        try:
            c.conn.close()
        except Exception:
            pass

    def call(self, action: str, payload: dict | None = None) -> dict:
        self.last_used = time.time()
        body = json.dumps(payload or {}, ensure_ascii=False)
        for attempt in (1, 2):
            c = self._acquire()
            try:
                raw = c.irispy.classMethodValue(FACADE, "Dispatch", action, body)
            except Exception as exc:
                c.lock.release()
                self._drop(c)
                if attempt == 2:
                    raise IrisError(f"Communication failure with IRIS: {exc}") from exc
                continue  # connection dropped (IRIS restart?): reopen and retry
            c.lock.release()
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            return json.loads(raw) if raw else {}
        return {}

    def close(self):
        with self._pool_lock:
            pool, self._pool = self._pool, []
        for c in pool:
            try:
                c.conn.close()
            except Exception:
                pass
