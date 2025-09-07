import { test, expect } from '@playwright/test';
import { navigateWithAuth } from '../helpers/auth';

test.describe('Basic Smoke Tests', () => {
  test('T01 - should load data sources page', async ({ page }) => {
    await navigateWithAuth(page, '/data_sources');
    await expect(page.locator('h1')).toContainText('Data sources');
    await expect(page.locator('text=Add Data Source')).toBeVisible();
  });

  test('T02 - should load new data source form', async ({ page }) => {
    await navigateWithAuth(page, '/data_sources/new');
    await expect(page.locator('h1')).toContainText('New Data Source');
    await expect(page.locator('#data-source-form_name')).toBeVisible();
    await expect(page.locator('#data-source-form_driver')).toBeVisible();
  });

  test('T03 - should load alerts page', async ({ page }) => {
    await navigateWithAuth(page, '/alerts');
    await expect(page.locator('h1')).toContainText('Alerts');
  });
});