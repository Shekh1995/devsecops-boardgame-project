from app import GAMES, create_app


def client():
    app = create_app({"TESTING": True})
    return app.test_client()


def test_health():
    response = client().get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "healthy"


def test_list_games():
    response = client().get("/api/games")
    assert response.status_code == 200
    assert response.json["count"] >= 3


def test_add_game_valid():
    original = len(GAMES)
    response = client().post("/api/games", json={"name": "Azul", "players": "2-4", "category": "Abstract"})
    assert response.status_code == 201
    assert response.json["name"] == "Azul"
    del GAMES[original:]


def test_add_game_rejects_missing_fields():
    response = client().post("/api/games", json={"name": "Incomplete"})
    assert response.status_code == 400
