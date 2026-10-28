import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app

PAYLOAD = {
    "text": "高数作业：2026年10月23日18:00前提交第三章习题。",
    "message_time": "2026-10-19T09:00:00+08:00",
    "source": "课程通知",
}


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("EXTRACTION_PROVIDER", "mock")
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    with TestClient(app) as client:
        yield client


@pytest.fixture
def upstream(monkeypatch):
    real_client = httpx.AsyncClient
    monkeypatch.setenv("EXTRACTION_PROVIDER", "deepseek")
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setenv("DEEPSEEK_BASE_URL", "https://example.test/v1/")
    monkeypatch.setenv("DEEPSEEK_MODEL", "test-model")

    def install(handler):
        monkeypatch.setattr(
            httpx,
            "AsyncClient",
            lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs),
        )

    return install


def model_response(tasks):
    return httpx.Response(200, json={"choices": [{
        "finish_reason": "stop",
        "message": {"content": json.dumps({"tasks": tasks})},
    }]})


def test_mock_preserves_source_and_requires_confirmation(client):
    assert client.get("/health").json() == {"status": "ok"}
    response = client.post("/api/tasks/extract", json=PAYLOAD)
    assert response.status_code == 200
    data = response.json()
    assert data["provider"] == "mock"
    assert data["source_text"] == PAYLOAD["text"]
    assert data["source"] == PAYLOAD["source"]
    assert data["tasks"][0]["needs_confirmation"] is True
    assert data["tasks"][0]["due_at"] is None
    assert "mock" in data["warnings"][0]


@pytest.mark.parametrize("change", [
    {"text": "   "},
    {"text": "a" * 10001},
    {"message_time": "2026-10-19T09:00:00"},
    {"message_time": "not-a-date"},
    {"message_time": None},
])
def test_invalid_input_is_rejected(client, change):
    assert client.post("/api/tasks/extract", json=PAYLOAD | change).status_code == 422


def test_missing_key_is_explicit(client, monkeypatch):
    monkeypatch.setenv("EXTRACTION_PROVIDER", "deepseek")
    response = client.post("/api/tasks/extract", json=PAYLOAD)
    assert response.status_code == 503
    assert "DEEPSEEK_API_KEY" in response.json()["detail"]


def test_unknown_provider_is_rejected(client, monkeypatch):
    monkeypatch.setenv("EXTRACTION_PROVIDER", "typo")
    assert client.post("/api/tasks/extract", json=PAYLOAD).status_code == 503


def test_deepseek_request_and_multiple_tasks(client, upstream):
    def handler(request):
        body = json.loads(request.content)
        assert str(request.url) == "https://example.test/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer test-key"
        assert body["model"] == "test-model"
        assert body["thinking"] == {"type": "disabled"}
        assert body["response_format"] == {"type": "json_object"}
        message = json.loads(body["messages"][1]["content"])
        assert message == {"text": PAYLOAD["text"], "message_time": PAYLOAD["message_time"]}
        return model_response([
            {"title": "提交高数作业", "due_at": "2026-10-23T18:00:00+08:00",
             "due_text": "2026年10月23日18:00前"},
            {"title": "复习习题", "warnings": ["时间未明确"]},
        ])

    upstream(handler)
    response = client.post("/api/tasks/extract", json=PAYLOAD)
    assert response.status_code == 200
    tasks = response.json()["tasks"]
    assert len(tasks) == 2
    assert tasks[0]["due_at"] == "2026-10-23T18:00:00+08:00"
    assert all(task["needs_confirmation"] for task in tasks)
    assert tasks[1]["due_at"] is None


@pytest.mark.parametrize("due_text", [None, "明天晚上"])
def test_unsupported_deadline_is_cleared(client, upstream, due_text):
    upstream(lambda request: model_response([{
        "title": "作业", "due_at": "2026-10-23T18:00:00+08:00", "due_text": due_text,
    }]))
    response = client.post("/api/tasks/extract", json=PAYLOAD)
    assert response.status_code == 200
    task = response.json()["tasks"][0]
    assert task["due_at"] is None
    assert task["warnings"]


def test_non_actionable_notification_returns_no_tasks(client, upstream):
    upstream(lambda request: model_response([]))
    response = client.post("/api/tasks/extract", json=PAYLOAD | {"text": "同学们早上好"})
    assert response.status_code == 200
    assert response.json()["tasks"] == []


@pytest.mark.parametrize("content,finish_reason", [
    ("", "stop"),
    ("not json", "stop"),
    ('{"tasks": []}', "length"),
    ('{"unexpected": []}', "stop"),
    ('{"tasks": [{"title": "作业", "due_at": "2026-10-23T18:00:00"}]}', "stop"),
    ('{"tasks": [{"title": "作业", "needs_confirmation": false}]}', "stop"),
])
def test_bad_model_output_is_rejected(client, upstream, content, finish_reason):
    upstream(lambda request: httpx.Response(200, json={"choices": [{
        "finish_reason": finish_reason, "message": {"content": content},
    }]}))
    assert client.post("/api/tasks/extract", json=PAYLOAD).status_code == 502


@pytest.mark.parametrize("failure,expected_status", [
    ("timeout", 504), ("connection", 502), ("http", 502),
])
def test_upstream_errors_are_sanitized(client, upstream, failure, expected_status):
    def handler(request):
        if failure == "timeout":
            raise httpx.ReadTimeout("test-key", request=request)
        if failure == "connection":
            raise httpx.ConnectError("test-key", request=request)
        return httpx.Response(401, text="test-key")

    upstream(handler)
    response = client.post("/api/tasks/extract", json=PAYLOAD)
    assert response.status_code == expected_status
    assert "test-key" not in response.text


def test_original_text_keeps_whitespace(client):
    text = "  高数作业\n请提交习题。  "
    response = client.post("/api/tasks/extract", json=PAYLOAD | {"text": text})
    assert response.status_code == 200
    assert response.json()["source_text"] == text
