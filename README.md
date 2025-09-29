# Elixir Alerts

A Phoenix application for monitoring database data and generating alerts. Connect to multiple databases (MySQL, PostgreSQL), create custom SQL alerts, and get notified when thresholds are exceeded. Features encrypted credential storage and SSL/HTTPS support.

## Quick Start

```bash
# Development (with sample databases and test data)
./bin/init.sh dev
# → http://localhost:4000

# Testing (with sample databases for E2E tests)
./bin/init.sh test
# → http://localhost:4002

# Production (clean start, no sample data)
./bin/init.sh prod
# → http://localhost:4004
```

## Screenshots

![Data Sources](screenshots/data-sources.png) ![Alerts Dashboard](screenshots/alerts-listing.png)
![Alert Timeline](screenshots/alert-diff-story.png) ![Alert Details](screenshots/alert-detail.png)

## Environment Details

### Development (`dev`)
- **Includes:** Sample databases (MySQL, PostgreSQL) for testing connections
- **Seeded:** Sample alerts and data sources for immediate experimentation
- **SSL:** Optional (`./bin/helpers/crypto/install_self_signed_certificate.sh dev`)
- **Access:** http://localhost:4000 (HTTP) or https://localhost:4001 (HTTPS)

### Testing (`test`)
- **Includes:** Sample databases for E2E test scenarios
- **Seeded:** Test data for automated testing workflows
- **Tests:** `./bin/test/backend.sh` and `./bin/test/e2e.sh`
- **Access:** http://localhost:4002

### Production (`prod`)
- **Clean:** No sample databases or seeded data
- **Data:** Add through web interface only
- **SSL:** Required for security (self-signed or CA-signed certificates)
- **Access:** https://localhost:4005 (HTTPS) with HTTP redirect

## SSL Configuration (Production)

**Self-signed (testing):**
```bash
./bin/helpers/crypto/install_self_signed_certificate.sh prod
```

**CA-signed (production):**
```bash
sudo certbot certonly --standalone -d yourdomain.com
./bin/helpers/crypto/install_custom_certificate.sh prod \
  /etc/letsencrypt/live/yourdomain.com/fullchain.pem \
  /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

## Security Management

**Secret Rotation:**
```bash
# Rotate all secrets and encrypted data
./bin/rotate_secrets.sh <env>

# Master password protection (optional)
./bin/set_master_password.sh <env>
```

**Stop Environment:**
```bash
docker stack rm alerts-<env>
```

## Independent Scripts

All scripts work with `dev`/`test`/`prod` environments. **Note:** `./bin/test/*` scripts should only be used in dev/test environments.

**Core Operations:**
- `./bin/init.sh <env>` - Full environment setup (secrets, build, start)
- `./bin/startup.sh <env>` - Start environment (use `--reboot` to restart)
- `./bin/build.sh <env>` - Build Docker images
- `./bin/stop.sh <env>` - Stop environment and cleanup
- `./bin/rotate_secrets.sh <env>` - Rotate all secrets and encrypted data

**Database & Testing (dev/test environments):**
- `./bin/helpers/db/seed.sh <env>` - Seed database with sample data
- `./bin/test/backend.sh` - Run Elixir/Phoenix tests (works with dev/test)
- `./bin/test/e2e.sh` - Run Playwright E2E tests (works with dev/test)

**Security & Certificates:**
- `./bin/helpers/crypto/secrets.sh <env>` - Generate application secrets
- `./bin/helpers/crypto/install_self_signed_certificate.sh <env>` - Install SSL cert
- `./bin/set_master_password.sh <env>` - Setup app password

**Database Initialization:**
Database creation and migration happens automatically in `alerts/bin/boot.sh` during container startup:
- `mix ecto.create --quiet || true` (creates DB if it doesn't exist)
- `mix ecto.migrate` (runs pending migrations)

## Credits

**Project:** jsph | **Engineering Support:** Claude (Anthropic AI)

---

## 📋 Future Enhancements

**Priority Roadmap:**

1. **📈 History Graphic Representation**
   - Interactive charts and graphs for alert trends over time
   - Visual dashboards for alert performance metrics
   - Historical data visualization and analysis tools

2. **🔐 HashiCorp Vault Integration**
   - Replace Docker secrets with Vault for enhanced security
   - Dynamic database credential rotation
   - Better protection against container compromise scenarios

3. **👥 Multi-Level User Permission System**
   - Role-based access control (RBAC) for different user types
   - Granular permissions for alerts, data sources, and system configuration
   - User management and authentication improvements

4. **🚨 Alert System Integrations**
   - PagerDuty, Slack, Teams, and email notifications
   - Webhook support for custom integrations
   - Escalation policies and notification routing

