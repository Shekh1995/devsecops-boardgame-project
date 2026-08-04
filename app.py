"""Board Game Library API with Prometheus metrics."""
import logging
import os
from flask import Flask, jsonify, render_template, request
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

REQUESTS = Counter("boardgame_requests_total", "HTTP requests", ["endpoint", "method"])

GAMES = [
    {"id": 1, "name": "Catan", "players": "3-4", "category": "Strategy"},
    {"id": 2, "name": "Ticket to Ride", "players": "2-5", "category": "Family"},
    {"id": 3, "name": "Pandemic", "players": "2-4", "category": "Cooperative"},
]


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update(test_config or {})

    @app.get("/")
    def index():
        REQUESTS.labels("index", "GET").inc()
        return render_template("index.html")

    @app.get("/health")
    def health():
        REQUESTS.labels("health", "GET").inc()
        return jsonify(status="healthy", service="boardgame-api"), 200

    @app.get("/api/games")
    def list_games():
        REQUESTS.labels("list_games", "GET").inc()
        return jsonify(games=GAMES, count=len(GAMES))

    @app.post("/api/games")
    def add_game():
        REQUESTS.labels("add_game", "POST").inc()
        payload = request.get_json(silent=True) or {}
        required = ("name", "players", "category")
        if not all(isinstance(payload.get(field), str) and payload[field].strip() for field in required):
            return jsonify(error="name, players, and category are required strings"), 400
        game = {"id": max((item["id"] for item in GAMES), default=0) + 1,
                **{field: payload[field].strip() for field in required}}
        GAMES.append(game)
        logger.info("Added board game id=%s", game["id"])
        return jsonify(game), 201

    @app.get("/metrics")
    def metrics():
        return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
