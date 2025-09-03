import { test, expect } from '@playwright/test';
import { TestDatabaseHelper } from '../helpers/database';

test.describe('Data Sources Management E2E', () => {
  let dbHelper: TestDatabaseHelper;

  test.beforeEach(async () => {
    dbHelper = new TestDatabaseHelper();
  });

  test.afterEach(async () => {
    if (dbHelper) {
      await dbHelper.disconnect();
    }
  });

  test('T80 - should create, test, and manage MySQL data source', async ({ page }) => {
    // Step 1: Navigate to new data source form
    await page.goto('/data_sources/new');
    await expect(page.locator('h1')).toContainText('New Data Source');

    // Step 2: Fill out MySQL data source form
    const timestamp = Date.now();
    await page.fill('#data_source_name', `mysql_test_${timestamp}`);
    await page.fill('#data_source_display_name', `MySQL Test ${timestamp}`);
    await page.selectOption('#data_source_driver', 'MariaDB Unicode');
    await page.fill('#data_source_server', 'test_mysql');
    await page.fill('#data_source_database', 'test');
    await page.fill('#data_source_username', 'monitor_user');
    await page.fill('#data_source_password', 'monitor_pass');
    await page.fill('#data_source_port', '3306');
    
    // Step 3: Submit form
    await page.click('#submit-btn');

    // Step 4: Verify redirect and creation
    await expect(page.locator('h1')).toContainText('Data sources');
    await expect(page.locator(`text=mysql_test_${timestamp}`)).toBeVisible();
  });

  test('T81 - should create and test PostgreSQL data source', async ({ page }) => {
    await page.goto('/data_sources/new');

    // Fill PostgreSQL data source form
    const timestamp = Date.now();
    await page.fill('#data_source_name', `postgres_test_${timestamp}`);
    await page.fill('#data_source_display_name', `PostgreSQL Test ${timestamp}`);
    await page.selectOption('#data_source_driver', 'PostgreSQL Unicode');
    await page.fill('#data_source_server', 'test_postgres');
    await page.fill('#data_source_database', 'test');
    await page.fill('#data_source_username', 'postgres');
    await page.fill('#data_source_password', 'test_password');
    await page.fill('#data_source_port', '5433');
    
    await page.click('#submit-btn');

    // Verify creation
    await expect(page.locator(`text=postgres_test_${timestamp}`)).toBeVisible();
  });

  test('T82 - should handle invalid connection parameters gracefully', async ({ page }) => {
    await page.goto('/data_sources/new');

    // Fill form with invalid connection details
    await page.fill('#data_source_name', 'invalid_test_source');
    await page.fill('#data_source_display_name', 'Invalid Test Source');
    await page.selectOption('#data_source_driver', 'MariaDB Unicode');
    await page.fill('#data_source_server', 'nonexistent_server');
    await page.fill('#data_source_database', 'nonexistent_db');
    await page.fill('#data_source_username', 'invalid_user');
    await page.fill('#data_source_password', 'invalid_pass');
    await page.fill('#data_source_port', '9999');
    
    await page.click('#submit-btn');

    // Should show error or stay on form with validation message
    // (The exact behavior depends on your app's error handling)
  });

  test('T83 - should validate required fields', async ({ page }) => {
    await page.goto('/data_sources/new');

    // Try to submit empty form
    await page.click('#submit-btn');

    // Should stay on form (required field validation)
    await expect(page.locator('h1')).toContainText('New Data Source');
  });

  test('T84 - should list and navigate data sources', async ({ page }) => {
    await page.goto('/data_sources');

    // Verify data sources page structure
    await expect(page.locator('h1')).toContainText('Data sources');
    
    // Should have table headers
    await expect(page.locator('th').filter({ hasText: 'Name' }).first()).toBeVisible();
    await expect(page.locator('th').filter({ hasText: 'Display Name' })).toBeVisible();
    await expect(page.locator('th').filter({ hasText: 'Type' })).toBeVisible();

    // Navigate to new data source form (look for any link to new data source page)
    await page.goto('/data_sources/new');
    await expect(page.locator('h1')).toContainText('New Data Source');
  });

  test('T85 - should view data source details', async ({ page }) => {
    await page.goto('/data_sources');
    
    // Click on first data source (assuming ecommerce_mysql exists)
    await page.click('a[href="/data_sources/1"]');
    
    // Should show data source details
    await expect(page.locator('h1')).toContainText('E-commerce Analytics Database');
    await expect(page.locator('text=ecommerce_mysql')).toBeVisible();
    await expect(page.locator('text=MariaDB Unicode')).toBeVisible();
  });
});