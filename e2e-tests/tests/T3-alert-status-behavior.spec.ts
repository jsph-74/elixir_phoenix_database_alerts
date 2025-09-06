import { test, expect } from '@playwright/test';
import { TestDatabaseHelper } from '../helpers/database';
import { AlertTestHelper } from '../helpers/alert-helper';

test.describe('Alert Status Behavior Tests', () => {
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

  test('T31 - new alert shows never run status', async ({ page }) => {
    // Create a fresh alert that will be in "never run" state
    const randomId = Math.random().toString(36).substring(7);
    const alert = await alertHelper.createTestAlert({
      name: 'Never Run Status Test',
      query: 'SELECT 1 as test_value',
      threshold: '2',
      context: 'T31'
    });

    const stayedOnForm = await alert.stayedOnForm();
    expect(stayedOnForm).toBe(false); // Alert creation should succeed

    await expect(alert.page.locator('h1')).toContainText('Never Run Status Test');
    
    // Status should be "never run" (no "since")
    const statusCell = alert.page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('never run');
    await expect(statusCell).not.toContainText('since');

    await alertHelper.findAlertRowInContextListing(alert.context, alert.name);
    alertHelper.deleteAlertFromAlertDetail()
  });

  test('T32 - running alert with broken connection shows broken status', async ({ page }) => {
    // Use seeded alert with broken data source
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '7-test-broken-connection');
    
    // Run alert directly from the listing row
    const runButton = alertRow.locator('button[title="Run alert"], button:has-text("Run")').first();
    await runButton.click();
    await page.waitForTimeout(2000);
    
    // Check status in the same row - should show "broken" due to connection failure  
    const statusCell = alertRow.locator('td').filter({ hasText: /broken/i }).last();
    await expect(statusCell).toBeVisible();
  });

  test('T33 - running alert with broken SQL shows broken status', async ({ page }) => {
    // Use seeded alert with broken SQL
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '8-test-broken-sql');

    // Run alert directly from the listing row
    const runButton = alertRow.locator('button[title="Run alert"], button:has-text("Run")').first();
    await runButton.click();
    await page.waitForTimeout(2000);
    
    // Check status in the same row - should show "broken" due to SQL error
    const statusCell = alertRow.locator('td').filter({ hasText: /broken/i }).last();
    await expect(statusCell).toBeVisible();
  });

  test('T34 - editing alert query shows needs refreshing status', async ({ page }) => {
    // Use seeded alert for editing
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '2-test-sql-diff-multiple');
    await alertRow.locator('a[href*="/edit"]').first().click();
    
    await expect(page.locator('h1')).toContainText('Edit');
    
    // Update query
    await page.fill('#alert-edit-form_query', 'SELECT 7 UNION SELECT 8 UNION SELECT 9');
    await page.click('#submit-btn');

    // Should redirect to alert detail
    await expect(page.locator('h1')).toContainText('2-test-sql-diff-multiple');
    
    // Status should show "needs refreshing" after query change
    const statusCell = page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('needs refreshing');
  });

  test('T35 - alert with results under threshold shows under threshold status', async ({ page }) => {
    // Create alert that returns few results (under threshold)
    const randomId = Math.random().toString(36).substring(7);
    const alert = await alertHelper.createTestAlert({
      name: 'Under Threshold Test',
      query: 'SELECT 1 UNION SELECT 2', // 2 rows
      threshold: '5', // Threshold is 5, so 2 rows is under,
      context: 'T35'
    });

    await expect(alert.page.locator('h1')).toContainText('Under Threshold Test');

    await alertHelper.runAlertFromAlertDetail();
    await page.waitForTimeout(2000);
    const statusCell = alert.page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('under threshold');
    
    await alertHelper.findAlertRowInContextListing(alert.context, alert.name);
    alertHelper.deleteAlertFromAlertDetail()
  });

  test('T36 - alert with zero results shows good status', async ({ page }) => {
    // Create alert that returns no results (good status)
    const randomId = Math.random().toString(36).substring(7);
    const alert = await alertHelper.createTestAlert({
      name: 'Good Status Test',
      query: 'SELECT 1 WHERE 1=0', // 0 rows
      threshold: '5', // Any threshold, 0 results = good       
      context: 'T36'

    });

    await expect(alert.page.locator('h1')).toContainText('Good Status Test');

    await alertHelper.runAlertFromAlertDetail();
    await page.waitForTimeout(2000);
    const statusCell = alert.page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('good');

    await alertHelper.findAlertRowInContextListing(alert.context, alert.name);
    alertHelper.deleteAlertFromAlertDetail()
  });

  test('T36b - alert with results equal to threshold shows bad status', async ({ page }) => {
    // Create alert that returns results equal to threshold
    const randomId = Math.random().toString(36).substring(7);
    const alert = await alertHelper.createTestAlert({
      name: 'Bad Status Test Equal',
      query: 'SELECT 1 UNION SELECT 2 UNION SELECT 3', // 3 rows
      threshold: '3', // Threshold is 3, so 3 >= 3 = bad
      context: 'T36b'
    });

    await expect(alert.page.locator('h1')).toContainText('Bad Status Test Equal');

    await alertHelper.runAlertFromAlertDetail();
    await page.waitForTimeout(2000);
    const statusCell = alert.page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('bad');

    await alertHelper.findAlertRowInContextListing(alert.context, alert.name);
    alertHelper.deleteAlertFromAlertDetail()
  });

  test('T37 - alert with results above threshold shows bad status', async ({ page }) => {
    // Create alert that returns many results (above threshold)
    const randomId = Math.random().toString(36).substring(7);
    const alert = await alertHelper.createTestAlert({
      name: 'Bad Status Test',
      query: 'SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6', // 6 rows
      threshold: '4', // Threshold is 4, so 6 rows = bad
      context: 'T37'
    });

    await expect(alert.page.locator('h1')).toContainText('Bad Status Test');

    // Run the alert
    await alertHelper.runAlertFromAlertDetail();
    await page.waitForTimeout(2000);
    const statusCell = alert.page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('bad');
    await alertHelper.findAlertRowInContextListing(alert.context, alert.name);
    alertHelper.deleteAlertFromAlertDetail()
  });
});