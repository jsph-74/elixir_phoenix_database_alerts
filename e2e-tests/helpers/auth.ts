import { Page, expect } from '@playwright/test';

/**
 * Handle master password authentication if the login form is present
 * @param page - Playwright page object
 * @param masterPassword - The master password to use (optional, will use MASTER_PASSWORD env var if not provided)
 */
export async function handleMasterPasswordLogin(page: Page, masterPassword?: string) {
  const password = masterPassword || process.env.MASTER_PASSWORD;
  
  if (!password) {
    return;
  }
  
  try {
    // Check if we're on the login page by looking for the master password field
    const passwordField = page.locator('#master_password');
    
    if (await passwordField.isVisible({ timeout: 5000 })) {
      // Fill the master password
      await passwordField.fill(password);
      
      // Submit the form (Enter key or find submit button)  
      await passwordField.press('Enter');
      
      // Wait for navigation after successful login (may redirect to default context)
      await page.waitForLoadState('networkidle', { timeout: 10000 });
    }
  } catch (error) {
    // If login elements don't exist or timeout, assume no master password required
  }
}

/**
 * Navigate to a URL and handle master password authentication if needed
 * @param page - Playwright page object  
 * @param url - URL to navigate to
 * @param masterPassword - The master password to use (optional, will use MASTER_PASSWORD env var if not provided)
 */
export async function navigateWithAuth(page: Page, url: string, masterPassword?: string) {
  await page.goto(url);
  await handleMasterPasswordLogin(page, masterPassword);
  
  // After authentication, ensure we're on the intended URL
  // (login might redirect to default context, so navigate to intended page again)
  const currentUrl = page.url();
  const baseUrl = currentUrl.split('?')[0];
  const targetPath = url.split('?')[0];
  const targetQuery = url.includes('?') ? url.split('?')[1] : '';
  
  if (!currentUrl.includes(targetPath) || (targetQuery && !currentUrl.includes(targetQuery))) {
    await page.goto(url);
  }
}