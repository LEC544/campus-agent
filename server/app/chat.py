"""最小无状态多轮聊天：客户端携带历史，密钥与系统提示词留在服务端。"""

import os
from typing import Literal

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator

router = APIRouter(prefix="/api/chat", tags=["chat"])

SYSTEM_PROMPT = "你是校园学习助手，请用中文清晰回答，并结合此前对话理解用户的追问。"


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=16000)

    @field_validator("content")
    @classmethod
    def reject_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("消息不能为空白")
        return value


class ChatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    messages: list[ChatMessage] = Field(min_length=1, max_length=39)

    @field_validator("messages")
    @classmethod
    def validate_history(cls, messages: list[ChatMessage]) -> list[ChatMessage]:
        if len(messages) % 2 != 1:
            raise ValueError("历史须以用户消息开始和结束，用户与助手交替出现")
        for index, message in enumerate(messages):
            expected = "user" if index % 2 == 0 else "assistant"
            if message.role != expected:
                raise ValueError("历史须以用户消息开始和结束，用户与助手交替出现")
        if sum(len(message.content) for message in messages) > 60000:
            raise ValueError("对话总长度超过 60000 字符，请清空会话后重试")
        return messages


class ChatResponse(BaseModel):
    provider: Literal["deepseek"] = "deepseek"
    model: str
    message: ChatMessage


@router.post("", response_model=ChatResponse)
async def chat(payload: ChatRequest):
    api_key = os.getenv("DEEPSEEK_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(503, "请在 server/.env 配置 DEEPSEEK_API_KEY 并重启服务")
    model = os.getenv("DEEPSEEK_MODEL", "deepseek-flash").strip()
    base_url = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com").strip().rstrip("/")
    if not model or not base_url:
        raise HTTPException(503, "请检查 DEEPSEEK_MODEL 和 DEEPSEEK_BASE_URL 配置")

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        *[message.model_dump() for message in payload.messages],
                    ],
                    "thinking": {"type": "disabled"},
                    "max_tokens": 4096,
                    "stream": False,
                },
            )
            response.raise_for_status()
    except httpx.TimeoutException:
        raise HTTPException(504, "模型响应超时，请重试，当前消息尚未加入对话") from None
    except httpx.HTTPError:
        raise HTTPException(502, "模型请求失败，请检查服务端地址、密钥、额度或网络") from None

    try:
        choice = response.json()["choices"][0]
        content = choice["message"]["content"]
        if choice["finish_reason"] != "stop" or not isinstance(content, str):
            raise ValueError("incomplete response")
        message = ChatMessage(role="assistant", content=content)
    except (ValueError, KeyError, IndexError, TypeError):
        raise HTTPException(502, "模型回复为空、不完整或格式错误，请重试") from None

    return ChatResponse(model=model, message=message)
