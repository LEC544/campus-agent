# 校园助手客户端

基于 ArkUI-X 与 ArkTS 的原生聊天页面，入口是 `entry/src/main/ets/pages/Index.ets`。

## 已实现

- 欢迎页与三个示例问题，点击后填入输入框，由用户确认发送。
- 左右区分的聊天气泡、消息复制、回复等待状态和自动滚动。
- 失败后恢复输入，支持修改后重发，不把失败请求加入聊天历史。
- 新建对话前确认清空，保留输入草稿。
- 可收起的服务连接设置，以及后端健康检查。
- 每轮携带历史上下文，支持最多 20 轮对话。

聊天记录和连接地址保留在当前页面内，退出后不保存。模型密钥由服务端配置，客户端不读取或保存密钥。

## 运行步骤

1. 在 DevEco Studio 中打开本目录 `client/`，等待依赖同步完成。
2. 在项目的 `server/.env` 配置 `DEEPSEEK_API_KEY`。
3. 使用 Git Bash 启动后端：

```bash
cd /d/arkUI-X_agent/campus-agent
bash server/start.sh --host 0.0.0.0
```

4. 在 DevEco Studio 选择 HarmonyOS 设备或已启动的 HarmonyOS 模拟器，运行 `entry`。HarmonyOS 真机安装需要在 IDE 中配置对应签名；Android 使用下文的 ArkUI-X 构建流程。
5. 打开页面右上角“连接设置”，填写服务地址，再点击“检查连接”。

| 运行环境 | 后端地址 |
| --- | --- |
| Android 官方模拟器 | `http://10.0.2.2:8000` |
| 真机、HarmonyOS 模拟器 | 使用设备可访问的电脑局域网 IP，如 `http://192.168.1.10:8000` |

真机与电脑需要网络互通，后端端口需要允许通过电脑防火墙。真机上的 `127.0.0.1` 指向真机自身。检查连接只验证 `/health`；模型密钥、额度等会在实际发送消息时验证。

6. 发送“请记住：我叫小林，周五有高数考试”，收到回复后，再发送“我叫什么，什么时候考试？”，检查是否使用了前文。

Android APK 请使用 ArkUI-X CLI 的构建运行流程；它会同步 ArkTS 资源，单独打开 Android 工程直接构建可能使用旧资源。当前项目的 Android 工具链依赖尚未补齐。Android 调试包已有本地 HTTP 许可；iOS 联调请使用 HTTPS 服务。

## 代码位置

| 文件 | 职责 |
| --- | --- |
| `entry/src/main/ets/pages/Index.ets` | 页面布局、草稿、会话状态、交互 |
| `entry/src/main/ets/services/ChatService.ets` | 请求校验、网络调用、健康检查、错误提示 |
| `entry/src/main/module.json5` | HarmonyOS 网络权限 |
| `.arkui-x/android/app/src/debug/AndroidManifest.xml` | Android 调试包本地 HTTP 配置 |

## 当前范围

聊天记录不持久化，暂未接入 Redis、登录、会话列表或流式输出。单条消息最多 16000 字符，请求中的历史总长度最多 60000 字符；达到上限后提示新建对话。

接口与网络能力参考 [ArkUI-X 官方 HTTP 文档](https://github.com/arkui-x/docs/blob/master/zh-cn/application-dev/reference/apis/js-apis-http.md)。
