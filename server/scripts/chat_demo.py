"""通过本地后端验证两轮真实云端对话，不读取或打印 API Key。"""

import argparse
import sys

import httpx


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    messages = []
    prompts = [
        "请记住：我叫小林，周五有高数考试。请简短确认。",
        "根据我刚才告诉你的信息，我叫什么，什么时候考什么科目？",
    ]
    try:
        # 联调脚本直接连接本地后端，避免系统代理转发 127.0.0.1。
        with httpx.Client(timeout=75.0, trust_env=False) as client:
            for prompt in prompts:
                messages.append({"role": "user", "content": prompt})
                response = client.post(f"{args.base_url.rstrip('/')}/api/chat", json={"messages": messages})
                if response.status_code != 200:
                    print(f"后端请求失败（HTTP {response.status_code}）：{response.text}", file=sys.stderr)
                    return 1
                message = response.json()["message"]
                messages.append(message)
                print(f"你：{prompt}\nDeepSeek：{message['content']}\n")
    except (httpx.HTTPError, ValueError, KeyError) as error:
        print(f"联调失败（{type(error).__name__}），请检查后端是否启动及地址是否正确。", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
