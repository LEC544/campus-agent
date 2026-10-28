import http from '@ohos.net.http';

export interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequest {
  messages: ChatMessage[];
}

interface ChatResponse {
  provider: string;
  model: string;
  message: ChatMessage;
}

interface HealthResponse {
  status: string;
}

interface ApiError {
  detail: string;
}

export const MAX_CHAT_TURNS: number = 20;
export const MAX_MESSAGE_LENGTH: number = 16000;
export const MAX_HISTORY_LENGTH: number = 60000;

function normalizeUrl(baseUrl: string): string {
  const url: string = baseUrl.trim().replace(/\/+$/, '');
  if (!/^https?:\/\/[^\s/?#]+(?:\/[^\s?#]*)?$/.test(url)) {
    throw new Error('请输入完整的服务地址，例如 http://192.168.1.10:8000');
  }
  return url;
}

async function requestBackend(baseUrl: string, path: string, method: http.RequestMethod,
  body: string = ''): Promise<http.HttpResponse> {
  const url: string = normalizeUrl(baseUrl);
  let request: http.HttpRequest | undefined = undefined;
  try {
    request = http.createHttp();
    return await request.request(`${url}${path}`, {
      method: method,
      header: { 'Content-Type': 'application/json' },
      extraData: body,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: method === http.RequestMethod.GET ? 10000 : 70000
    });
  } catch (_error) {
    throw new Error('无法连接服务，请检查地址、后端是否启动，以及设备与电脑的网络');
  } finally {
    if (request !== undefined) {
      request.destroy();
    }
  }
}

function responseError(response: http.HttpResponse): string {
  if (response.responseCode === 404) {
    return '未找到对应接口，请确认地址指向 Campus Agent 后端';
  }
  if (response.responseCode === 422) {
    return '消息或对话超出限制，请缩短内容或新建对话后重试';
  }
  try {
    const error: ApiError = JSON.parse(response.result as string) as ApiError;
    if (error && typeof error.detail === 'string') {
      return error.detail;
    }
  } catch (_error) {
    // 网关可能返回 HTML，避免直接把解析错误展示给用户。
  }
  return `服务暂时无法处理请求（HTTP ${response.responseCode}），请稍后重试`;
}

export async function checkConnection(baseUrl: string): Promise<void> {
  const response = await requestBackend(baseUrl, '/health', http.RequestMethod.GET);
  if (response.responseCode !== 200) {
    throw new Error(responseError(response));
  }
  let health: HealthResponse;
  try {
    health = JSON.parse(response.result as string) as HealthResponse;
  } catch (_error) {
    throw new Error('服务返回格式异常，请确认连接的是 Campus Agent 后端');
  }
  if (!health || health.status !== 'ok') {
    throw new Error('服务返回格式异常，请确认连接的是 Campus Agent 后端');
  }
}

export async function sendChat(baseUrl: string, messages: ChatMessage[]): Promise<ChatMessage> {
  if (messages.length > MAX_CHAT_TURNS * 2 - 1) {
    throw new Error('当前对话已满 20 轮，请新建对话后继续');
  }
  let totalLength: number = 0;
  for (const message of messages) {
    if (message.content.length > MAX_MESSAGE_LENGTH) {
      throw new Error('单条消息最多 16000 字符，请缩短后重试');
    }
    totalLength += message.content.length;
  }
  if (totalLength > MAX_HISTORY_LENGTH) {
    throw new Error('当前对话内容较长，请新建对话后继续');
  }
  const payload: ChatRequest = { messages: messages };
  const response = await requestBackend(baseUrl, '/api/chat', http.RequestMethod.POST, JSON.stringify(payload));
  if (response.responseCode !== 200) {
    throw new Error(responseError(response));
  }
  let data: ChatResponse;
  try {
    data = JSON.parse(response.result as string) as ChatResponse;
  } catch (_error) {
    throw new Error('回复格式异常，请重试');
  }
  if (!data || !data.message || data.message.role !== 'assistant' ||
    typeof data.message.content !== 'string' || data.message.content.trim().length === 0) {
    throw new Error('回复格式异常，请重试');
  }
  return data.message;
}
