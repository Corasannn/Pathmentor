import cors, { type CorsOptions } from 'cors';
import express from 'express';
import type { AppConfig } from './config/env';
import { requestContext } from './middleware/requestContext';
import { chatRateLimiter } from './middleware/rateLimiter';
import { errorHandler } from './middleware/errorHandler';
import { HttpError } from './errors/httpError';
import { createChatRouter } from './routes/chat';

const createCorsConfig = (allowedOrigins: string[]): CorsOptions => {
  if (allowedOrigins.length === 0) {
    return { origin: true, credentials: true };
  }

  return {
    credentials: true,
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new HttpError(403, 'Origin not allowed', true));
    }
  };
};

export const createApp = (config: AppConfig) => {
  const app = express();

  app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use(cors(createCorsConfig(config.allowedOrigins)));
  app.use(express.json({ limit: '1mb' }));
  app.use(requestContext);
  app.use('/api/chat', chatRateLimiter, createChatRouter(config));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use((_req, _res, next) => {
    next(new HttpError(404, 'Not Found', true));
  });

  app.use(errorHandler);

  return app;
};
