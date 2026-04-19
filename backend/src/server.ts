import './config/env'; // Validate env vars first (fail-fast)
import { config } from './config/env';
import { connectDB } from './config/database';
import { createApp } from './app';

async function main(): Promise<void> {
  await connectDB();

  const app = createApp();

  app.listen(config.port, () => {
    console.log(`[Server] Running on port ${config.port} (${config.nodeEnv})`);
  });
}

main().catch((err) => {
  console.error('[Server] Fatal error during startup:', err);
  process.exit(1);
});
