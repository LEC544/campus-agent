# Campus Agent 最小服务端

使用 Python 3.11+、FastAPI。支持云端 DeepSeek 多轮聊天、健康检查与通知文本提取。

## 多轮聊天 Demo

1. 在 `server/.env` 配置 `DEEPSEEK_API_KEY`，不要把密钥放进客户端或提交到 Git。
2. 使用 Git Bash 启动后端：

~~~bash
cd /d/arkUI-X_agent/campus-agent
bash server/start.sh --host 0.0.0.0
~~~

3. 在 DevEco Studio 打开 `client/`，运行聊天页面。
4. 页面后端地址：Android 官方模拟器用 `http://10.0.2.2:8000`，真机使用电脑局域网 IP，例如 `http://192.168.1.10:8000`；HarmonyOS 模拟器按其实际网络填写电脑可达地址。真机需与电脑互通，并允许本地端口通过防火墙。
5. 第一轮发送“请记住：我叫小林，周五有高数考试”，第二轮发送“我叫什么，什么时候考试？”，检查回答是否保留前文信息。

聊天始终调用真实 DeepSeek，与通知提取的 `EXTRACTION_PROVIDER=mock` 独立；缺少密钥会明确报错。配置如下：

~~~dotenv
DEEPSEEK_API_KEY=替换为你的真实密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash
~~~

`POST /api/chat` 接收 `messages`，每次包含历史中成功完成的用户与助手消息，最后追加当前用户消息；后端添加固定系统提示词，再请求 DeepSeek。后端不存储会话，不返回密钥；客户端关闭页面或点击“清空”后重新开始。失败时保留输入，点击发送即可重试，不会把失败消息写入历史。等待回复期间禁止重复发送和清空。

~~~json
{
  "messages": [
    {"role": "user", "content": "请记住，我叫小林。"},
    {"role": "assistant", "content": "记住了，你叫小林。"},
    {"role": "user", "content": "我叫什么？"}
  ]
}
~~~

响应包含 `provider`、`model` 和 `message: {"role":"assistant","content":"…"}`。请求中的角色只接受 `user` 和 `assistant`，须交替出现，以用户开始和结束。单条最多 16000 字符，发送给模型的对话合计最多 60000 字符，每个会话最多 20 轮；超过后需清空。采用非流式回复，模型超时为 60 秒。此限制是 Demo 输入上限，不是精确 token 预算。

可不启动客户端，直接测试真实云端连续两轮：

~~~bash
cd /d/arkUI-X_agent/campus-agent/server
./.venv/Scripts/python.exe scripts/chat_demo.py
~~~

该脚本只访问本地后端，由后端读取密钥；会发生两次真实模型调用。前端已声明 Harmony 网络权限；Android 的本地 HTTP 明文许可仅放在 debug 清单中，发布版应使用 HTTPS。当前未实现 iOS 的本地 HTTP 放行配置，iOS 联调请使用 HTTPS 后端。

此 Demo 用于本地联调，未实现登录或服务访问鉴权；不要将它直接暴露到公网。

[DeepSeek 官方多轮对话方案](https://api-docs.deepseek.com/guides/multi_round_chat/)

## 启动（Windows Git Bash）

推荐使用一键启动脚本，无需手动激活虚拟环境：

~~~bash
cd /d/arkUI-X_agent/campus-agent
bash server/start.sh
~~~

脚本自动创建虚拟环境（如缺失）、安装 requirements.txt 中的依赖，并在 .env 不存在时复制示例配置；已有配置会保留。默认监听 127.0.0.1:8000，启用热重载，按 Ctrl+C 停止。首次安装依赖需要联网。

可传入 Uvicorn 参数，例如更换端口或允许局域网访问：

~~~bash
bash server/start.sh --port 8001
bash server/start.sh --host 0.0.0.0
~~~

也可以手动配置：

~~~bash
cd /d/arkUI-X_agent/campus-agent/server
python -m venv .venv
source .venv/Scripts/activate
python -m pip install -r requirements.txt
test -f .env || cp .env.example .env
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
~~~

以后只需进入 server、激活虚拟环境并运行最后一条启动命令。

- 接口文档：http://127.0.0.1:8000/docs
- 健康检查：GET /health
- 提取任务：POST /api/tasks/extract

默认 EXTRACTION_PROVIDER=mock，无需密钥即可启动。mock 仅把原文回显为一条候选，截止时间为 null，并在 warnings 中明确提示；它不执行语义提取或日期解析。

## 请求示例

另开一个 Git Bash 终端执行：

~~~bash
curl -sS http://127.0.0.1:8000/health

curl -sS http://127.0.0.1:8000/api/tasks/extract \
  -H 'Content-Type: application/json' \
  --data-binary '{"text":"高数作业：2026年10月23日18:00前提交第三章习题。","message_time":"2026-10-19T09:00:00+08:00","source":"课程通知"}'
~~~

message_time 必填，必须是带时区偏移量的原消息时间，用于解释相对日期；不要把导入时间当作原消息时间。text 限制为 1–10000 字符，source 可省略，默认“手动粘贴”。

响应结构（以下为 mock 示例）：

~~~json
{
  "provider": "mock",
  "source": "课程通知",
  "source_text": "高数作业：2026年10月23日18:00前提交第三章习题。",
  "message_time": "2026-10-19T09:00:00+08:00",
  "tasks": [
    {
      "title": "高数作业：2026年10月23日18:00前提交第三章习题。",
      "course": null,
      "description": "高数作业：2026年10月23日18:00前提交第三章习题。",
      "due_at": null,
      "due_text": null,
      "warnings": ["尚未确定截止时间，请核对原文后补充"],
      "needs_confirmation": true
    }
  ],
  "warnings": ["当前为 mock 模式：仅将原文作为一条候选返回，未调用模型或解析时间"]
}
~~~

客户端应展示原文、候选结果与两层 warnings，让用户核对后再确认。所有候选的 needs_confirmation 都为 true；返回结果不代表已创建正式任务。

## 接入 DeepSeek

编辑 server/.env（不要提交真实密钥），然后重启服务：

~~~dotenv
EXTRACTION_PROVIDER=deepseek
DEEPSEEK_API_KEY=替换为你的真实密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash
~~~

服务端调用 /chat/completions，使用 JSON 输出并校验字段。调用只发送通知原文及消息时间；source 不发送。环境变量优先于 server/.env。

模型可返回多条候选或空列表。时间缺失、只有日期没有时刻或含歧义时，提示模型返回 null；没有原文时间依据的截止时间会被清空。程序校验格式、时区和原文时间片段，语义准确性仍需用户核对。

错误约定：422 为输入校验失败，503 为配置缺失或错误，502 为模型服务请求失败或返回格式异常，504 为模型服务超时。失败不会静默切换为 mock。

## 测试

在已激活虚拟环境的 server 目录运行：

~~~bash
python -m pip install -r requirements-dev.txt
python -m pytest -q
~~~

测试使用模拟上游响应，不需要真实密钥，不会调用付费模型服务。

## 客户端联调

本机使用 http://127.0.0.1:8000。真机联调时可将启动命令的 host 改为 0.0.0.0，客户端改用电脑的局域网 IP，并检查系统防火墙及客户端网络权限。真机上的 127.0.0.1 指向真机自身。

当前接口用于本地开发，未实现登录鉴权、任务存储、提醒或外部平台同步。

## 参考

- [FastAPI 基础示例](https://fastapi.tiangolo.com/tutorial/first-steps/)
- [FastAPI 请求体校验](https://fastapi.tiangolo.com/tutorial/body/)
- [DeepSeek JSON Output](https://api-docs.deepseek.com/guides/json_mode/)
