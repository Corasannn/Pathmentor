import type { AppConfig } from '../config/env';
import { HttpError } from '../errors/httpError';
import type { ChatRequest } from '../schemas/chat';

type OpenRouterConfig = AppConfig['openRouter'];

const mapStatus = (status: number): HttpError => {
  if (status === 429) {
    return new HttpError(429, 'Upstream rate limit exceeded');
  }

  if (status === 401 || status === 403) {
    return new HttpError(502, 'Upstream authentication failed');
  }

  return new HttpError(502, 'Upstream service unavailable');
};

export const streamCompletion = async (
  payload: ChatRequest,
  config: OpenRouterConfig,
  signal?: AbortSignal
): Promise<Response> => {
  const messages = [
    ...(payload.systemPrompt
      ? [{ role: 'system' as const, content: payload.systemPrompt }]
      : []),
    { role: 'user' as const, content: payload.prompt }
  ];

  try {
    const response = await fetch(`${config.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: config.model,
        stream: true,
        messages,
        temperature: payload.temperature ?? 0.7
      }),
      signal
    });

    if (!response.ok) {
      await response.body?.cancel();
      throw mapStatus(response.status);
    }

    return response;
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }

    if (signal?.aborted) {
      throw error as Error;
    }

    throw new HttpError(502, 'Failed to reach OpenRouter');
  }
};
