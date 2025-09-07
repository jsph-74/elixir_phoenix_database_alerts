import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL || 'http://localhost:4000';

export default defineConfig({
  testDir: './tests',
  fullyParallel: process.env.PLAYWRIGHT_WORKERS ? parseInt(process.env.PLAYWRIGHT_WORKERS) > 1 : false, // Sequential for data manipulation tests unless workers specified
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.PLAYWRIGHT_WORKERS ? parseInt(process.env.PLAYWRIGHT_WORKERS) : 1, // Single worker to avoid database conflicts
  reporter: process.env.CI ? 'github' : [['list'], ['html', { open: 'never' }]],
  timeout: 30000, // 30s timeout for complex alert operations
  
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    ignoreHTTPSErrors: true, // Accept self-signed certificates for dev/test
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Web server is managed by docker-compose, not by Playwright
  // webServer: {
  //   command: 'echo "Web server should be running via docker-compose"',
  //   url: baseURL,
  //   reuseExistingServer: true,
  // },
});