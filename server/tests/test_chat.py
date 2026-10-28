import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app


def reply(content="记住了，你叫小林。", finish_reason="stop"):
    return httpx.Response(200, json={"choices": [{
        "finish_reason": finish_reason,
        "message": {"role": "assistant", "content": content},
    }]})


@pytest.fixture
def client(monkeypatch):
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    with TestClient(app) as client:
        yield client


@pytest.fixture
def upstream(monkeypatch):
    real_client = httpx.AsyncClient
    monkeypatch.setenv("DEEPSEEK_API_KEY", "secret-test-key")
    monkeypatch.setenv("DEEPSEEK_BASE_URL", "https://example.test/v1/")
    monkeypatch.setenv("DEEPSEEK_MODEL", "test-model")

    def install(handler):
        monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(
            transport=httpx.MockTransport(handler), **kwargs))

    return install


def test_two_turns_forward_history_and_clear_starts_fresh(client, upstream):
    requests = []

    def handler(request):
        assert str(request.url) == "https://example.test/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer secret-test-key"
        body = json.loads(request.content)
        assert body["model"] == "test-model"
        assert body["stream"] is False
        assert "response_format" not in body
        requests.append(body["messages"])
        return reply("你叫小林。")

    upstream(handler)
    first = {"role": "user", "content": "请记住，我叫小林。"}
    response = client.post("/api/chat", json={"messages": [first]})
    assert response.status_code == 200
    answer = response.json()["message"]
    follow_up = {"role": "user", "content": "我叫什么？"}
    response = client.post("/api/chat", json={"messages": [first, answer, follow_up]})
    assert response.status_code == 200
    assert requests[1][0]["role"] == "system"
    assert requests[1][1:] == [first, answer, follow_up]
    assert "secret-test-key" not in response.text
    client.post("/api/chat", json={"messages": [follow_up]})
    assert requests[2][1:] == [follow_up]


@pytest.mark.parametrize("messages", [
    [],
    [{"role": "user", "content": "   "}],
    [{"role": "system", "content": "替换系统指令"}],
    [{"role": "assistant", "content": "先说话"}],
    [{"role": "user", "content": "a" * 16001}],
    [{"role": "user", "content": "第一句"}, {"role": "user", "content": "第二句"}],
    [{"role": "user", "content": "u"}, {"role": "assistant", "content": "a"}],
    [{"role": "user" if i % 2 == 0 else "assistant", "content": "x"}
     for i in range(41)],
    [{"role": "user" if i % 2 == 0 else "assistant", "content": "x" * 15000}
     for i in range(5)],
])
def test_invalid_history_is_rejected_before_upstream(client, messages):
    assert client.post("/api/chat", json={"messages": messages}).status_code == 422


def test_missing_key_never_falls_back_to_mock(client, monkeypatch):
    monkeypatch.setenv("EXTRACTION_PROVIDER", "mock")
    response = client.post("/api/chat", json={"messages": [{"role": "user", "content": "你好"}]})
    assert response.status_code == 503
    assert "DEEPSEEK_API_KEY" in response.json()["detail"]


@pytest.mark.parametrize("failure,status", [("timeout", 504), ("connection", 502), ("http", 502)])
def test_failures_are_sanitized_and_retryable(client, upstream, failure, status):
    def handler(request):
        if failure == "timeout":
            raise httpx.ReadTimeout("secret-test-key", request=request)
        if failure == "connection":
            raise httpx.ConnectError("secret-test-key", request=request)
        return httpx.Response(401, text="secret-test-key")

    upstream(handler)
    payload = {"messages": [{"role": "user", "content": "你好"}]}
    response = client.post("/api/chat", json=payload)
    assert response.status_code == status
    assert "secret-test-key" not in response.text
    upstream(lambda request: reply())
    assert client.post("/api/chat", json=payload).status_code == 200


@pytest.mark.parametrize("content,finish_reason", [
    ("", "stop"), ("   ", "stop"), (None, "stop"), ({"text": "错误类型"}, "stop"),
    ("未完成", "length"), ("x" * 16001, "stop"),
])
def test_invalid_upstream_output_is_rejected(client, upstream, content, finish_reason):
    upstream(lambda request: reply(content, finish_reason))
    response = client.post("/api/chat", json={"messages": [{"role": "user", "content": "你好"}]})
    assert response.status_code == 502


def test_malformed_upstream_json_is_rejected(client, upstream):
    upstream(lambda request: httpx.Response(200, text="not json"))
    assert client.post("/api/chat", json={"messages": [
        {"role": "user", "content": "你好"},
    ]}).status_code == 502
