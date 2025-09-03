import { test, expect } from '@playwright/test';
import { TestDatabaseHelper } from '../helpers/database';
import { AlertTestHelper } from '../helpers/alert-helper';

test.describe('Alert Updates and Delete Tests', () => {
  let dbHelper: TestDatabaseHelper;
  let alertHelper: AlertTestHelper;

  test.beforeEach(async ({ page }) => {
    dbHelper = new TestDatabaseHelper();
    alertHelper = new AlertTestHelper(page);
  });

  test.afterEach(async () => {
    if (dbHelper) {
      await dbHelper.disconnect();
    }
  });

  test('T21 - should edit alert description', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '1-test-sql-diff-history');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    await expect(page.locator('h1')).toContainText('Edit');
    
    // Update description
    await page.fill('#alert_description', 'Updated description via T21');
    await page.click('#submit-btn');
    
    // Should redirect to alert detail
    await expect(page.locator('h1')).toContainText('1-test-sql-diff-history');
  });

  test('T22 - should reject invalid cron format', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '1-test-sql-diff-history');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    await expect(page.locator('h1')).toContainText('Edit');
    
    // Try invalid cron format
    await page.fill('#alert_schedule', 'not a valid cron');
    await page.click('#submit-btn');
    
    // Should stay on edit page with error
    await expect(page.locator('h1')).toContainText('Edit');
    await expect(page.locator('.help-block')).toBeVisible();
    const errorMessage = await page.locator('.help-block').textContent();
    expect(errorMessage).toMatch(/cron|schedule|format/i);
  });

  test('T23 - should edit alert threshold', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '3-test-sql-diff-non-sql');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    await expect(page.locator('h1')).toContainText('Edit');
    
    // Update threshold
    await page.fill('#alert_threshold', '15');
    await page.click('#submit-btn');
    
    // Should redirect to alert detail
    await expect(page.locator('h1')).toContainText('3-test-sql-diff-non-sql');
  });

  test('T24 - should prevent saving edit with invalid SQL', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '4-test-timeline-workflow');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    await expect(page.locator('h1')).toContainText('Edit');
    
    // Try to save invalid SQL
    await page.fill('#alert_query', 'COMPLETELY BROKEN SQL SYNTAX');
    await page.click('#submit-btn');
    
    // Should stay on edit page with error
    await expect(page.locator('h1')).toContainText('Edit');
    await expect(page.locator('.help-block')).toBeVisible();
  });

  test('T25 - edit preserves unchanged fields', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '5-test-validation-broken-sql');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    // Get initial values
    const originalName = await page.inputValue('#alert_name');
    const originalContext = await page.inputValue('#alert_context');
    
    // Only change description
    await page.fill('#alert_description', 'Only description changed');
    await page.click('#submit-btn');
    
    // Go back to edit to verify other fields preserved
    const alertRowAgain = await alertHelper.findAlertRowInContextListing('test', originalName);
    await alertRowAgain.locator('a[href*="/edit"]').first().click();
    
    const newName = await page.inputValue('#alert_name');
    const newContext = await page.inputValue('#alert_context');
    
    expect(newName).toBe(originalName);
    expect(newContext).toBe(originalContext);
  });

  test('T26 - should delete alert and remove from context listing', async ({ page }) => {
    // Create a test alert to delete
    const alert = await alertHelper.createTestAlert({
      name: 'Delete Test Alert',
      query: 'SELECT 1 as delete_test',
      threshold: '1'
    });

    const stayedOnForm = await alert.stayedOnForm();
    expect(stayedOnForm).toBe(false); // Alert creation should succeed

    await expect(alert.page.locator('h1')).toContainText('Delete Test Alert');

    // Delete button is on the detail page with specific classes
    const deleteButton = alert.page.locator('a.btn-icon-danger[title="Delete alert"]');
    await expect(deleteButton).toBeVisible();
    
    // Set up dialog handler before clicking
    alert.page.on('dialog', async dialog => {
      await dialog.accept();
    });
    
    await deleteButton.click();
    
    // Wait for deletion to complete and redirect
    await alert.page.waitForTimeout(3000);
    
    // Check if we were redirected (successful deletion should redirect away)
    const currentUrl = alert.page.url();
    
    // Verify alert no longer appears in context listing  
    await page.goto(`/alerts?context=${alert.context}`);
    await page.waitForTimeout(1000); // Allow page to load
    
    // Use a more specific selector to avoid false positives
    const alertLinks = page.locator(`a:has-text("${alert.name}")`);
    await expect(alertLinks).toHaveCount(0);
  });
});