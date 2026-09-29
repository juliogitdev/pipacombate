"""Mock local da Live Gaming Gateway, sem dependências externas."""

from __future__ import annotations

import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


HOST = "127.0.0.1"
PORT = 8899
EVENTS: list[dict] = []
SCORES: dict[str, int] = {}
USERS = (
    ("ana_pipa", "Ana Pipa"),
    ("joao_vento", "João Vento"),
    ("bia_corta", "Bia Corta"),
)


def add_demo_event() -> None:
    uid, nickname = USERS[len(EVENTS) % len(USERS)]
    cursor = len(EVENTS) + 1
    user = {"uniqueId": uid, "apelido": nickname, "avatar": ""}
    if cursor % 7 == 0:
        gifts = (
            ("Rosa", 5655, 1, "SPAWN", 10),
            ("Rosquinha", 6064, 5, "SPAWN", 8),
            ("Perfume", 5658, 20, "GIGANTE", 20),
        )
        gift_name, gift_id, diamonds, action, points = gifts[(cursor // 7) % len(gifts)]
        event = {
            "tipo": "PRESENTE", "acao": action, "pontos": points, "usuario": user,
            "detalhes": {"giftId": gift_id, "giftName": gift_name, "quantidade": 1, "diamantes": diamonds},
        }
    elif cursor % 3 == 0:
        event = {
            "tipo": "LIKE", "acao": "BOOST", "pontos": 20, "usuario": user,
            "detalhes": {"quantidade": 20},
        }
    else:
        event = {
            "tipo": "COMENTARIO", "acao": "CHAT", "pontos": 5, "usuario": user,
            "detalhes": {"mensagem": "Quero minha pipa!"},
        }
    event["cursor"] = cursor
    event["recebidoEm"] = int(time.time() * 1000)
    EVENTS.append(event)
    SCORES[uid] = SCORES.get(uid, 0) + event["pontos"]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802 - nome definido pela biblioteca
        parsed = urlparse(self.path)
        if parsed.path != "/api/v1/game/ranking/reset":
            self._json({"erro": "rota não encontrada"}, 404)
            return
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length) if content_length else b"{}"
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._json({"erro": "JSON inválido"}, 400)
            return
        SCORES.clear()
        self._json({"ok": True, "manterNicks": bool(payload.get("manterNicks", True))})

    def do_GET(self) -> None:  # noqa: N802 - nome definido pela biblioteca
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/game/events":
            self._events(parse_qs(parsed.query))
        elif parsed.path == "/api/v1/game/ranking":
            self._ranking(parse_qs(parsed.query))
        elif parsed.path == "/api/v1/game/config":
            self._json({"instancia": "Mock local", "tiktokUsername": "streamer_teste", "regras": {}})
        else:
            self._json({"erro": "rota não encontrada"}, 404)

    def _events(self, query: dict[str, list[str]]) -> None:
        cursor = int(query.get("cursor", ["0"])[0])
        limit = min(100, max(1, int(query.get("limit", ["30"])[0])))
        add_demo_event()
        pending = [event for event in EVENTS if event["cursor"] > cursor]
        selected = pending[:limit]
        response_cursor = selected[-1]["cursor"] if selected else cursor
        self._json(
            {
                "statusLive": "ONLINE",
                "eventos": selected,
                "cursor": response_cursor,
                "pendentes": max(0, len(pending) - len(selected)),
                "totalEmBuffer": len(EVENTS),
            }
        )

    def _ranking(self, query: dict[str, list[str]]) -> None:
        limit = max(1, int(query.get("limit", ["10"])[0]))
        ordered = sorted(SCORES.items(), key=lambda item: item[1], reverse=True)[:limit]
        top = [
            {
                "posicao": index,
                "uniqueId": uid,
                "nickname": next((name for key, name in USERS if key == uid), uid),
                "avatar": "",
                "nickJogo": None,
                "pontos": score,
                "atualizadoEm": int(time.time() * 1000),
            }
            for index, (uid, score) in enumerate(ordered, start=1)
        ]
        self._json({"instancia": "Mock local", "top": top})

    def _json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, message: str, *args: object) -> None:
        print("[mock] " + message % args)


if __name__ == "__main__":
    print(f"Mock em http://{HOST}:{PORT} — pressione Ctrl+C para encerrar")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
