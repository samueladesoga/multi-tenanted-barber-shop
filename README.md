# BarberApp

A multi-tenant SaaS application for managing barber salons. Each salon gets its own subdomain (`salon.barberapp.club`) with isolated data, staff authentication, customer QR-code loyalty tracking, appointment booking, service management, expense logging, and profitability reports.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Local Development Setup](#local-development-setup)
  - [Prerequisites](#prerequisites)
  - [Install Ruby 3.4.2](#install-ruby-342)
  - [Clone and Bootstrap](#clone-and-bootstrap)
  - [Configure Local Subdomains](#configure-local-subdomains)
  - [Environment Variables](#environment-variables)
  - [Database Setup](#database-setup)
  - [Seed Demo Data](#seed-demo-data)
  - [Run the App](#run-the-app)
  - [Register a Salon](#register-a-salon)
- [Background Jobs](#background-jobs)
- [Email in Development](#email-in-development)
- [SMS in Development](#sms-in-development)
- [Hetzner VPS Deployment](#hetzner-vps-deployment)
  - [Environment Strategy](#environment-strategy)
  - [Infrastructure Overview](#infrastructure-overview)
  - [1. Provision a Server](#1-provision-a-server)
  - [2. Configure DNS](#2-configure-dns)
  - [3. Run the Server Setup Script](#3-run-the-server-setup-script)
  - [4. Configure deploy.yml Files](#4-configure-deployyml-files)
  - [5. Configure Secrets](#5-configure-secrets)
  - [6. First Deploy — Staging](#6-first-deploy--staging)
  - [7. First Deploy — Production](#7-first-deploy--production)
  - [8. Stop kamal-proxy](#8-stop-kamal-proxy)
  - [9. Subsequent Deploys](#9-subsequent-deploys)
  - [10. Useful Kamal Commands](#10-useful-kamal-commands)
- [11. Backups](#11-backups)
- [Database Schema](#database-schema)
- [URL Structure](#url-structure)

---

## Architecture Overview

```
                           ┌─────────────────────────────────┐
                           │         Hetzner VPS              │
                           │                                  │
Internet ──HTTPS──►  Nginx (443/80)                          │
                     wildcard SSL cert                        │
                     *.barberapp.club                          │
                           │                                  │
                           ▼                                  │
                     localhost:3000                           │
                           │                                  │
                           ▼                                  │
                     App Container (Puma/Thruster)            │
                           │                                  │
                     ┌─────┴──────┐                          │
                     ▼            ▼                           │
               PostgreSQL    Solid Queue                      │
               (accessory)   (background jobs,               │
                              cron reminders)                 │
                           └─────────────────────────────────┘
```

**Multi-tenancy** is subdomain-based. The request host determines the current salon via `acts_as_tenant`. All database queries are automatically scoped to that salon. The root domain (`barberapp.club`) hosts the marketing page and salon registration form.

---

## Features

- **Salon registration** — owners self-register with name, subdomain, working hours, chair count, and loyalty threshold
- **Staff authentication** — Devise-based login scoped per tenant; owner vs staff roles
- **Customer management** — name, phone, email, area, state; QR code generated per customer
- **QR loyalty programme** — visits tracked by QR scan or phone/name lookup; free cut after N visits (configurable per salon)
- **Appointment booking** — staff-side and public self-booking; slot engine respects working hours, chair count, and existing bookings; 30-minute slots by default
- **SMS + email notifications** — on appointment booked, confirmed, and cancelled; day-before reminders via Solid Queue cron (Twilio + SMTP)
- **Services catalogue** — name, price, duration; mark active/inactive
- **Price overrides** — staff can discount the base price at visit time with an optional reason
- **Expense logging** — categorised expenses (rent, supplies, utilities, wages, marketing, equipment, other)
- **Reports** — monthly P&L with charts; per-service profitability; discount analysis
- **Owner-only areas** — team management, settings, working hours (enforced server-side)
- **Print-friendly QR card** — Stimulus-powered print button; clean print CSS

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.4.2 |
| Framework | Rails 8.1.3 |
| Database | PostgreSQL 16 |
| CSS | Tailwind CSS v4 |
| JS | Hotwire (Turbo + Stimulus), Importmap |
| Assets | Propshaft |
| Auth | Devise |
| Multi-tenancy | acts_as_tenant |
| Background jobs | Solid Queue |
| Charts | Chartkick + Chart.js (CDN) |
| QR codes | rqrcode |
| SMS | twilio-ruby |
| Email (dev) | letter_opener |
| Deploy | Kamal 2 |
| Web server | Puma + Thruster |
| Reverse proxy | Nginx (wildcard SSL) |

---

## Local Development Setup

### Prerequisites

You need the following installed on your machine:

- **macOS** (these instructions assume macOS; Linux steps are similar)
- **Homebrew** — [brew.sh](https://brew.sh)
- **rbenv** or **rvm** for Ruby version management
- **PostgreSQL 14+** running locally
- **Node.js** (only needed if you run Tailwind's watcher manually; not required for basic dev)

Install system dependencies:

```bash
brew install openssl@3 libyaml postgresql@16
brew services start postgresql@16
```

---

### Install Ruby 3.4.2

Ruby 3.4.2 is required for Rails 8.1.3. If you are on Apple Silicon (M1/M2/M3), you must point the compiler at Homebrew's OpenSSL.

**With rbenv:**

```bash
RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)" \
  rbenv install 3.4.2
rbenv global 3.4.2   # or: rbenv local 3.4.2 inside the project
```

**With rvm:**

```bash
rvm install ruby-3.4.2 --with-openssl-dir=$(brew --prefix openssl@3)
rvm use 3.4.2 --default
```

Verify:

```bash
ruby -v
# ruby 3.4.2 ...
```

---

### Clone and Bootstrap

```bash
git clone <your-repo-url> barberapp
cd barberapp

# Install gems
bundle install

# Install Tailwind CSS binary
bin/rails tailwindcss:install   # only needed on first setup

# Install git hooks (RuboCop + Brakeman run on every commit)
bin/setup-hooks
```

---

### Configure Local Subdomains

The app routes on subdomains. In development you need `barberapp.localhost` (the marketing root) and `demo.barberapp.localhost` (a salon subdomain) to resolve to `127.0.0.1`.

**Option A — `/etc/hosts` (simplest):**

Add the following lines to `/etc/hosts` (you will need to add a new line each time you create a new test salon):

```
127.0.0.1  barberapp.localhost
127.0.0.1  demo.barberapp.localhost
127.0.0.1  mysalon.barberapp.localhost
```

**Option B — dnsmasq (recommended for active development):**

Dnsmasq resolves all `*.localhost` addresses to `127.0.0.1` automatically, so you never need to edit `/etc/hosts` again.

```bash
brew install dnsmasq

# Route *.localhost to loopback
echo "address=/.localhost/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf

brew services start dnsmasq

# Tell macOS to use dnsmasq for .localhost lookups
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/localhost
```

Test it:

```bash
ping -c 1 anything.localhost   # should resolve to 127.0.0.1
```

**Rails TLD config** — the app is already configured for single-segment TLDs:

```ruby
# config/application.rb
config.action_dispatch.tld_length = 1
```

This means `barberapp.localhost` is treated as the root (TLD = `localhost`), and `demo.barberapp.localhost` has the subdomain `demo`.

---

### Environment Variables

The app reads optional environment variables for SMS. Copy and customise the example below — these are not required to start the server in development (the app will fall back gracefully).

Create a `.env` file or add to your shell profile:

```bash
# Twilio SMS (optional in development — SmsService logs to console if absent)
export TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export TWILIO_AUTH_TOKEN="your_auth_token"
export TWILIO_FROM="+1234567890"
```

No `.env` gem is included. Either `source` the file before starting the server, or add the exports to your `~/.zshrc` / `~/.bashrc`.

---

### Database Setup

Make sure PostgreSQL is running, then:

```bash
bin/rails db:create db:migrate
```

This creates `barberapp_development` and `barberapp_test` databases and runs all migrations.

---

### Seed Demo Data

A demo salon is included for development, staging, and production demos. It creates a realistic Nigerian barbershop with staff, customers, visits, appointments, and expenses so you can explore every feature immediately.

```bash
bin/rails db:seed
```

**What gets created:**

| Thing | Detail |
|---|---|
| Salon | **Chukwu's Cuts** — subdomain `demo`, NGN, 3 chairs, every 5th cut free |
| Owner | `emeka@democuts.com` / `password123` |
| Staff | Tunde Adeyemi, Chioma Eze — same password |
| Services | 6 services from ₦1,000 (Hair Wash) to ₦6,000 (Locs Maintenance) |
| Working hours | Mon–Sat open, Sunday closed |
| Customers | 10 Lagos-based customers |
| Visits | 34 visits spread across 2 months — loyalty milestones, discounts, multiple staff |
| Appointments | 7 upcoming — mix of pending/confirmed, staff-booked and self-booked |
| Expenses | 12 expenses across 2 months — rent, wages, supplies, equipment |

The seed is **idempotent** — safe to run multiple times in any environment without duplicating data.

**Visit the demo salon after seeding:**

| URL | What you see |
|---|---|
| `http://demo.barberapp.localhost:3000` | Public salon home page |
| `http://demo.barberapp.localhost:3000/book` | Public customer booking page |
| `http://demo.barberapp.localhost:3000/dashboard` | Staff dashboard (login required) |

**To run on staging or production:**

```bash
kamal app exec -d staging "bin/rails db:seed"
kamal app exec "bin/rails db:seed"
```

---

### Run the App

Start all processes with the Rails dev server (Tailwind CSS watcher runs in parallel):

```bash
bin/dev
```

This runs `Procfile.dev` which starts:
- `rails server` on port 3000
- `tailwindcss --watch` for CSS hot-reload

Visit:

| URL | What you see |
|---|---|
| `http://barberapp.localhost:3000` | Marketing / registration page |
| `http://demo.barberapp.localhost:3000` | A salon's app (after registering `demo`) |

---

### Register a Salon

1. Open `http://barberapp.localhost:3000`
2. Click **Register your salon**
3. Fill in salon name, subdomain (e.g. `demo`), owner details, working hours, chair count, and loyalty threshold
4. Submit — you are redirected to `http://demo.barberapp.localhost:3000`
5. Sign in with the owner email and password you just set
6. You will land on the dashboard

From here you can:
- Add services (Services → New Service)
- Add staff members (Team → New Staff Member) — owner role only
- Register customers (Customers → New Customer)
- Record visits and book appointments

---

## Background Jobs

Solid Queue powers background jobs and the daily cron. In development it runs inside the Puma process automatically (`SOLID_QUEUE_IN_PUMA=true` is the default).

The cron schedule is defined in `config/recurring.yml`:

```yaml
development:
  appointment_reminders:
    class: AppointmentReminderJob
    schedule: "0 9 * * *"   # daily at 9am — reminds customers of tomorrow's appointments
```

To run a reminder manually in development:

```bash
bin/rails runner "AppointmentReminderJob.perform_now"
```

---

## Email in Development

The `letter_opener` gem is configured for development. All emails open in your default browser instead of being sent. No SMTP configuration is needed.

---

## SMS in Development

`SmsService` checks for Twilio credentials at call time. If `TWILIO_ACCOUNT_SID` is blank, it logs the message to the Rails console instead of making an API call. You will see lines like:

```
[SmsService] SMS to +44... : "Your appointment tomorrow at 10:00am..."
```

---

## Hetzner VPS Deployment

### Environment Strategy

Both staging and production run on the **same single Hetzner VPS**. Kamal 2's **destination** feature handles the split cleanly, with port separation preventing conflicts:

| | Staging | Production |
|---|---|---|
| Kamal command | `kamal ... -d staging` | `kamal ...` |
| Config file | `config/deploy.yml` + `config/deploy.staging.yml` | `config/deploy.yml` |
| Secrets file | `.kamal/secrets.staging` | `.kamal/secrets` |
| Domain | `*.staging.barberapp.club` | `*.barberapp.club` |
| App port | `127.0.0.1:3001` | `127.0.0.1:3000` |
| Database port | `127.0.0.1:5433` | `127.0.0.1:5432` |
| Database | `barberapp_staging` | `barberapp_production` |
| Log level | `debug` | `info` |

`config/deploy.staging.yml` is **deep-merged** on top of `config/deploy.yml` by Kamal. Only the values that differ (port bindings, domain, DB name, log level) live in the staging file. Everything else (image name, registry, SSH user, volumes, aliases) is inherited from the base.

---

### Infrastructure Overview

Both staging and production run on the **same single Hetzner VPS**. Port separation prevents conflicts:

```
DNS (Hetzner / your registrar)
  barberapp.club            → SERVER_IP
  *.barberapp.club          → SERVER_IP
  staging.barberapp.club    → SERVER_IP   (same server)
  *.staging.barberapp.club  → SERVER_IP   (same server)

Single Hetzner VPS (Ubuntu 22.04/24.04)
  Nginx              — ports 80 and 443, wildcard SSL, reverse proxy
  Docker             — runs containers managed by Kamal

  Production app     — Puma + Thruster → 127.0.0.1:3000
  Production DB      — PostgreSQL      → 127.0.0.1:5432

  Staging app        — Puma + Thruster → 127.0.0.1:3001
  Staging DB         — PostgreSQL      → 127.0.0.1:5433

  Solid Queue        — runs inside Puma in both environments
```

Nginx routes traffic by subdomain:
- `*.barberapp.club` → `localhost:3000` (production)
- `*.staging.barberapp.club` → `localhost:3001` (staging)

**Why Nginx instead of kamal-proxy?**
Kamal's built-in proxy uses Let's Encrypt's HTTP-01 challenge, which can only issue single-hostname certificates. Wildcard certificates (`*.barberapp.club`) require a DNS-01 challenge. Nginx + Certbot (with the Hetzner DNS plugin) handles this correctly.

---

### 1. Provision a Server

In the [Hetzner Cloud console](https://console.hetzner.cloud):

1. Create a project (e.g. `barberapp`)
2. Create one server — Ubuntu 22.04, type **CX21** (2 vCPU / 4 GB RAM) or larger
   - CX21 comfortably runs both the production and staging app containers plus two PostgreSQL containers
3. Add your SSH public key during creation
4. Note the public IPv4 address (referred to as `SERVER_IP` throughout these instructions)

---

### 2. Configure DNS

In your domain registrar (or Hetzner DNS console), add these A records — all pointing to the **same** `SERVER_IP`:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `@` | `SERVER_IP` | 300 |
| A | `*` | `SERVER_IP` | 300 |
| A | `staging` | `SERVER_IP` | 300 |
| A | `*.staging` | `SERVER_IP` | 300 |

Wait for propagation before running Certbot (5–10 minutes for Hetzner DNS):

```bash
dig barberapp.club +short                # → SERVER_IP
dig demo.barberapp.club +short           # → SERVER_IP
dig staging.barberapp.club +short        # → SERVER_IP
dig demo.staging.barberapp.club +short   # → SERVER_IP
```

---

### 3. Run the Server Setup Script

Run `script/server_setup.sh` **once on your single server**. The script:

- Creates a `deploy` user (Kamal SSHes in as this user)
- Installs Docker CE
- Installs Nginx
- Installs Certbot with the Hetzner DNS plugin
- Obtains **both** wildcard Let's Encrypt certificates (`*.barberapp.club` and `*.staging.barberapp.club`)
- Installs the Nginx site config (which proxies production on port 3000 and staging on port 3001)
- Schedules automatic cert renewal (twice daily via cron)

**Before running**, edit `script/server_setup.sh` and set the variable at the top:

```bash
HETZNER_API_TOKEN=""     # create at console.hetzner.cloud → Security → API Tokens
```

**Copy and run the script:**

```bash
scp script/server_setup.sh root@SERVER_IP:/root/
scp config/nginx/barberapp.conf root@SERVER_IP:/root/barberapp.conf

# Edit HETZNER_API_TOKEN inside the script first, then:
ssh root@SERVER_IP "bash /root/server_setup.sh"
```

The Nginx config proxies both environments from the same server:
- `*.barberapp.club` → `localhost:3000` (production)
- `*.staging.barberapp.club` → `localhost:3001` (staging)

Verify Nginx is serving HTTPS after setup:

```bash
curl -I https://staging.barberapp.club   # HTTP/2 200 (or 502 until app is deployed)
curl -I https://barberapp.club           # HTTP/2 200 (or 502 until app is deployed)
```

---

### 4. Configure deploy.yml Files

Open `config/deploy.yml` (production) and replace the placeholders:

```yaml
image: YOUR_DOCKERHUB_USERNAME/barberapp   # ← your Docker Hub username
servers:
  web:
    hosts:
      - SERVER_IP                          # ← your Hetzner VPS IPv4
accessories:
  db:
    host: SERVER_IP                        # ← same IP
env:
  clear:
    APP_HOST: barberapp.club                # ← your production domain
```

Open `config/deploy.staging.yml` and replace the placeholder:

```yaml
servers:
  web:
    hosts:
      - SERVER_IP                          # ← same Hetzner VPS as production
    options:
      publish:
        - "127.0.0.1:3001:80"             # staging app on port 3001 (prod uses 3000)
accessories:
  db:
    host: SERVER_IP                        # ← same server
    port: "127.0.0.1:5433:5432"           # staging DB on port 5433 (prod uses 5432)
env:
  clear:
    APP_HOST: staging.barberapp.club        # ← your staging domain
```

If you do not have a Docker Hub account, create a free one at [hub.docker.com](https://hub.docker.com) and create a repository named `barberapp`.

---

### 5. Configure Secrets

All secrets are pulled from your **local shell** at deploy time. The `.kamal/secrets` and `.kamal/secrets.staging` files reference shell variables and are safe to commit — they contain no values.

**Production secrets** — set before running `kamal deploy`:

```bash
export KAMAL_REGISTRY_PASSWORD="your_dockerhub_access_token"
export POSTGRES_PASSWORD="strong_production_password"
export DATABASE_URL="postgresql://barberapp:strong_production_password@127.0.0.1:5432/barberapp_production"
export TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export TWILIO_AUTH_TOKEN="your_auth_token"
export TWILIO_FROM="+1234567890"
export SMTP_ADDRESS="smtp.postmarkapp.com"
export SMTP_USERNAME="your_smtp_username"
export SMTP_PASSWORD="your_smtp_password"
```

**Staging secrets** — set before running `kamal deploy -d staging`:

```bash
export KAMAL_REGISTRY_PASSWORD="your_dockerhub_access_token"  # same registry
export STAGING_POSTGRES_PASSWORD="strong_staging_password"
export STAGING_DATABASE_URL="postgresql://barberapp:strong_staging_password@127.0.0.1:5433/barberapp_staging"
# Twilio and SMTP can reuse production values or point to sandbox accounts
export TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export TWILIO_AUTH_TOKEN="your_auth_token"
export TWILIO_FROM="+1234567890"
export SMTP_ADDRESS="smtp.postmarkapp.com"
export SMTP_USERNAME="your_smtp_username"
export SMTP_PASSWORD="your_smtp_password"
```

A convenient pattern is to keep two sourced files:

```bash
# ~/.barberapp_prod_secrets
# ~/.barberapp_staging_secrets
```

Then before deploying:

```bash
source ~/.barberapp_prod_secrets && kamal deploy
source ~/.barberapp_staging_secrets && kamal deploy -d staging
```

`RAILS_MASTER_KEY` is read directly from `config/master.key` in both secrets files. **Never commit `config/master.key`.**

---

### 6. First Deploy — Staging

Run the full bootstrap for staging first. This lets you validate the setup before touching production.

```bash
source ~/.barberapp_staging_secrets

kamal setup -d staging
```

`kamal setup` will:
1. SSH into the server as `deploy`
2. Install Docker (if absent)
3. Start kamal-proxy and the staging PostgreSQL accessory (port 5433)
4. Build and push the Docker image
5. Pull and start the staging app container (port 3001)
6. Run `bin/rails db:migrate`

Verify staging is working:

```bash
kamal logs -d staging
kamal app exec -d staging "bin/rails runner 'puts Salon.count'"
```

Then stop kamal-proxy for staging (Nginx is the proxy):

```bash
kamal proxy stop -d staging
```

Visit `https://staging.barberapp.club` — you should see the BarberApp homepage.

---

### 7. First Deploy — Production

Once staging is confirmed working, deploy production to the same server:

```bash
source ~/.barberapp_prod_secrets

kamal setup
```

This starts the production app on port 3000 and its PostgreSQL accessory on port 5432, alongside the already-running staging containers.

Verify production:

```bash
kamal logs
kamal app exec "bin/rails runner 'puts Salon.count'"
```

Stop kamal-proxy for production:

```bash
kamal proxy stop
```

Visit `https://barberapp.club`.

> **Note:** Every time you run `kamal setup` it (re)starts kamal-proxy. Run `kamal proxy stop` (or `kamal proxy stop -d staging`) afterwards. Routine `kamal deploy` updates do not restart kamal-proxy.

---

### 8. Stop kamal-proxy

After any fresh `kamal setup`, stop kamal-proxy before Nginx can take over. Since both environments run on the same server, run this for each:

```bash
kamal proxy stop             # production
kamal proxy stop -d staging  # staging
```

---

### 9. Subsequent Deploys

For ongoing code changes:

```bash
# Deploy to staging first — validate — then promote to production
kamal deploy -d staging
# ... test on staging.barberapp.club ...
kamal deploy

# Roll back if needed
kamal rollback -d staging
kamal rollback
```

Migrations run automatically on every deploy via the deploy hook. Zero-downtime rolling restart is used by default.

---

### 10. Useful Kamal Commands

Append `-d staging` to any command to target the staging environment.

```bash
# View live logs
kamal logs
kamal logs -d staging

# Rails console
kamal console
kamal console -d staging

# Bash shell in the running container
kamal shell
kamal shell -d staging

# Run a one-off Rails command
kamal app exec "bin/rails db:migrate:status"
kamal app exec -d staging "bin/rails db:migrate:status"

# Database console
kamal dbc
kamal dbc -d staging

# Restart without deploying a new image
kamal app restart
kamal app restart -d staging

# Container status
kamal app details
kamal app details -d staging

# Nginx access logs on the server (both environments share the same server)
ssh deploy@SERVER_IP "sudo tail -f /var/log/nginx/access.log"

# Renew SSL certificates manually (auto-renewal runs via cron)
ssh deploy@SERVER_IP "sudo certbot renew && sudo systemctl reload nginx"
```

---

### 11. Backups

There are two things to back up: the **PostgreSQL database** and the **Active Storage uploaded files**. Both are backed up to Hetzner Object Storage (S3-compatible, ~€0.006/GB/month — effectively free at this scale).

#### Create a Hetzner Object Storage bucket

In the Hetzner Cloud console → Object Storage → Create bucket (e.g. `barberapp-backups`). Note the endpoint, access key, and secret key.

#### Install and configure s3cmd on the server

```bash
ssh deploy@SERVER_IP
sudo apt install s3cmd -y
s3cmd --configure   # enter your Hetzner Object Storage credentials when prompted
```

#### Create the backup script

```bash
sudo nano /usr/local/bin/backup_db.sh
```

```bash
#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ── Production database ────────────────────────────────────────────────────────
PROD_FILE="/tmp/barberapp_prod_${TIMESTAMP}.sql.gz"
docker exec barberapp-db pg_dump -U barberapp barberapp_production | gzip > "$PROD_FILE"
s3cmd put "$PROD_FILE" s3://barberapp-backups/db/
rm "$PROD_FILE"

# ── Staging database ───────────────────────────────────────────────────────────
# The staging PostgreSQL container is named barberapp-db (staging destination)
STAGING_FILE="/tmp/barberapp_staging_${TIMESTAMP}.sql.gz"
docker exec barberapp-staging-db pg_dump -U barberapp barberapp_staging | gzip > "$STAGING_FILE"
s3cmd put "$STAGING_FILE" s3://barberapp-backups/db/
rm "$STAGING_FILE"

# ── Active Storage volume (production) ────────────────────────────────────────
STORAGE_FILE="/tmp/storage_${TIMESTAMP}.tar.gz"
docker run --rm \
  -v barberapp_storage:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/storage_${TIMESTAMP}.tar.gz /data

s3cmd put "$STORAGE_FILE" s3://barberapp-backups/storage/
rm "$STORAGE_FILE"

echo "Backup complete: ${TIMESTAMP}"
```

```bash
sudo chmod +x /usr/local/bin/backup_db.sh
```

#### Schedule with cron

```bash
sudo crontab -e
```

```
# Daily backup at 2am
0 2 * * * /usr/local/bin/backup_db.sh >> /var/log/barberapp_backup.log 2>&1

# Weekly cleanup — delete backups older than 30 days
0 3 * * 0 s3cmd del --recursive s3://barberapp-backups/db/ --older-than=30
0 3 * * 0 s3cmd del --recursive s3://barberapp-backups/storage/ --older-than=30
```

#### Restore from a backup

```bash
# Download the backup you want to restore
s3cmd get s3://barberapp-backups/db/barberapp_prod_20260412_020000.sql.gz /tmp/restore.sql.gz

# Restore into the production PostgreSQL container
gunzip -c /tmp/restore.sql.gz | docker exec -i barberapp-db psql -U barberapp barberapp_production

# To restore staging:
s3cmd get s3://barberapp-backups/db/barberapp_staging_20260412_020000.sql.gz /tmp/restore.sql.gz
gunzip -c /tmp/restore.sql.gz | docker exec -i barberapp-staging-db psql -U barberapp barberapp_staging
```

#### Summary

| What | Method | Frequency | Retention |
|---|---|---|---|
| Database | `pg_dump` → gzip → Hetzner Object Storage | Daily at 2am | 30 days |
| Active Storage files | Docker volume → tar → Hetzner Object Storage | Daily at 2am | 30 days |
| VPS snapshot | Hetzner Cloud console → Snapshots | Before major deploys | Manual |

> **Tip:** Take a manual VPS snapshot in the Hetzner Cloud console before running `kamal setup` for the first time and before any large database migration. A snapshot captures the full server state and can be restored in one click (~€0.01/GB/month).

---

## Database Schema

| Table | Purpose |
|---|---|
| `salons` | Tenant record; subdomain, name, loyalty_threshold, chair_count |
| `staffs` | Devise auth; role (owner / staff); belongs to salon |
| `customers` | Name, phone, email, area, state; QR token; visits_count counter cache |
| `visits` | Each haircut; price_charged, is_free, discount_reason; belongs to customer + service + staff |
| `appointments` | Scheduled slots; status enum (pending/confirmed/completed/cancelled/no_show); belongs to customer + service + staff |
| `services` | Catalogue entry; base_price, duration_minutes, active flag |
| `expenses` | Categorised costs; amount, incurred_on, description |
| `working_hours` | One row per day of week per salon; opens_at, closes_at, is_closed |

---

## URL Structure

| URL pattern | Description |
|---|---|
| `barberapp.club` | Marketing homepage |
| `barberapp.club/register` | New salon registration |
| `[subdomain].barberapp.club` | Salon dashboard (requires staff login) |
| `[subdomain].barberapp.club/customers` | Customer list |
| `[subdomain].barberapp.club/visits` | Visit history |
| `[subdomain].barberapp.club/appointments` | Appointment list |
| `[subdomain].barberapp.club/book` | Public customer self-booking (no login) |
| `[subdomain].barberapp.club/scan/:qr_token` | QR code scan endpoint (no login) |
| `[subdomain].barberapp.club/services` | Services catalogue |
| `[subdomain].barberapp.club/expenses` | Expense log |
| `[subdomain].barberapp.club/reports` | Monthly P&L report |
| `[subdomain].barberapp.club/reports/services` | Service profitability |
| `[subdomain].barberapp.club/reports/discounts` | Discount analysis |
| `[subdomain].barberapp.club/working_hours` | Working hours (owner only) |
| `[subdomain].barberapp.club/staffs` | Team management (owner only) |
| `[subdomain].barberapp.club/settings` | Salon settings (owner only) |
