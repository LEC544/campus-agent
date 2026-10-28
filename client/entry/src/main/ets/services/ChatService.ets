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

interface ApiError {
  detail: string;
}

export async function sendChat(baseUrl: string, messages: ChatMessage[]): Promise<ChatMessage> {
  const url: string = baseUrl.trim().replace(/\/+$/, '');
  if (!/^https?:\/\/[^\s]+$/.test(url)) {
    throw new Error('请输入有效的后端地址，例如 http://192.168.1.10:8000');
  }
  const request = http.createHttp();
  const payload: ChatRequest = { messages: messages };
  try {
    const response = await request.request(`${url}/api/chat`, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify(payload),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 70000
    });
    const body: string = response.result as string;
    if (response.responseCode !== 200) {
      if (response.responseCode === 422) {
        throw new Error('消息或历史超出限制：单条最多 16000 字符，对话合计 60000 字符，最多 20 轮');
      }
      const error: ApiError = JSON.parse(body) as ApiError;
      throw new Error(typeof error.detail === 'string' ? error.detail : '请求失败，请检查后端服务');
    }
    const data: ChatResponse = JSON.parse(body) as ChatResponse;
    if (data.message.role !== 'assistant' || typeof data.message.content !== 'string' ||
      data.message.content.trim().length === 0) {
      throw new Error('后端回复格式异常，请重试');
    }
    return data.message;
  } finally {
    request.destroy();
  }
}
