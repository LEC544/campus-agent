from typing import Literal

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, field_validator


class ExtractRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str = Field(min_length=1, max_length=10000)
    message_time: AwareDatetime
    source: str = Field(default="手动粘贴", min_length=1, max_length=200)


    @field_validator("text", "source")
    @classmethod
    def reject_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("内容不能为空白")
        return value


class TaskCandidate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    title: str = Field(min_length=1, max_length=200)
    course: str | None = Field(default=None, max_length=200)
    description: str = Field(default="", max_length=10000)
    due_at: AwareDatetime | None = None
    due_text: str | None = Field(default=None, max_length=1000)
    warnings: list[str] = Field(default_factory=list, max_length=20)
    needs_confirmation: Literal[True] = True


class ModelResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tasks: list[TaskCandidate] = Field(max_length=30)


class ExtractResponse(BaseModel):
    provider: Literal["mock", "deepseek"]
    source: str
    source_text: str
    message_time: AwareDatetime
    tasks: list[TaskCandidate]
    warnings: list[str] = Field(default_factory=list)
