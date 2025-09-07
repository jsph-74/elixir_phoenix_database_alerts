import mysql from 'mysql2/promise';
import { Client } from 'pg';

export class TestDatabaseHelper {
  private mysqlConnection?: mysql.Connection;
  private pgClient?: Client;

  // For E2E tests we need write permissions, so use admin users
  async connectMySQL() {
    this.mysqlConnection = await mysql.createConnection({
      host: 'test-mysql',
      port: 3306,
      user: 'root',
      password: 'mysql',
      database: 'test'
    });
  }

  async connectPostgres() {
    this.pgClient = new Client({
      host: 'test-postgres',
      port: 5432,
      user: 'postgres',
      password: 'postgres',
      database: 'test'
    });
    await this.pgClient.connect();
  }

  // MySQL Data Manipulation
  async insertFailedOrders(count: number) {
    await this.connectMySQL();
    for (let i = 0; i < count; i++) {
      const orderNumber = `TEST-${Date.now()}-${i}`;
      await this.mysqlConnection!.execute(
        `INSERT INTO orders (order_number, customer_id, subtotal, total_amount, status, order_date) 
         VALUES (?, 1, 100.00, 100.00, 'cancelled', NOW())`,
        [orderNumber]
      );
    }
  }

  async updateOrdersToSuccess(limit: number) {
    await this.connectMySQL();
    await this.mysqlConnection!.execute(
      `UPDATE orders SET status = 'delivered' WHERE status = 'cancelled' LIMIT ?`,
      [limit]
    );
  }

  async getFailedOrderCount(): Promise<number> {
    await this.connectMySQL();
    const [rows] = await this.mysqlConnection!.execute(
      `SELECT COUNT(*) as count FROM orders WHERE status = 'cancelled'`
    ) as any;
    return rows[0].count;
  }

  async cleanupTestOrders() {
    await this.connectMySQL();
    // Remove test orders created during this session (they have TEST- prefix)
    await this.mysqlConnection!.execute(
      `DELETE FROM orders WHERE order_number LIKE 'TEST-%'`
    );
  }

  // PostgreSQL Data Manipulation  
  async insertActiveUsers(count: number) {
    await this.connectPostgres();
    for (let i = 0; i < count; i++) {
      await this.pgClient!.query(
        `INSERT INTO sessions (user_id, active, created_at) VALUES ($1, true, NOW())`,
        [Math.floor(Math.random() * 1000) + i]
      );
    }
  }

  async deactivateUsers(count: number) {
    await this.connectPostgres();
    await this.pgClient!.query(
      `UPDATE sessions SET active = false WHERE active = true LIMIT $1`,
      [count]
    );
  }

  async getActiveUserCount(): Promise<number> {
    await this.connectPostgres();
    const result = await this.pgClient!.query(
      `SELECT COUNT(DISTINCT user_id) as count FROM sessions WHERE active = true`
    );
    return parseInt(result.rows[0].count);
  }

  // Schema Manipulation for Testing
  async dropEmailColumn() {
    await this.connectMySQL();
    await this.mysqlConnection!.execute(`ALTER TABLE users DROP COLUMN email`);
  }

  async addEmailColumn() {
    await this.connectMySQL();
    await this.mysqlConnection!.execute(`ALTER TABLE users ADD COLUMN email VARCHAR(255)`);
  }

  // Alert Management (requires connection to alerts PostgreSQL database)
  async connectAlertsDB() {
    // Close any existing connection first
    if (this.pgClient) {
      await this.pgClient.end();
    }
    // Connect to the alerts PostgreSQL database to manipulate alert records directly
    this.pgClient = new Client({
      host: process.env.ALERTS_DB_HOST || 'db-test', // alerts database host
      port: 5432,
      user: 'postgres',
      password: 'postgres',
      database: process.env.ALERTS_DB_NAME || 'alerts_test'
    });
    await this.pgClient.connect();
  }

  async breakDataSourceConnection() {
    await this.connectAlertsDB();
    // Update data source with invalid connection details
    await this.pgClient!.query(
      `UPDATE data_sources SET server = 'invalid_host', port = 9999 WHERE display_name = 'E-commerce Analytics Database'`
    );
  }

  async fixDataSourceConnection() {
    await this.connectAlertsDB();
    // Restore valid connection details
    await this.pgClient!.query(
      `UPDATE data_sources SET server = 'test-mysql', port = 3306 WHERE display_name = 'E-commerce Analytics Database'`
    );
  }

  async updateAlertQuery(alertName: string, newQuery: string) {
    await this.connectAlertsDB();
    // Update the alert's query directly in the database
    await this.pgClient!.query(
      `UPDATE alert SET query = $1 WHERE name = $2`,
      [newQuery, alertName]
    );
  }

  // Clean up connections
  async disconnect() {
    if (this.mysqlConnection) {
      await this.mysqlConnection.end();
    }
    if (this.pgClient) {
      await this.pgClient.end();
    }
  }
}