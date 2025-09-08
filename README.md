# Elixir Alerts

A Phoenix application for monitoring database data and generating alerts with encrypted data source credentials. Connect to multiple databases (MySQL, PostgreSQL), create alerts with custom SQL queries, and get notified when thresholds are exceeded. Features encrypted credential storage, master password protection, and full SSL/HTTPS support.

## Screenshots

### Data Source Management
Securely manage multiple database connections with encrypted credentials:

![Data Sources](screenshots/data-sources.png)

### Alert Dashboard
Monitor all your alerts with real-time status updates and context filtering:

![Alerts Listing](screenshots/alerts-listing.png)

### Alert Timeline & History
Track alert changes and results over time with detailed diff visualization:

![Alert Timeline](screenshots/alert-diff-story.png)

### Alert Details & Monitoring
View individual alert status, execution results, and downloadable CSV data:

![Alert Detail](screenshots/alert-detail.png)

## Development Environment

Local development with hot reload and debugging capabilities.

### Setup & Run

**Setup & Start:**
```bash
# Full setup from scratch (recommended)
./bin/init.sh dev

# Manual step-by-step (if you need granular control)
./bin/helpers/crypto/secrets.sh dev                    # Create application secrets
./bin/helpers/docker/create_docker_compose.sh dev      # Generate compose file
./bin/build.sh dev                                      # Build Docker image (required first time)
./bin/startup.sh dev                                    # Start environment
./bin/helpers/db/seed.sh dev                           # Seed database with sample data
```

*Note: `./bin/init.sh` automatically handles sample databases, secrets, building, and starting*
**→ Access at http://localhost:4000**

### With SSL (Optional)
```bash
# Generate and install self-signed certificate (stored in container)
./bin/helpers/crypto/install_self_signed_certificate.sh dev

# Restart to enable SSL (startup script auto-detects certificates)
./bin/startup.sh dev
```
**→ Access at https://localhost:4001 (HTTPS) or http://localhost:4000 (HTTP) - both work independently**

*Note: Self-signed certificates will show browser security warnings - click through to proceed.*

### Secret Rotation (Existing Environment)

Rotate encryption keys and update encrypted data automatically:

```bash
# Rotate all secrets (encryption key + secret key base + database data)
./bin/rotate_secrets.sh dev

# Or rotate master password only
./bin/helpers/crypto/setup_master_password.sh dev
./bin/helpers/docker/create_docker_compose.sh dev
./bin/startup.sh dev --reboot
```

*Note: `rotate_secrets.sh` automatically handles: extracting old key, creating new secrets, rotating encrypted database data, updating compose file, and restarting.*

### Stop Environment
```bash
# Stop dev environment
docker stack rm alerts-dev

# Stop test environment
docker stack rm alerts-test

# Stop all sample databases
docker-compose -f docker-compose.sample-dbs.yaml down
```

---

## Test Environment

Automated testing with clean database state and E2E browser tests.

### Setup & Run

**Setup & Start:**
```bash
# Full setup from scratch (recommended)
./bin/init.sh test

# Manual step-by-step (if you need granular control)
./bin/helpers/crypto/secrets.sh test                   # Create application secrets  
./bin/helpers/docker/create_docker_compose.sh test     # Generate compose file
./bin/build.sh test                                     # Build Docker image (required first time)
./bin/startup.sh test                                   # Start environment
./bin/helpers/db/seed.sh test                          # Seed database with sample data
```

*Note: `./bin/init.sh` automatically handles sample databases, secrets, building, and starting*
**→ Access at http://localhost:4002**

### Run Tests

**Prerequisites:** Test environment must be running first
```bash
# Start test environment (if not already running) 
./bin/init.sh test
```

**Then run tests:**
```bash
# Backend tests (Elixir/Phoenix) - resets DB and runs tests
./bin/test/backend.sh

# E2E tests (Playwright) - seed DB with sample data and run tests
./bin/helpers/db/seed.sh test && ./bin/test/e2e.sh

# E2E with specific pattern and workers
./bin/helpers/db/seed.sh test && ./bin/test/e2e.sh -w 3 "T4"
```

---

## Production Environment

Production-ready deployment with security hardening and SSL/HTTPS.

### Setup & Run
```bash
# Full setup from scratch (recommended)
./bin/init.sh prod

# Manual step-by-step (if you need granular control)
./bin/helpers/crypto/secrets.sh prod                   # Create application secrets
./bin/helpers/docker/create_docker_compose.sh prod     # Generate compose file  
./bin/build.sh prod                                     # Build Docker image (required first time)
./bin/startup.sh prod                                   # Start environment
# Note: No seeding in prod - add data through web interface
```

*Note: `./bin/init.sh` handles secrets, building, and starting (no sample databases in prod)*
**→ Access at http://localhost:4004**

### SSL Configuration (Required)

**Option 1: Self-signed certificate (testing)**
```bash
# Generate and install self-signed certificate (stored in container)
./bin/helpers/crypto/install_self_signed_certificate.sh prod

# Optional: Generate with custom domain
SSL_DOMAIN="yourdomain.com" ./bin/helpers/crypto/install_self_signed_certificate.sh prod
```

**Option 2: CA-signed certificate (production)**
```bash
# Get Let's Encrypt certificate (on host)
sudo certbot certonly --standalone -d yourdomain.com

# Install custom certificate using helper script
./bin/helpers/crypto/install_custom_certificate.sh prod \
  /etc/letsencrypt/live/yourdomain.com/fullchain.pem \
  /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

**Enable SSL and restart:**
```bash
# Start production server (auto-detects SSL certificates)
./bin/startup.sh prod
```
**→ Access at https://localhost:4005 (HTTPS) or http://localhost:4004 (HTTP redirects to HTTPS)**

### Security Management
```bash
# Rotate all secrets (encryption key + secret key base + database data)
./bin/rotate_secrets.sh prod

# Or full re-initialization (generates new secrets but doesn't rotate existing data)
./bin/init.sh prod
```

### Stop Environment
```bash
# Stop production environment
docker stack rm alerts-prod
```

### Master Password Protection (Optional)

Add application-level password protection requiring login to access the web interface.

```bash
# Generate and install master password (auto-regenerates compose and reboots)
./bin/helpers/crypto/setup_master_password.sh dev
```

**Requirements:**
- Password must be at least 8 characters
- Interactive confirmation required

**Configuration:**
```bash
# Set session timeout (default: 10 minutes)  
SESSION_TIMEOUT_MINUTES=30 ./bin/startup.sh dev
```

**User Experience:**
- 🔐 Login screen appears when master password is configured
- 🚪 Logout button in top-right corner when authenticated
- ⏱️ Automatic session timeout with configurable duration
- 🔄 Seamless redirect to login when session expires

**Security Features:**
- SHA-256 password hashing stored in Docker Swarm secrets
- Session-based authentication with CSRF protection
- Configurable session timeout (environment variable)
- Login screen protection for all routes
- Secure logout clears all session data
- Timestamped secret rotation for password updates

---

## 👥 Credits

**Project by:** jsph  
**Engineering Support:** Claude (Anthropic AI Assistant)

Built with Elixir, Phoenix, Docker, and a focus on secure database monitoring patterns.

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

