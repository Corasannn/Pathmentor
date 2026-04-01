import { createApp } from './app';
import { config } from './config/env';
import { logger } from './logging/logger';

const app = createApp(config);

const server = app.listen(config.port, () => {
  logger.info(`🚀 Server listening on http://localhost:${config.port}`);
});

const SHUTDOWN_TIMEOUT_MS = 10_000;

const shutdown = (signal: string) => {
  logger.info({ signal }, 'Received shutdown signal');

  const forceExit = setTimeout(() => {
    logger.error('Shutdown timed out — forcing exit');
    process.exit(1);
  }, SHUTDOWN_TIMEOUT_MS);
  forceExit.unref();

  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'Unhandled promise rejection');
  process.exit(1);
});
