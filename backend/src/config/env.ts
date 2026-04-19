const REQUIRED_ENV_VARS = [
  'DATABASE_URL',
  'JWT_SECRET',
  'AI_SERVICE_URL',
  'AI_SERVICE_API_KEY',
] as const;

for (const varName of REQUIRED_ENV_VARS) {
  if (!process.env[varName]) {
    console.error(`[Config] Missing required environment variable: ${varName}`);
    process.exit(1);
  }
}

export const config = {
  databaseUrl: process.env.DATABASE_URL as string,
  jwtSecret: process.env.JWT_SECRET as string,
  aiServiceUrl: process.env.AI_SERVICE_URL as string,
  aiServiceApiKey: process.env.AI_SERVICE_API_KEY as string,
  port: parseInt(process.env.PORT ?? '3000', 10),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY,
};
