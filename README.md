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

**Prerequisites:** Start external test databases (shared between dev/test environments)
```bash
./bin/helpers/db/start_external_testdbs.sh
```

**Then start dev environment:**
```bash
# Full sequence (initialize, build, start, seed with test data)
./bin/helpers/crypto/init_secrets.sh dev && ./bin/build.sh dev && ./bin/startup.sh dev && sleep 20 && ./bin/helpers/db/reset.sh dev --seed

# Or step by step:
./bin/helpers/crypto/init_secrets.sh dev  # Create Docker Swarm secrets
./bin/build.sh dev                        # Build Docker image
./bin/startup.sh dev                      # Start environment
./bin/helpers/db/reset.sh dev --seed      # Reset DB and add sample data
```
**→ Access at http://localhost:4000**

### With SSL (Optional)
```bash
# Generate self-signed certificate (stored in container)
./bin/helpers/crypto/generate_self_signed_cert.sh dev

# Restart to enable SSL (startup script auto-detects certificates)
./bin/startup.sh dev
```
**→ Access at https://localhost:4001 (HTTPS) or http://localhost:4000 (HTTP) - both work independently**

*Note: Self-signed certificates will show browser security warnings - click through to proceed.*

---

## Test Environment

Automated testing with clean database state and E2E browser tests.

### Setup & Run

**Prerequisites:** Start external test databases (if not already running from dev setup)
```bash
./bin/helpers/db/start_external_testdbs.sh
```

**Then start test environment:**
```bash
# Full sequence (initialize, build, start, seed with test data)
./bin/helpers/crypto/init_secrets.sh test && ./bin/build.sh test && ./bin/startup.sh test && sleep 20 && ./bin/helpers/db/reset.sh test --seed

# Or step by step:
./bin/helpers/crypto/init_secrets.sh test  # Create Docker Swarm secrets
./bin/build.sh test                        # Build Docker image  
./bin/startup.sh test                      # Start environment
./bin/helpers/db/reset.sh test --seed      # Reset DB and add sample data
```
**→ Access at http://localhost:4002**

### Run Tests

**Prerequisites:** Test environment must be running first
```bash
# Start test environment (if not already running)
./bin/helpers/crypto/init_secrets.sh test && ./bin/build.sh test && ./bin/startup.sh test
```

**Then run tests:**
```bash
# Backend tests (Elixir/Phoenix) - resets DB and runs tests
./bin/test/run_backend_tests.sh

# E2E tests (Playwright) - resets DB with sample data and runs tests
./bin/test/run_e2e_tests.sh

# E2E with specific pattern and workers
./bin/test/run_e2e_tests.sh -w 3 "T4"
```

---

## Production Environment

Production-ready deployment with security hardening and SSL/HTTPS.

### Setup & Run
```bash
# Full sequence (initialize, build, start - no seeding in prod)
./bin/helpers/crypto/init_secrets.sh prod && ./bin/build.sh prod && ./bin/startup.sh prod

# Or step by step:
./bin/helpers/crypto/init_secrets.sh prod  # Create Docker Swarm secrets
./bin/build.sh prod                        # Build Docker image
./bin/startup.sh prod                      # Start environment
# Note: No seeding in prod - add data through web interface
```
**→ Access at http://localhost:4004**

### SSL Configuration (Required)

**Option 1: Self-signed certificate (testing)**
```bash
# Generate certificate (stored in container)
./bin/helpers/crypto/generate_self_signed_cert.sh prod

# Optional: Generate with custom domain
SSL_DOMAIN="yourdomain.com" ./bin/helpers/crypto/generate_self_signed_cert.sh prod
```

**Option 2: CA-signed certificate (production)**
```bash
# Get Let's Encrypt certificate (on host)
sudo certbot certonly --standalone -d yourdomain.com

# Copy certificates to running container (get container ID first)
CONTAINER_ID=$(docker ps -q -f name=alerts-prod_web-prod)
docker cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem $CONTAINER_ID:/app/priv/ssl/prod/cert.pem
docker cp /etc/letsencrypt/live/yourdomain.com/privkey.pem $CONTAINER_ID:/app/priv/ssl/prod/key.pem
```

**Enable SSL and restart:**
```bash
# Start production server (auto-detects SSL certificates)
./bin/startup.sh prod
```
**→ Access at https://localhost:4005 (HTTPS) or http://localhost:4004 (HTTP redirects to HTTPS)**

### Security Management
```bash
# Secrets are managed through Docker Swarm
# To rotate secrets, run init_secrets.sh again to generate new ones
./bin/helpers/crypto/init_secrets.sh prod
```

### Master Password Protection (Optional)

Add application-level password protection requiring login to access the web interface.

**Setup Master Password:**
```bash
# Interactive setup (secure password input)
./bin/helpers/crypto/setup_master_password.sh dev
./bin/helpers/crypto/setup_master_password.sh prod

# Non-interactive setup
./bin/helpers/crypto/setup_master_password.sh dev "your_secure_password"
```

**Requirements:**
- Environment must be running (application started)
- Password must be at least 8 characters
- Confirmation required for interactive setup

**Configuration:**
```bash
# Set session timeout (default: 10 minutes)
SESSION_TIMEOUT_MINUTES=30 ./bin/startup.sh dev

# Start with master password enabled
./bin/startup.sh dev  # Automatically detects master password
```

**User Experience:**
- 🔐 Login screen appears when master password is configured
- 🚪 Logout button in top-right corner when authenticated
- ⏱️ Automatic session timeout with configurable duration
- 🔄 Seamless redirect to login when session expires

**Security Features:**
- SHA-256 password hashing before encryption
- AES-256-GCM encryption using existing encryption keys
- Session-based authentication with CSRF protection
- Configurable session timeout (environment variable)
- Login screen protection for all routes
- No environment variable bypasses
- Secure logout clears all session data

---

## 👥 Credits

**Project by:** jsph  
**Engineering Support:** Claude (Anthropic AI Assistant)

Built with Elixir, Phoenix, Docker, and a focus on secure database monitoring patterns.

