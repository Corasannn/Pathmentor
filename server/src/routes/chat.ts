import { Readable } from 'node:stream';
import type { ReadableStream as WebReadableStream } from 'node:stream/web';
import { Router } from 'express';
import type { AppConfig } from '../config/env';
import { HttpError } from '../errors/httpError';
import { chatRequestSchema } from '../schemas/chat';
import { streamCompletion } from '../services/openrouterClient';

export const createChatRouter = (config: AppConfig) => {
  const router = Router();

  router.post('/', async (req, res, next) => {
    const parsed = chatRequestSchema.safeParse(req.body);

    if (!parsed.success) {
      return next(new HttpError(400, 'Invalid request body', true));
    }

    const abortController = new AbortController();

    req.on('close', () => {
      abortController.abort();
    });

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();

    try {
      const upstreamResponse = await streamCompletion(
        parsed.data,
        config.openRouter,
        abortController.signal
      );

      if (!upstreamResponse.body) {
        throw new HttpError(502, 'Upstream response missing body');
      }

      const webStream = upstreamResponse.body as unknown as WebReadableStream<Uint8Array>;
      const stream = Readable.fromWeb(webStream);

      for await (const chunk of stream) {
        res.write(chunk);
      }

      res.end();
    } catch (error) {
      if (abortController.signal.aborted) {
        if (!res.writableEnded) res.end();
        return;
      }

      if (!res.headersSent) {
        return next(error);
      }

      const message =
        error instanceof Error ? error.message : 'Internal Server Error';

      if (!res.writableEnded) {
        try {
          res.write(`event: error\ndata: ${JSON.stringify({ message })}\n\n`);
          res.end();
        } catch {
          // Socket already destroyed — nothing to do
        }
      }
    }
  });

  return router;
};
