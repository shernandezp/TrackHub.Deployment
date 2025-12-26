# TrackHub Deployment Guide

A comprehensive guide for deploying TrackHub on Linux servers using Docker.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Detailed Installation](#detailed-installation)
6. [Configuration Reference](#configuration-reference)
7. [Deployment Scenarios](#deployment-scenarios)
8. [Database Setup](#database-setup)
9. [Migrating to a New Server](#migrating-to-a-new-server-existing-database)
10. [SSL Certificates](#ssl-certificates)
11. [Updating Services](#updating-services)
12. [Monitoring & Maintenance](#monitoring--maintenance)
13. [Troubleshooting](#troubleshooting)

---

## Overview

TrackHub is a GPS tracking and monitoring platform consisting of:

| Component | Description | Technology |
|-----------|-------------|------------|
| **TrackHub** | Web frontend | React.js |
| **AuthorityServer** | Identity provider | .NET 10, OpenIddict |
| **TrackHubSecurity** | Security & user management | .NET 10, GraphQL |
| **TrackHub.Manager** | Asset management | .NET 10, GraphQL |
| **TrackHubRouter** | Device routing | .NET 10, GraphQL |
| **TrackHub.Geofencing** | Geofence management | .NET 10, GraphQL |
| **TrackHub.Reporting** | Reports generation | .NET 10, REST API |

---

## Architecture

### Full Stack Deployment (Single Server)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Linux Server                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Nginx (Reverse Proxy)                   │  │
│  │              Port 80 → 443 (SSL Termination)               │  │
│  └────────────────────────┬──────────────────────────────────┘  │
│                           │                                      │
│  ┌────────────────────────┼──────────────────────────────────┐  │
│  │     /              /Identity    /Security    /Manager      │  │
│  │   Frontend         Authority    Security     Manager       │  │
│  │   (React)          (:8080)      (:8080)      (:8080)       │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │     /Router        /Geofence    /Reporting                 │  │
│  │     Router         Geofencing   Reporting                  │  │
│  │     (:8080)        (:8080)      (:8080)                    │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │  (External DB)  │
                    └─────────────────┘
```

### Split Deployment (Separate Servers)

```
┌──────────────────────┐        ┌──────────────────────┐
│   Frontend Server    │        │   Backend Server     │
│  ┌────────────────┐  │        │  ┌────────────────┐  │
│  │     Nginx      │  │        │  │     Nginx      │  │
│  └───────┬────────┘  │        │  └───────┬────────┘  │
│          │           │        │          │           │
│  ┌───────▼────────┐  │   →    │  ┌───────▼────────┐  │
│  │  React App     │  │  API   │  │  All Backend   │  │
│  │  (Static)      │──┼───────→│  │  Services      │  │
│  └────────────────┘  │ Calls  │  └────────────────┘  │
└──────────────────────┘        └──────────────────────┘
```

---

## Prerequisites

### Server Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 20 GB | 50+ GB SSD |
| OS | Ubuntu 20.04+ / Debian 11+ | Ubuntu 22.04 LTS |

### Software Requirements

- **Docker** 20.10+
- **Docker Compose** v2.0+
- **Git** (for cloning repositories)
- **OpenSSL** (for certificate generation)

### External Requirements

- Registered domain name
- PostgreSQL database server (external)
- SSL certificate (Let's Encrypt recommended for production)

---

## Quick Start

### 1. Install Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and back in, then verify
docker --version
docker compose version
```

### 2. Clone Repositories

```bash
# Create project directory
mkdir -p /opt/trackhub
cd /opt/trackhub

# Clone all required repositories
git clone https://github.com/shernandezp/TrackHub.git
git clone https://github.com/shernandezp/TrackHub.AuthorityServer.git
git clone https://github.com/shernandezp/TrackHubSecurity.git
git clone https://github.com/shernandezp/TrackHub.Manager.git
git clone https://github.com/shernandezp/TrackHubRouter.git
git clone https://github.com/shernandezp/TrackHub.Geofencing.git
git clone https://github.com/shernandezp/TrackHub.Reporting.git

# Clone or copy the deployment folder
# (assuming deployment folder is in the repository)
```

### 3. Configure Environment

```bash
cd deployment

# Copy example configuration
cp .env.example .env

# Edit configuration (see Configuration Reference section)
nano .env
```

### 4. Set Up Certificates

```bash
# For development/testing - generate self-signed certificates
./scripts/generate-certs.sh your-domain.com

# For production - copy your Let's Encrypt or CA certificates
# cp /path/to/fullchain.pem certificates/
# cp /path/to/privkey.pem certificates/
# cp /path/to/certificate.pfx certificates/
```

### 5. Configure OAuth Clients

```bash
# Copy and edit clients.json
cp config/clients.json.example config/clients.json
nano config/clients.json

# Update the callback URI with your domain
```

### 6. Deploy

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy full stack
./scripts/deploy.sh full --build
```

### 7. Verify Deployment

```bash
# Check health
./scripts/health-check.sh your-domain.com

# View logs
./scripts/logs.sh
```

---

## Detailed Installation

### Step 1: Prepare the Linux Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    curl \
    git \
    openssl \
    htop \
    ufw

# Configure firewall
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

### Step 2: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Start Docker on boot
sudo systemctl enable docker

# Log out and back in
exit
# SSH back in

# Verify installation
docker --version
docker compose version
```

### Step 3: Set Up Project Structure

```bash
# Create directory structure
sudo mkdir -p /opt/trackhub
sudo chown $USER:$USER /opt/trackhub
cd /opt/trackhub

# Clone repositories (as shown in Quick Start)
```

### Step 4: Database Setup

Before deploying, ensure your PostgreSQL database is accessible:

```bash
# Test database connectivity
psql -h your-db-server.com -U postgres -d postgres -c "SELECT version();"
```

See the [Database Setup](#database-setup) section for detailed database initialization instructions.

### Step 5: Configure Environment Variables

Create and configure the `.env` file:

```bash
cd /opt/trackhub/deployment
cp .env.example .env
```

Edit the file with your configuration:

```bash
nano .env
```

Key configurations to update:

```env
# Domain
DOMAIN=trackhub.example.com
ALLOWED_CORS_ORIGINS=https://trackhub.example.com

# Database
DB_CONNECTION_SECURITY=server=db.example.com;user id=postgres;password=SecurePass123;database=TrackHubSecurity;port=5432
DB_CONNECTION_MANAGER=server=db.example.com;user id=postgres;password=SecurePass123;database=TrackHub;port=5432

# Certificate
CERTIFICATE_PASSWORD=your-cert-password

# Encryption (generate a new GUID)
ENCRYPTION_KEY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Update all REACT_APP_ URLs with your domain
REACT_APP_AUTHORIZATION_ENDPOINT=https://trackhub.example.com/Identity/authorize
# ... etc
```

### Step 6: SSL Certificates

#### Option A: Let's Encrypt (Production)

```bash
# Install certbot
sudo apt install -y certbot

# Generate certificate
sudo certbot certonly --standalone -d trackhub.example.com

# Copy certificates
sudo cp /etc/letsencrypt/live/trackhub.example.com/fullchain.pem certificates/
sudo cp /etc/letsencrypt/live/trackhub.example.com/privkey.pem certificates/
sudo chown $USER:$USER certificates/*.pem
```

#### Option B: Self-Signed (Development)

```bash
./scripts/generate-certs.sh trackhub.example.com 365 openiddict
```

### Step 7: Configure OAuth Clients

```bash
cp config/clients.json.example config/clients.json
```

Edit `config/clients.json`:

```json
{
  "scopes": [
    {"name": "web_scope", "resource": "web_resource"},
    {"name": "mobile_scope", "resource": "mobile_resource"},
    {"name": "sec_scope", "resource": "sec_resource"}
  ],
  "PKCEClients": [
    {
      "clientId": "web_client",
      "uri": "https://trackhub.example.com/authentication/callback",
      "scope": "web_scope"
    }
  ],
  "serviceClients": [
    {
      "clientId": "syncworker_client",
      "clientSecret": "generate-a-secure-secret-here"
    }
  ]
}
```

### Step 8: Deploy

```bash
# Full stack deployment
./scripts/deploy.sh full --build

# Monitor deployment
docker compose logs -f
```

### Step 9: Initialize Databases

The database initialization container runs automatically on first deployment. Monitor its progress:

```bash
docker logs -f trackhub-db-init
```

### Step 10: Sync User and Account IDs

The User and Account IDs between the two databases are automatically synchronized during database initialization. However, if you need to run this manually (or re-run it), use the sync script:

```bash
# Run the sync script
./scripts/sync-user-account-ids.sh

# Or run without confirmation prompt
./scripts/sync-user-account-ids.sh --yes
```

**What this script does:**

1. Gets the user ID from `TrackHubSecurity.security.user`
2. Updates `TrackHub.app.user.userid` with the security user ID
3. Updates `TrackHub.app.user_settings.userid` with the security user ID
4. Gets the account ID from `TrackHub.app.account`
5. Updates `TrackHubSecurity.security.user.accountid` with the account ID

**Manual sync (if needed):**

If you prefer to sync manually via SQL:

```bash
# Connect to PostgreSQL
psql -h db.example.com -U postgres

-- Get user ID from security database
SELECT id FROM "TrackHubSecurity".security."user";
-- Example result: 550e8400-e29b-41d4-a716-446655440000

-- Get current user ID from manager database  
SELECT userid FROM "TrackHub".app."user";
-- Example result: 11111111-1111-1111-1111-111111111111

-- Update user ID in manager database
UPDATE "TrackHub".app."user" 
SET userid = '550e8400-e29b-41d4-a716-446655440000' 
WHERE userid = '11111111-1111-1111-1111-111111111111';

UPDATE "TrackHub".app.user_settings 
SET userid = '550e8400-e29b-41d4-a716-446655440000' 
WHERE userid = '11111111-1111-1111-1111-111111111111';

-- Get account ID from manager database
SELECT accountid FROM "TrackHub".app.account;
-- Example result: 660e8400-e29b-41d4-a716-446655440000

-- Update account ID in security database
UPDATE "TrackHubSecurity".security."user" 
SET accountid = '660e8400-e29b-41d4-a716-446655440000' 
WHERE id = '550e8400-e29b-41d4-a716-446655440000';
```

### Step 11: Verify Deployment

```bash
# Health check
./scripts/health-check.sh trackhub.example.com

# Test in browser
# https://trackhub.example.com
```

---

## Centralized Configuration Management

All backend services share similar `appsettings.json` configurations. Instead of manually updating each service's configuration file, use the centralized configuration tools.

### Configuration Workflow

1. **Edit the central `.env` file** with all your settings
2. **Run the generator** to create all `appsettings.json` files
3. **Deploy** to source repositories or use directly in Docker

### Generate AppSettings Files

```bash
# Preview all generated configurations (stdout)
./scripts/generate-appsettings.sh

# Generate to a directory for review
./scripts/generate-appsettings.sh --output-dir ./generated

# Generate for a specific service only
./scripts/generate-appsettings.sh --service manager --output-dir ./generated

# Deploy directly to source repository folders
./scripts/generate-appsettings.sh --deploy-to-sources
```

### Full Configuration Sync

The `sync-config.sh` script handles both backend and frontend configuration:

```bash
# Validate your .env configuration
./scripts/sync-config.sh validate

# Show current configuration values
./scripts/sync-config.sh show

# Generate all backend appsettings.json files
./scripts/sync-config.sh generate

# Deploy to all source repositories (backend + frontend .env)
./scripts/sync-config.sh deploy

# Generate only the React .env file
./scripts/sync-config.sh frontend
```

### Configuration Template

The master template at `config/appsettings.template.json` shows all configurable values and their environment variable mappings:

| Variable | Used By | Description |
|----------|---------|-------------|
| `${ALLOWED_CORS_ORIGINS}` | All services | CORS allowed origins |
| `${AUTHORITY_URL}` | All except Authority | Identity provider URL |
| `${DB_CONNECTION_SECURITY}` | Authority, Security | Security database |
| `${DB_CONNECTION_MANAGER}` | Manager, Geofencing | Manager database |
| `${CERTIFICATE_PATH}` | All services | Path to OpenIddict certificate |
| `${CERTIFICATE_PASSWORD}` | All services | Certificate password |
| `${ENCRYPTION_KEY}` | Security, Manager, Router | Database encryption key |
| `${GRAPHQL_*_SERVICE}` | Various | Internal service URLs |

### When to Regenerate

Regenerate appsettings when you change:
- Domain or URLs
- Database connection strings
- Encryption keys
- Certificate paths or passwords
- Service endpoint URLs

---

## Configuration Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain name | `trackhub.example.com` |
| `ALLOWED_CORS_ORIGINS` | CORS allowed origins | `https://trackhub.example.com` |
| `DB_CONNECTION_SECURITY` | Security DB connection | `server=...;database=TrackHubSecurity;...` |
| `DB_CONNECTION_MANAGER` | Manager DB connection | `server=...;database=TrackHub;...` |
| `CERTIFICATE_PASSWORD` | OpenIddict cert password | `your-password` |
| `ENCRYPTION_KEY` | Database encryption key | `GUID format` |
| `AUTHORITY_URL` | Identity provider URL | `https://domain.com/Identity` |
| `SYNCWORKER_CLIENT_ID` | SyncWorker OAuth client ID | `sync_worker_client` |
| `SYNCWORKER_CLIENT_SECRET` | SyncWorker OAuth client secret | `your-secret` |

### Service Ports (Internal)

| Service | Internal Port |
|---------|---------------|
| Authority | 8080 |
| Security | 8080 |
| Manager | 8080 |
| Router | 8080 |
| Geofencing | 8080 |
| Reporting | 8080 |
| SyncWorker | - (background) |

### URL Paths

| Path | Service |
|------|---------|
| `/` | Frontend (React) |
| `/Identity/*` | Authority Server |
| `/Security/*` | Security API |
| `/Manager/*` | Manager API |
| `/Router/*` | Router API |
| `/Geofence/*` | Geofencing API |
| `/Reporting/*` | Reporting API |

---

## Deployment Scenarios

### Scenario 1: Single Server (Full Stack)

Use `docker-compose.yml`:

```bash
./scripts/deploy.sh full --build
```

### Scenario 2: Separate Frontend and Backend

#### Backend Server

```bash
# Copy .env.backend.example to .env
cp .env.backend.example .env
# Edit with backend-specific settings
nano .env

# Deploy backend only
./scripts/deploy.sh backend --build
```

#### Frontend Server

```bash
# Copy .env.frontend.example to .env
cp .env.frontend.example .env
# Edit with frontend-specific settings (pointing to backend server)
nano .env

# Deploy frontend only
./scripts/deploy.sh frontend --build
```

---

## Database Setup

### PostgreSQL Requirements

- PostgreSQL 13+
- Two databases: `TrackHubSecurity` and `TrackHub`

### Manual Database Creation

If not using the automated initialization:

```sql
-- Create databases
CREATE DATABASE "TrackHubSecurity";
CREATE DATABASE "TrackHub";

-- Create user (if needed)
CREATE USER trackhub WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE "TrackHubSecurity" TO trackhub;
GRANT ALL PRIVILEGES ON DATABASE "TrackHub" TO trackhub;
```

### Running Initializers Manually

```bash
# Build and run ClientSeeder
cd /opt/trackhub/TrackHub.AuthorityServer/src/ClientSeeder
dotnet build
dotnet run

# Build and run Security DBInitializer
cd /opt/trackhub/TrackHubSecurity/src/DBInitializer
dotnet build
dotnet run

# Build and run Manager DBInitializer
cd /opt/trackhub/TrackHub.Manager/src/DBInitializer
dotnet build
dotnet run
```

---

## Migrating to a New Server (Existing Database)

If you already have a running TrackHub installation and want to migrate the application services to a new server while keeping your existing database, follow these steps:

### What the db-init Container Does

The `db-init` container performs the following on first run:

1. **ClientSeeder** - Inserts OAuth clients into the database
2. **Security DBInitializer** - Creates/migrates security database schema
3. **Manager DBInitializer** - Creates/migrates manager database schema
4. **Sync User/Account IDs** - Updates foreign keys between databases

For migrations with existing data, you should **skip the db-init** to avoid potential conflicts with existing OAuth clients.

### Option 1: Deploy Without db-init (Recommended)

Start all services except db-init:

```bash
# Configure your .env with existing database connection strings
cp .env.example .env
nano .env  # Set DB_CONNECTION_SECURITY and DB_CONNECTION_MANAGER

# Deploy without db-init
docker compose up -d --no-deps nginx frontend authority security manager router geofencing reporting syncworker
```

### Option 2: Use --skip-init Flag

```bash
./scripts/deploy.sh full --build --skip-init
```

### Option 3: Pre-create the Initialization Flag

If you want to use the normal deployment process but skip initialization:

```bash
# Create the flag volume and file manually
docker volume create deployment_db-init-flag
docker run --rm -v deployment_db-init-flag:/flags alpine touch /flags/db-initialized

# Now deploy normally - db-init will detect the flag and skip
./scripts/deploy.sh full --build
```

### Option 4: Comment Out db-init in docker-compose.yml

Edit `docker-compose.yml` and comment out the db-init service:

```yaml
# db-init:
#   build:
#     context: .
#     dockerfile: docker/Dockerfile.db-init
#   ...
```

Then remove the dependency from the authority service.

### Migration Checklist

- [ ] Backup existing database before migration
- [ ] Verify PostgreSQL is accessible from new server
- [ ] Copy SSL certificates (`certificates/` folder)
- [ ] Copy OpenIddict certificate (`certificate.pfx`)
- [ ] Update `.env` with correct database connection strings
- [ ] Update `.env` with new server's domain (if changed)
- [ ] Choose one of the skip options above
- [ ] Deploy and verify services connect properly
- [ ] Test authentication flow
- [ ] Test API endpoints

---

## SSL Certificates

### Production (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone -d your-domain.com

# Set up auto-renewal
sudo crontab -e
# Add: 0 0 1 * * certbot renew --quiet && docker restart trackhub-nginx
```

### OpenIddict Certificate

For the Authority Server, you need a certificate for token signing:

```bash
# Generate using the script
./scripts/generate-certs.sh your-domain.com 365 your-password

# Or generate manually
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
openssl pkcs12 -export -out certificate.pfx -inkey key.pem -in cert.pem
```

---

## Updating Services

### Update Single Service

```bash
# Update only the manager service
./scripts/update-service.sh manager

# Update only the frontend
./scripts/update-service.sh frontend
```

### Update All Services

```bash
# Pull latest code
cd /opt/trackhub/TrackHub && git pull
cd /opt/trackhub/TrackHub.Manager && git pull
# ... repeat for all repos

# Rebuild and deploy
cd /opt/trackhub/deployment
./scripts/deploy.sh full --build
```

### Zero-Downtime Updates

For production environments, update services one at a time:

```bash
# Update backend services
./scripts/update-service.sh authority
./scripts/update-service.sh security
./scripts/update-service.sh manager
./scripts/update-service.sh router
./scripts/update-service.sh geofencing
./scripts/update-service.sh reporting

# Update frontend last
./scripts/update-service.sh frontend
./scripts/update-service.sh nginx
```

---

## Monitoring & Maintenance

### View Logs

```bash
# All services
./scripts/logs.sh

# Specific service
./scripts/logs.sh manager

# Last 50 lines, no follow
./scripts/logs.sh security -n 50 --no-follow
```

### Health Checks

```bash
# Check all services
./scripts/health-check.sh your-domain.com

# HTTP endpoints
curl -k https://your-domain.com/health
curl -k https://your-domain.com/health/authority
curl -k https://your-domain.com/health/security
```

### Backup Configuration

```bash
# Create backup
./scripts/backup.sh

# Backups are stored in deployment/backups/
```

### Database Backup & Restore

```bash
# Backup security database
./scripts/backup-database.sh backup security

# Backup manager database  
./scripts/backup-database.sh backup manager

# List all backups
./scripts/backup-database.sh list

# Restore from backup
./scripts/backup-database.sh restore security backups/db/security_20241201_120000.sql

# Cleanup old backups (keep last 7 days)
./scripts/backup-database.sh cleanup 7
```

### Version Management & Rollback

```bash
# Tag current version before making changes
./scripts/rollback.sh tag v1.0.0

# List all tagged versions
./scripts/rollback.sh list

# Rollback to a previous version
./scripts/rollback.sh rollback v1.0.0

# Delete a version tag
./scripts/rollback.sh delete v1.0.0
```

### SSL Certificate Renewal

```bash
# Manual renewal
./scripts/renew-ssl.sh

# Set up automatic renewal (cron)
sudo ./scripts/renew-ssl.sh --install-cron
```

### Service Management

```bash
# Stop all services
docker compose down

# Start all services
docker compose up -d

# Restart specific service
docker compose restart manager

# View service status
docker compose ps
```

### Resource Monitoring

```bash
# Container resource usage
docker stats

# System resources
htop
```

---

## Troubleshooting

### Common Issues

#### Services won't start

```bash
# Check logs
docker compose logs --tail=100

# Check specific service
docker logs trackhub-authority
```

#### Database connection issues

```bash
# Test connectivity from container
docker exec -it trackhub-authority ping db-server.com

# Check environment variables
docker exec -it trackhub-authority env | grep DB_
```

#### Certificate issues

```bash
# Verify certificate files exist
ls -la certificates/

# Test certificate
openssl x509 -in certificates/fullchain.pem -text -noout
```

#### CORS errors

1. Check `ALLOWED_CORS_ORIGINS` in `.env`
2. Ensure frontend URL matches exactly (including protocol)
3. Check nginx configuration

#### 502 Bad Gateway

1. Check if backend service is running: `docker compose ps`
2. Check service logs: `docker logs trackhub-<service>`
3. Verify network connectivity between containers

### Debug Mode

Enable detailed logging:

```bash
# Add to service environment in docker-compose.yml
environment:
  - ASPNETCORE_ENVIRONMENT=Development
  - Logging__LogLevel__Default=Debug
```

### Reset Deployment

```bash
# Stop and remove everything
docker compose down -v --remove-orphans

# Remove all images
docker system prune -a

# Re-deploy
./scripts/deploy.sh full --build
```

---

## Security Considerations

1. **Never commit `.env` files** to version control
2. **Use strong passwords** for database and certificates
3. **Keep Docker and OS updated** with security patches
4. **Use Let's Encrypt** for production SSL certificates
5. **Configure firewall** to only allow necessary ports
6. **Regular backups** of configuration and database
7. **Monitor logs** for suspicious activity

---

## Support

For issues and questions:
- GitHub Issues: [TrackHub Repository](https://github.com/shernandezp/TrackHub/issues)
- Documentation: [Project README](https://github.com/shernandezp/TrackHub)

---

## License

Apache License 2.0 - See individual repository LICENSE files for details.
