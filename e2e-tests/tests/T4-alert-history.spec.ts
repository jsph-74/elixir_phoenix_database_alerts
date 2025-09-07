import { test, expect } from '@playwright/test';
import { navigateWithAuth, handleMasterPasswordLogin } from '../helpers/auth';
import { TestDatabaseHelper } from '../helpers/database';
import { AlertTestHelper, HistoryTestHelper } from '../helpers/alert-helper';

test.describe('Alert History E2E', () => {
  let dbHelper: TestDatabaseHelper;
  let alertHelper: AlertTestHelper;
  let historyHelper: HistoryTestHelper;

  test.beforeEach(async ({ page }) => {
    dbHelper = new TestDatabaseHelper();
    alertHelper = new AlertTestHelper(page);
    historyHelper = new HistoryTestHelper(page);
  });

  test.afterEach(async () => {
    if (dbHelper) {
      await dbHelper.cleanupTestOrders();
      await dbHelper.fixDataSourceConnection();
      await dbHelper.disconnect();
    }
  });

  test('T41 - alert edition history tracks individual field changes with correct diffs', async ({ page }) => {
    const randomId = Math.random().toString(36).substring(7);
    const initialName = `History Test ${randomId}`;
    const contextName = 'T41';
    await alertHelper.createTestAlert({
      name: initialName,
      context: contextName,
      query: "SELECT 1 as test", 
      threshold: '5',
      description: 'Initial description',
      dataSourceLabel: 'Investment Portfolio Database'
    });
    
    await alertHelper.editTestAlert('T41', initialName);
    await page.fill('#alert-edit-form_schedule', '0 * * * *');
    await page.click('#submit-btn');
    
    // Wait for navigation and handle potential auth redirects
    await page.waitForLoadState('networkidle');
    await handleMasterPasswordLogin(page);
    
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    await expect(page.locator('h1')).toContainText(initialName);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(2);
    
    const updates = [
      { field: 'name', selector: '#alert-edit-form_name', oldValue: initialName, newValue: `Updated Name ${randomId}` },
      { field: 'description', selector: '#alert-edit-form_description', oldValue: 'Initial description', newValue: 'Updated description' },
      { field: 'query', selector: '#alert-edit-form_query', oldValue: 'SELECT 1 as test', newValue: 'SELECT 2 as test' },
      { field: 'threshold', selector: '#alert-edit-form_threshold', oldValue: '5', newValue: '10' },
      { field: 'schedule', selector: '#alert-edit-form_schedule', oldValue: '0 * * * *', newValue: '0 0 * * *' }
    ];
    
    let currentAlertName = initialName;
    
    for (let i = 0; i < updates.length; i++) {
      const update = updates[i];
      
      await alertHelper.editTestAlert(contextName, currentAlertName);
      
      await page.fill(update.selector, update.newValue);
      await page.click('#submit-btn');
      
      // Wait for navigation and handle potential auth redirects
      await page.waitForLoadState('networkidle');
      await handleMasterPasswordLogin(page);
      
      const currentUrl = page.url();
      expect(currentUrl).not.toContain('/edit');
      expect(currentUrl).toMatch(/\/alerts\/[a-f0-9-]+$/);
      
      await historyHelper.goToHistoryTab();
      expect(await historyHelper.getHistoryEntryCount()).toBe(i + 3);
      await historyHelper.verifyDiffContent(0, update.field, update.oldValue, update.newValue);
      await historyHelper.verifyCurrentTag();
      
      if (update.field === 'name') {
        currentAlertName = update.newValue;
      }
    }

    await alertHelper.findAlertRowInContextListing(contextName, currentAlertName);
    // TEMP: Disabled delete - alertHelper.deleteAlertFromAlertDetail()
  });

  test('T42 - alert status changes create history entries with result diffs and correct dates', async ({ page }) => {
    const randomId = Math.random().toString(36).substring(7);
    const contextName = 'T42';
    const alertName = `Status History ${randomId}`;
    
    await alertHelper.createTestAlert({
      name: alertName,
      context: contextName,
      query: "SELECT COUNT(*) as count FROM orders WHERE status = 'cancelled'",
      threshold: '5'
    });
    
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    
    const statusCell = page.locator('tr:has-text("Status") td').last();
    await expect(statusCell).toContainText('never run');
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(1);
    
    await alertHelper.runAlertAndWaitForCompletion(2);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(2);
    await historyHelper.verifyDiffButton(0);
    
    await dbHelper.insertFailedOrders(10);
    await alertHelper.runAlertAndWaitForCompletion(3);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(3);
    
    const diffButton = await historyHelper.verifyDiffButton(0);
    await diffButton.click();
    const timelineEntry = page.locator('.timeline-event').first();
    await expect(timelineEntry.locator('.diff-content')).toHaveCount(2);
    await diffButton.click();
    
    await dbHelper.breakDataSourceConnection();
    await alertHelper.runAlertAndWaitForCompletion(4);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(4);
    await alertHelper.waitForAlertStatus('broken');
    
    await dbHelper.fixDataSourceConnection();
    await dbHelper.updateAlertQuery(alertName, "SELECT INVALID_COLUMN FROM non_existent_table");
    await alertHelper.runAlertAndWaitForCompletion(5);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(5);
    await alertHelper.waitForAlertStatus('broken');
    
    await dbHelper.updateAlertQuery(alertName, "SELECT COUNT(*) as count FROM orders WHERE status = 'cancelled'");
    await alertHelper.runAlertAndWaitForCompletion(6);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(6);
    
    await alertHelper.editTestAlert(contextName, alertName);
    await page.fill('#alert-edit-form_description', 'Updated description to trigger needs refreshing');
    await page.click('#submit-btn');
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    
    await expect(statusCell).toContainText('needs refreshing');
    const statusText = await statusCell.textContent();
    expect(statusText).not.toContain('since');
    
    const refreshedAlertRow = await alertHelper.findAlertRowInContextListing(contextName, alertName);
    const listingStatusCell = refreshedAlertRow.locator('td').nth(5);
    await expect(listingStatusCell).toContainText('needs refreshing');
    const listingStatusText = await listingStatusCell.textContent();
    expect(listingStatusText).not.toContain('since');
    
    await refreshedAlertRow.locator('a').first().click();
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(7);
    
    const timelineEvents = page.locator('.timeline-event');
    const eventCount = await timelineEvents.count();
    
    for (let i = 0; i < eventCount; i++) {
      const eventText = await timelineEvents.nth(i).textContent();
      expect(eventText).toMatch(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/);
    }
    
    await historyHelper.verifyCurrentTag();

    const alertRow = await alertHelper.findAlertRowInContextListing(contextName, alertName);
    await alertRow.locator('a').first().click(); // Navigate to alert detail page
    // TEMP: Disabled delete - await alertHelper.deleteAlertFromAlertDetail()
  });

  test('T43 - combined status and alert changes create correct history with proper diffs', async ({ page }) => {
    const randomId = Math.random().toString(36).substring(7);
    const contextName = 'T43';
    const alertName = `Combined History ${randomId}`;
    
    await alertHelper.createTestAlert({
      name: alertName,
      context: contextName,
      query: "SELECT 1 as test_value",
      threshold: '5'
    });
    
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    
    const hasHistoryTab = await page.locator('a[href="#query-history"]').count() > 0;
    if (!hasHistoryTab) {
      await alertHelper.navigateToTestAlert(contextName, alertName);
      await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    }
    
    await expect(page.locator('h1')).toContainText(alertName);
    await expect(page.locator('button[title="Run alert"]')).toBeVisible();
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(1);
    
    const edits = [
      { field: 'threshold', selector: '#alert-edit-form_threshold', value: '3' },
      { field: 'description', selector: '#alert-edit-form_description', value: 'First description update' },
      { field: 'query', selector: '#alert-edit-form_query', value: "SELECT COUNT(*) as count FROM orders" }
    ];
    
    for (let i = 0; i < edits.length; i++) {
      const edit = edits[i];
      await alertHelper.editTestAlert(contextName, alertName);
      
      await page.fill(edit.selector, edit.value);
      await page.click('#submit-btn');
      await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
      
      await historyHelper.goToHistoryTab();
      expect(await historyHelper.getHistoryEntryCount()).toBe(i + 2);
      await historyHelper.verifyDiffButton(0);
    }
    
    await alertHelper.runAlertAndWaitForCompletion(5);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(5);
    
    await dbHelper.insertFailedOrders(10);
    await alertHelper.runAlertAndWaitForCompletion(6);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(6);
    
    const diffButton = await historyHelper.verifyDiffButton(0);
    await diffButton.click();
    const timelineEntry = page.locator('.timeline-event').first();
    await expect(timelineEntry.locator('.diff-content')).toHaveCount(2);
    await diffButton.click();
    
    await alertHelper.editTestAlert(contextName, alertName);
    await page.fill('#alert-edit-form_threshold', '20');
    await page.click('#submit-btn');
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    
    await alertHelper.runAlertAndWaitForCompletion(8);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(8);
    
    const underThresholdButton = await historyHelper.verifyDiffButton(0);
    await underThresholdButton.click();
    const underThresholdEntry = page.locator('.timeline-event').first();
    const diffContentCount = await underThresholdEntry.locator('.diff-content').count();
    expect(diffContentCount).toBe(2);
    await underThresholdButton.click();
    
    await navigateWithAuth(page, `/alerts?context=${contextName}`);
    const finalAlertRow = page.locator('tr').filter({ hasText: alertName });
    await finalAlertRow.locator('a[href*="/edit"]').click();
    await page.fill('#alert-edit-form_description', 'Alternating pattern edit 1');
    await page.click('#submit-btn');
    await page.waitForURL(/\/alerts\/.*/, { timeout: 10000 });
    
    await alertHelper.runAlertAndWaitForCompletion(10);
    
    await historyHelper.goToHistoryTab();
    expect(await historyHelper.getHistoryEntryCount()).toBe(10);
    
    await historyHelper.verifyCurrentTag();
    
    const timelineEvents = page.locator('.timeline-event');
    const eventCount = await timelineEvents.count();
    for (let i = 0; i < eventCount; i++) {
      const eventText = await timelineEvents.nth(i).textContent();
      expect(eventText).toMatch(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/);
    }

    await alertHelper.findAlertRowInContextListing(contextName, alertName);
    // TEMP: Disabled delete - alertHelper.deleteAlertFromAlertDetail()
  });
});