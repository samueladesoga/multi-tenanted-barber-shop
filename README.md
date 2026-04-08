# BarberApp

A multi-tenant SaaS application for managing barber salons. Each salon gets its own subdomain (`salon.barberapp.com`) with isolated data, staff authentication, customer QR-code loyalty tracking, appointment booking, service management, expense logging, and profitability reports.

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
  - [Run the App](#run-the-app)
  - [Register a Salon](#register-a-salon)
- [Background Jobs](#background-jobs)
- [Email in Development](#email-in-development)
- [SMS in Development](#sms-in-development)
- [Hetzner VPS Deployment](#hetzner-vps-deployment)
  - [Environment Strategy](#environment-strategy)
  - [Infrastructure Overview](#infrastructure-overview)
  - [1. Provision Two Servers](#1-provision-two-servers)
  - [2. Configure DNS](#2-configure-dns)
  - [3. Run the Server Setup Script](#3-run-the-server-setup-script)
  - [4. Configure deploy.yml Files](#4-configure-deployyml-files)
  - [5. Configure Secrets](#5-configure-secrets)
  - [6. First Deploy — Staging](#6-first-deploy--staging)
  - [7. First Deploy — Production](#7-first-deploy--production)
  - [8. Stop kamal-proxy on Both Servers](#8-stop-kamal-proxy-on-both-servers)
  - [9. Subsequent Deploys](#9-subsequent-deploys)
  - [10. Useful Kamal Commands](#10-useful-kamal-commands)
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
                     *.barberapp.com                          │
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

**Multi-tenancy** is subdomain-based. The request host determines the current salon via `acts_as_tenant`. All database queries are automatically scoped to that salon. The root domain (`barberapp.com`) hosts the marketing page and salon registration form.

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

There are no seed files — salons register themselves through the UI.

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

The app uses two separate Hetzner VPS instances — one for staging and one for production. Kamal 2's **destination** feature handles the split cleanly:

| | Staging | Production |
|---|---|---|
| Kamal command | `kamal ... -d staging` | `kamal ...` |
| Config file | `config/deploy.yml` + `config/deploy.staging.yml` | `config/deploy.yml` |
| Secrets file | `.kamal/secrets.staging` | `.kamal/secrets` |
| Domain | `*.staging.barberapp.com` | `*.barberapp.com` |
| Database | `barberapp_staging` | `barberapp_production` |
| Log level | `debug` | `info` |

`config/deploy.staging.yml` is **deep-merged** on top of `config/deploy.yml` by Kamal. Only the values that differ (server IP, domain, DB name, log level) live in the staging file. Everything else (image name, registry, SSH user, volumes, aliases) is inherited from the base.

---

### Infrastructure Overview

```
DNS (Hetzner / your registrar)
  barberapp.com            → PROD_SERVER_IP
  *.barberapp.com          → PROD_SERVER_IP
  staging.barberapp.com    → STAGING_SERVER_IP
  *.staging.barberapp.com  → STAGING_SERVER_IP

Each Hetzner VPS (Ubuntu 22.04/24.04)
  Nginx         — ports 80 and 443, wildcard SSL, reverse proxy
  Docker        — runs containers managed by Kamal
  PostgreSQL    — Kamal accessory container (127.0.0.1:5432)
  App container — Puma + Thruster, bound to 127.0.0.1:3000
  Solid Queue   — runs inside Puma (SOLID_QUEUE_IN_PUMA=true)
```

**Why Nginx instead of kamal-proxy?**
Kamal's built-in proxy uses Let's Encrypt's HTTP-01 challenge, which can only issue single-hostname certificates. Wildcard certificates (`*.barberapp.com`) require a DNS-01 challenge. Nginx + Certbot (with the Hetzner DNS plugin) handles this correctly.

---

### 1. Provision Two Servers

In the [Hetzner Cloud console](https://console.hetzner.cloud):

1. Create a project (e.g. `barberapp`)
2. **Staging server** — Ubuntu 22.04, type **CX11** (2 vCPU / 2 GB RAM) is enough
3. **Production server** — Ubuntu 22.04, type **CX21** (2 vCPU / 4 GB RAM) or larger
4. Add your SSH public key to both servers during creation
5. Note both public IPv4 addresses

---

### 2. Configure DNS

In your domain registrar (or Hetzner DNS console), add these A records:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `@` | `PROD_SERVER_IP` | 300 |
| A | `*` | `PROD_SERVER_IP` | 300 |
| A | `staging` | `STAGING_SERVER_IP` | 300 |
| A | `*.staging` | `STAGING_SERVER_IP` | 300 |

Wait for propagation before running Certbot (5–10 minutes for Hetzner DNS):

```bash
dig barberapp.com +short                # → PROD_SERVER_IP
dig demo.barberapp.com +short           # → PROD_SERVER_IP
dig staging.barberapp.com +short        # → STAGING_SERVER_IP
dig demo.staging.barberapp.com +short   # → STAGING_SERVER_IP
```

---

### 3. Run the Server Setup Script

Run `script/server_setup.sh` **on each server separately**. The script:

- Creates a `deploy` user (Kamal SSHes in as this user)
- Installs Docker CE
- Installs Nginx
- Installs Certbot with the Hetzner DNS plugin
- Obtains a wildcard Let's Encrypt certificate
- Installs the correct Nginx site config
- Schedules automatic cert renewal (twice daily via cron)

**Before running**, edit `script/server_setup.sh` and set the two variables at the top:

```bash
DOMAIN="barberapp.com"   # or "staging.barberapp.com" for the staging run
HETZNER_API_TOKEN=""     # create at console.hetzner.cloud → Security → API Tokens
```

**Set up the staging server** (use `DOMAIN=staging.barberapp.com` and the staging Nginx config):

```bash
scp script/server_setup.sh root@STAGING_SERVER_IP:/root/
scp config/nginx/barberapp-staging.conf root@STAGING_SERVER_IP:/root/barberapp.conf

# Edit DOMAIN and HETZNER_API_TOKEN inside the script first, then:
ssh root@STAGING_SERVER_IP "bash /root/server_setup.sh"
```

**Set up the production server** (use `DOMAIN=barberapp.com` and the production Nginx config):

```bash
scp script/server_setup.sh root@PROD_SERVER_IP:/root/
scp config/nginx/barberapp.conf root@PROD_SERVER_IP:/root/barberapp.conf

# Edit DOMAIN and HETZNER_API_TOKEN inside the script first, then:
ssh root@PROD_SERVER_IP "bash /root/server_setup.sh"
```

Verify Nginx is serving HTTPS on both servers after setup:

```bash
curl -I https://staging.barberapp.com   # HTTP/2 200 (or 502 until app is deployed)
curl -I https://barberapp.com           # HTTP/2 200 (or 502 until app is deployed)
```

---

### 4. Configure deploy.yml Files

Open `config/deploy.yml` (production) and replace the placeholders:

```yaml
image: YOUR_DOCKERHUB_USERNAME/barberapp   # ← your Docker Hub username
servers:
  web:
    hosts:
      - PROD_SERVER_IP                     # ← production server IPv4
accessories:
  db:
    host: PROD_SERVER_IP                   # ← same IP
env:
  clear:
    APP_HOST: barberapp.com                # ← your production domain
```

Open `config/deploy.staging.yml` and replace the placeholders:

```yaml
servers:
  web:
    hosts:
      - STAGING_SERVER_IP                  # ← staging server IPv4
accessories:
  db:
    host: STAGING_SERVER_IP               # ← same IP
env:
  clear:
    APP_HOST: staging.barberapp.com       # ← your staging domain
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
export STAGING_DATABASE_URL="postgresql://barberapp:strong_staging_password@127.0.0.1:5432/barberapp_staging"
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
1. SSH into the staging server as `deploy`
2. Install Docker (if absent)
3. Start kamal-proxy and the PostgreSQL accessory
4. Build and push the Docker image
5. Pull and start the app container
6. Run `bin/rails db:migrate`

Verify staging is working:

```bash
kamal logs -d staging
kamal app exec -d staging "bin/rails runner 'puts Salon.count'"
```

Then stop kamal-proxy on the staging server (Nginx is the proxy):

```bash
kamal proxy stop -d staging
```

Visit `https://staging.barberapp.com` — you should see the BarberApp homepage.

---

### 7. First Deploy — Production

Once staging is confirmed working, deploy to production:

```bash
source ~/.barberapp_prod_secrets

kamal setup
```

Verify production:

```bash
kamal logs
kamal app exec "bin/rails runner 'puts Salon.count'"
```

Stop kamal-proxy on the production server:

```bash
kamal proxy stop
```

Visit `https://barberapp.com`.

> **Note:** Every time you run `kamal setup` on a fresh server it restarts kamal-proxy. Run `kamal proxy stop` (or `kamal proxy stop -d staging`) again afterwards. Routine `kamal deploy` updates do not restart kamal-proxy.

---

### 8. Stop kamal-proxy on Both Servers

After any fresh `kamal setup`, stop kamal-proxy before Nginx can take over:

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
# ... test on staging.barberapp.com ...
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

# Nginx access logs on the server
ssh deploy@PROD_SERVER_IP    "sudo tail -f /var/log/nginx/access.log"
ssh deploy@STAGING_SERVER_IP "sudo tail -f /var/log/nginx/access.log"

# Renew SSL certificate manually (auto-renewal runs via cron)
ssh deploy@PROD_SERVER_IP    "sudo certbot renew && sudo systemctl reload nginx"
ssh deploy@STAGING_SERVER_IP "sudo certbot renew && sudo systemctl reload nginx"
```

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
| `barberapp.com` | Marketing homepage |
| `barberapp.com/register` | New salon registration |
| `[subdomain].barberapp.com` | Salon dashboard (requires staff login) |
| `[subdomain].barberapp.com/customers` | Customer list |
| `[subdomain].barberapp.com/visits` | Visit history |
| `[subdomain].barberapp.com/appointments` | Appointment list |
| `[subdomain].barberapp.com/book` | Public customer self-booking (no login) |
| `[subdomain].barberapp.com/scan/:qr_token` | QR code scan endpoint (no login) |
| `[subdomain].barberapp.com/services` | Services catalogue |
| `[subdomain].barberapp.com/expenses` | Expense log |
| `[subdomain].barberapp.com/reports` | Monthly P&L report |
| `[subdomain].barberapp.com/reports/services` | Service profitability |
| `[subdomain].barberapp.com/reports/discounts` | Discount analysis |
| `[subdomain].barberapp.com/working_hours` | Working hours (owner only) |
| `[subdomain].barberapp.com/staffs` | Team management (owner only) |
| `[subdomain].barberapp.com/settings` | Salon settings (owner only) |
