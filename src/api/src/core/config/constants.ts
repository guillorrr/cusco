/**
 * Application-wide constants
 */
export const APP_CONSTANTS = {
  APP_NAME: process.env.APP_NAME ?? 'app',
  PAGINATION: {
    DEFAULT_PAGE: 1,
    DEFAULT_LIMIT: 10,
    MAX_LIMIT: 100,
  },
  AUTH: {
    SALT_ROUNDS: 10,
    TOKEN_EXPIRATION: '1h',
    REFRESH_TOKEN_EXPIRATION: '7d',
  },
} as const;
