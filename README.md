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

**Prerequisites:** Start external test databases (shared between dev/test environment, needed for seeding)
```bash
./bin/helpers/db/start_sample_dbs.sh
```

**Then start dev environment:**
```bash
# Full sequence (initialize, build, start, seed with test data)
./bin/init.sh dev && ./bin/startup.sh dev && sleep 20 && ./bin/helpers/db/seed.sh dev

# Or step by step:
./bin/init.sh dev                    # Initialize: create secrets, generate compose, build image
./bin/startup.sh dev                 # Start environment
./bin/helpers/db/seed.sh dev         # Seed database with sample data
```
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

**Prerequisites:** Start external test databases (if not already running from dev setup)
```bash
./bin/helpers/db/start_sample_dbs.sh
```

**Then start test environment:**
```bash
# Full sequence (initialize, build, start, seed with test data)
./bin/init.sh test && ./bin/startup.sh test && sleep 20 && ./bin/helpers/db/seed.sh test

# Or step by step:
./bin/init.sh test                   # Initialize: create secrets, generate compose, build image
./bin/startup.sh test                # Start environment
./bin/helpers/db/seed.sh test        # Seed database with sample data
```
**→ Access at http://localhost:4002**

### Run Tests

**Prerequisites:** Test environment must be running first
```bash
# Start test environment (if not already running)
./bin/init.sh test && ./bin/startup.sh test
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
# Full sequence (initialize, build, start - no seeding in prod)
./bin/init.sh prod && ./bin/startup.sh prod

# Or step by step:
./bin/init.sh prod        # Initialize: create secrets, generate compose, build image
./bin/startup.sh prod     # Start environment
# Note: No seeding in prod - add data through web interface
```
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
# Secrets are managed through Docker Swarm
# To rotate secrets, run init again to generate new ones
./bin/init.sh prod
```

### Stop Environment
```bash
# Stop production environment
docker stack rm alerts-prod
```

### Master Password Protection (Optional)

Add application-level password protection requiring login to access the web interface.

**Setup Master Password:**
```bash
# 1. Create master password (interactive secure input)
./bin/helpers/crypto/setup_master_password.sh dev

# 2. Update docker-compose with new master password secret
./bin/helpers/docker/create_docker_compose.sh dev

# 3. Restart environment to use master password
./bin/startup.sh dev --reboot
```

**For production:**
```bash
./bin/helpers/crypto/setup_master_password.sh prod
./bin/helpers/docker/create_docker_compose.sh prod  
./bin/startup.sh prod --reboot
```

**Requirements:**
- Docker Swarm initialized (done automatically by init.sh)
- Password must be at least 8 characters
- Interactive confirmation required

**Remove Master Password:**
```bash
# Remove all master password secrets
docker secret rm $(docker secret ls --format "{{.Name}}" | grep "^master_password_")

# Update compose to use placeholder  
./bin/helpers/docker/create_docker_compose.sh dev

# Restart to disable authentication
./bin/startup.sh dev --reboot
```

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

