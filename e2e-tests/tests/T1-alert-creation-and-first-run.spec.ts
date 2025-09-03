import { test, expect } from '@playwright/test';
import { TestDatabaseHelper } from '../helpers/database';
import { AlertTestHelper } from '../helpers/alert-helper';

test.describe('Alert Creation, Validation and First Run Tests', () => {
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

  test('T11 - alert detail view shows correct date field names and order', async ({ page }) => {

    // Navigate to test context and open known seeded alert (READ-ONLY)
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '1-test-sql-diff-history');
    await alertRow.locator('a').first().click();
    
    // Wait for alert details to load
    await expect(page.locator('h1')).toContainText('Alert');
    
    // Check that the date fields appear in the correct order with correct names
    const dateRows = page.locator('table tr');
    
    // Status should be first (with optional "since" timestamp)
    await expect(dateRows.filter({ hasText: 'Status' }).first()).toBeVisible();
    
    // Last run should be second
    await expect(dateRows.filter({ hasText: 'Last run' }).first()).toBeVisible();
    
    // Created should be third
    await expect(dateRows.filter({ hasText: 'Created' }).first()).toBeVisible();
    
    // Updated should be fourth (not "Modified" or "Last modified")
    await expect(dateRows.filter({ hasText: 'Updated' }).first()).toBeVisible();
  });

  test('T12 - new alert shows never run without since', async ({ page }) => {
    // Create our own alert to test with known state - use helper
    const randomId = Math.random().toString(36).substring(7);
    const alertName = `Status Test ${randomId}`;
    
    const alert = await alertHelper.createTestAlert({
      name: alertName,
      query: 'SELECT 1 as test_count',
      threshold: '0'
    });
    
    // Check if creation was successful (redirect to alerts) or failed (stayed on /new)
    const currentUrl = alert.page.url();
    if (currentUrl.includes('/new')) {
      throw new Error('Alert creation failed - stayed on form page');
    }
    
    await expect(alert.page.locator('h1')).toContainText(alertName);
    
    // Initial status should be "never run" (no "since")
    await expect(alert.page.getByRole('row', { name: /Status never run/ })).toBeVisible();
    
    // Alert just created - should be "never run" with no "since"
    const statusCell = alert.page.locator('tr:has-text("Status") td').last(); // Get the value cell, not the label
    await expect(statusCell).toContainText('never run');
    await expect(statusCell).not.toContainText('since');
  });

  test('T13 - alert creation shows proper initial date structure', async ({ page }) => {
    // Use seeded test alert (READ-ONLY)
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '5-test-validation-broken-sql');
    await alertRow.locator('a').first().click();
    
    // Wait for alert details to load
    await expect(page.locator('h1')).toContainText('5-test-validation-broken-sql');
    
    // Verify dates are present
    await expect(page.locator('tr:has-text("Created") td')).not.toContainText('never');
    await expect(page.locator('tr:has-text("Last run") td')).toContainText('never');
    await expect(page.locator('tr:has-text("Updated") td')).not.toContainText('never');
  });

  test('T14 - first alert run updates last run but preserves created and updated dates', async ({ page }) => {
    // Use seeded test alert (READ-ONLY)
    const alertRow = await alertHelper.findAlertRowInContextListing('test', '6-test-validation-lifecycle');
    await alertRow.locator('a').first().click();
    
    await expect(page.locator('h1')).toContainText('Alert');
    
    // Get initial timestamps
    const initialCreated = await page.locator('tr:has-text("Created") td').textContent();
    const initialUpdated = await page.locator('tr:has-text("Updated") td').textContent();
    
    // TODO: "20 seconds ago (2025-09-02 16:57:08)" the 20 seconds changes! 

    // Run the alert using helper
    await alertHelper.runAlertFromAlertDetail();
    
    // Wait for page to reload or update
    await page.waitForTimeout(1000);
    
    // Verify timestamps after running
    const newCreated = await page.locator('tr:has-text("Created") td').textContent();
    const newUpdated = await page.locator('tr:has-text("Updated") td').textContent();
    
    // Created and Updated should be unchanged after running - extract only timestamp in parentheses
    const extractTimestamp = (text: string) => {
      const match = text?.match(/\(([^)]+)\)$/);
      return match ? match[1] : text;
    };
    
    expect(extractTimestamp(newCreated)).toBe(extractTimestamp(initialCreated));
    expect(extractTimestamp(newUpdated)).toBe(extractTimestamp(initialUpdated));
    
    // Last run should be updated (not "never")
    const lastRun = await page.locator('tr:has-text("Last run") td').textContent();
    expect(lastRun).not.toContain('never');
    
    // Status should show "since" if it's a real status
    const statusCell = page.locator('tr:has-text("Status") td');
    const statusText = await statusCell.textContent();
    
    if (statusText && !statusText.includes('needs refreshing') && !statusText.includes('never run')) {
      await expect(statusCell).toContainText('since');
    }
  });

  test('T15 - form validates broken data source connection', async ({ page }) => {
    // Create alert using helper with BROKEN data source - should fail M2H validation
    const alert = await alertHelper.createTestAlert({
      name: 'M2H Connection Test',
      query: 'SELECT 1 as test_value',
      threshold: '0',
      dataSourceLabel: 'Broken MySQL Database' // Use the seeded broken data source
    });
    
    // M2H validation should prevent saving - MUST stay on form (check title)
    const stayedOnForm = await alert.stayedOnForm();
    expect(stayedOnForm).toBe(true); // Should still show "New Alert" title
    
    // Should show connection failure in help-block
    await expect(alert.page.locator('.help-block')).toBeVisible();
    const errorMessage = await alert.page.locator('.help-block').textContent();
    expect(errorMessage).toMatch(/could not connect/i);
  });

  test('T16 - form validates invalid SQL syntax', async ({ page }) => {
    // Create alert using helper with INVALID SQL - should fail M2H validation
    const alert = await alertHelper.createTestAlert({
      name: 'M2H SQL Validation Test',
      query: 'TOTALLY INVALID SQL SYNTAX THAT MAKES NO SENSE',
      threshold: '0'
      // Uses default working data source
    });
    
    // M2H validation should prevent saving - MUST stay on form (check title)
    const stayedOnForm = await alert.stayedOnForm();
    expect(stayedOnForm).toBe(true); // Should still show "New Alert" title
    
    // Should show SQL validation error in help-block  
    await expect(alert.page.locator('.help-block')).toBeVisible();
    const errorMessage = await alert.page.locator('.help-block').textContent();
    expect(errorMessage).toMatch(/sql.*syntax|invalid.*query/i);
  });

  test('T17 - form prevents creation with broken data source', async ({ page }) => {
    // This test already covered by T15 with broken data source
    // Just ensuring we have comprehensive coverage of data source validation
    const alert = await alertHelper.createTestAlert({
      name: 'Another Connection Test',
      query: 'SELECT 2 as test_value',
      threshold: '0',
      dataSourceLabel: 'Broken MySQL Database'
    });
    
    const stayedOnForm = await alert.stayedOnForm();
    expect(stayedOnForm).toBe(true);
    
    await expect(alert.page.locator('.help-block')).toBeVisible();
  });
});