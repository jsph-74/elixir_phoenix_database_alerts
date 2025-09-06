import { Page, expect } from '@playwright/test';

export interface AlertCreateOptions {
  name?: string;
  context?: string;
  description?: string;
  query?: string;
  threshold?: string;
  dataSourceLabel?: string;
}

export class AlertTestHelper {
  constructor(private page: Page) {}

  /**
   * Creates a test alert using ONLY seed data sources (READ-ONLY)
   * Never modifies seed data, only creates new test alerts
   */
  async createTestAlert(options: AlertCreateOptions = {}) {
    const randomId = Math.random().toString(36).substring(7);
    
    const alertData = {
      name: options.name || `Test Alert ${randomId}`,
      context: options.context || `test-context-${randomId}`,
      description: options.description || `Test description ${randomId}`,
      query: options.query || 'SELECT 1 as test_value',
      threshold: options.threshold || '2',
      dataSourceLabel: options.dataSourceLabel || 'E-commerce Analytics Database' // Use seeded data source READ-ONLY
    };

    await this.page.goto('/alerts/new');
    
    await this.page.fill('#alert-form_context', alertData.context);
    await this.page.fill('#alert-form_name', alertData.name);
    await this.page.fill('#alert-form_description', alertData.description);
    
    // Use seeded data source (always available)
    await this.page.selectOption('#alert-form_data_source_id', { label: alertData.dataSourceLabel });
    
    await this.page.fill('#alert-form_query', alertData.query);
    await this.page.fill('#alert-form_threshold', alertData.threshold);
    
    await this.page.click('#submit-btn');
    
    // Wait for response and check for server errors
    await this.page.waitForTimeout(1000);
    const bodyText = await this.page.textContent('body');
    if (bodyText?.includes('Internal Server Error') || bodyText?.includes('500')) {
      throw new Error('Server error (500) occurred during alert creation');
    }
    
    // Return page and alert data - tests can check title to see if stayed on form
    return {
      page: this.page,
      name: alertData.name,
      context: alertData.context,
      stayedOnForm: async () => {
        const title = await this.page.locator('h1').textContent();
        return title?.includes('New Alert') || false;
      }
    };
  }

  /**
   * Navigate to a test alert by context (never touches seed alerts)
   */
  async navigateToTestAlert(context: string, alertName: string) {
    await this.page.goto(`/alerts?context=${context}`);
    const alertRow = this.page.locator('tr').filter({ hasText: alertName });
    await alertRow.locator('a').first().click();
    await expect(this.page.locator('h1')).toContainText(alertName);
  }

  /**
   * Edit a test alert (never touches seed alerts)
   */
  async editTestAlert(context: string, alertName: string) {
    await this.page.goto(`/alerts?context=${context}`);
    const alertRow = this.page.locator('tr').filter({ hasText: alertName });
    await alertRow.locator('a[href*="/edit"]').click();
  }

  /**
   * Run a test alert and wait for completion
   */
  async runAlert() {
    await this.page.click('button[type="submit"][title="Run alert"]');
    await this.page.waitForTimeout(2000); // Allow time for execution
  }

  /**
   * Get alert status (never from seed alerts)
   */
  async getAlertStatus(): Promise<string> {
    const statusCell = this.page.locator('tr:has-text("Status") td').last();
    return await statusCell.textContent() || '';
  }

  /**
   * Navigate to context and find alert row in listing (READ-ONLY)
   */
  async findAlertRowInContextListing(contextName: string, alertName: string) {
    await this.page.goto(`/alerts?context=${contextName}`);
    await expect(this.page.locator('table')).toBeVisible();
    
    // Check if the alert row exists
    const row = this.page.locator('tr').filter({ hasText: alertName });
    const rowExists = await row.count();
    
    if (rowExists === 0) {
      throw new Error(`Alert "${alertName}" not found in context "${contextName}"! Database may not be properly seeded.`);
    }
    
    return row;
  }

  /**
   * Run alert from alert detail page
   */
  async runAlertFromAlertDetail() {
    const runButton = this.page.locator('button[title="Run alert"]').first();
    await expect(runButton).toBeVisible();
    await runButton.click();
  }

  /**
   * Delete alert from alert detail page
   */
  async deleteAlertFromAlertDetail() {
     const deleteButton = this.page.locator('a.btn-icon-danger[title="Delete alert"]');
    await expect(deleteButton).toBeVisible();
    
    // Set up dialog handler before clicking
    this.page.on('dialog', async dialog => {
      await dialog.accept();
    });
    
    await deleteButton.click();
    
  }
  
}

export class HistoryTestHelper {
  constructor(private page: Page) {}

  async goToHistoryTab() {
    // Check if history tab is visible and enabled
    const historyTab = this.page.locator('a[href="#query-history"]');
    await expect(historyTab).toBeVisible();
    
    // Wait for the tab to be clickable and not covered
    await historyTab.waitFor({ state: 'attached' });
    await historyTab.waitFor({ state: 'visible' });
    
    
    // Try clicking with force if needed
    try {
      await historyTab.click({ timeout: 5000 });
    } catch (error) {
      console.log('Regular click failed, trying with force...');
      await historyTab.click({ force: true });
    }
    
    await this.page.waitForTimeout(1000);
  }

  async getHistoryEntryCount() {
    return await this.page.locator('.timeline-event').count();
  }

  async verifyDiffButton(entryIndex: number = 0) {
    const diffButton = this.page.locator('.timeline-event').nth(entryIndex).locator('button', { hasText: /show|hide|diff/i });
    await expect(diffButton).toBeVisible();
    return diffButton;
  }

  async verifyDiffContent(entryIndex: number, expectedField: string, oldValue: string, newValue: string) {
    const diffButton = await this.verifyDiffButton(entryIndex);
    await diffButton.click();
    
    const timelineEntry = this.page.locator('.timeline-event').nth(entryIndex);
    
    // Verify field name appears in diff - be more specific about field names
    const fieldDisplayName = expectedField.charAt(0).toUpperCase() + expectedField.slice(1); // Capitalize first letter
    await expect(timelineEntry).toContainText(fieldDisplayName);
    
    // Verify old and new values separately
    const oldContent = timelineEntry.locator('.diff-content.old');
    const newContent = timelineEntry.locator('.diff-content.new');
    
    await expect(oldContent).toContainText(oldValue);
    await expect(newContent).toContainText(newValue);
    
    // Verify only one field changed by counting diff content blocks
    // Each field change should have exactly 2 diff-content divs (old + new)
    const diffContentBlocks = timelineEntry.locator('.diff-content');
    const blockCount = await diffContentBlocks.count();
    expect(blockCount).toBe(2); // Should be exactly 2: one old, one new
    
    // Close diff to clean up
    await diffButton.click();
  }

  async verifyCurrentTag() {
    const currentTags = this.page.locator('.timeline-event .current, .timeline-event .label-success, .timeline-event .badge-success');
    expect(await currentTags.count()).toBe(1);
  }
}