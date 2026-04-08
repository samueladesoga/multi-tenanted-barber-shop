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
  - [Infrastructure Overview](#infrastructure-overview)
  - [1. Provision the Server](#1-provision-the-server)
  - [2. Configure DNS](#2-configure-dns)
  - [3. Run the Server Setup Script](#3-run-the-server-setup-script)
  - [4. Configure Secrets](#4-configure-secrets)
  - [5. Edit deploy.yml](#5-edit-deployyml)
  - [6. Build and Push the Docker Image](#6-build-and-push-the-docker-image)
  - [7. First Deploy](#7-first-deploy)
  - [8. Stop kamal-proxy](#8-stop-kamal-proxy)
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

### Infrastructure Overview

```
DNS (Hetzner / your registrar)
  barberapp.com          → YOUR_SERVER_IP
  *.barberapp.com        → YOUR_SERVER_IP

Hetzner VPS (Ubuntu 22.04/24.04, CX21 or larger)
  Nginx        — ports 80 and 443, wildcard SSL, reverse proxy
  Docker       — runs containers managed by Kamal
  PostgreSQL   — Kamal accessory container (127.0.0.1:5432)
  App container — Puma + Thruster, bound to 127.0.0.1:3000
  Solid Queue  — runs inside Puma (SOLID_QUEUE_IN_PUMA=true)
```

**Why Nginx instead of kamal-proxy?**
Kamal's built-in proxy (kamal-proxy) uses Let's Encrypt's HTTP-01 challenge, which only issues certificates for specific hostnames. Wildcard certificates (`*.barberapp.com`) require a DNS-01 challenge. Nginx + Certbot (with the Hetzner DNS plugin) handles this correctly.

---

### 1. Provision the Server

In the Hetzner Cloud console:

1. Create a new project (e.g. `barberapp`)
2. Add a server: **Ubuntu 22.04**, type **CX21** (2 vCPU / 4 GB RAM) or larger
3. Add your SSH public key during creation (you will log in as `root`)
4. Note the server's public IPv4 address

---

### 2. Configure DNS

In your domain registrar (or Hetzner DNS console), add these records. Replace `YOUR_SERVER_IP` with the VPS IPv4:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `@` (or `barberapp.com`) | `YOUR_SERVER_IP` | 300 |
| A | `*` | `YOUR_SERVER_IP` | 300 |

The wildcard `*` record routes every tenant subdomain to the same server. TTL 300 (5 minutes) is fine for initial setup; raise it to 3600 once everything is working.

Wait for DNS propagation before running Certbot (typically 5–10 minutes for Hetzner DNS):

```bash
dig barberapp.com +short        # should return YOUR_SERVER_IP
dig demo.barberapp.com +short   # should return YOUR_SERVER_IP
```

---

### 3. Run the Server Setup Script

The script `script/server_setup.sh` automates the entire server bootstrap:

- Creates a `deploy` user with passwordless Docker access (Kamal uses this account)
- Installs Docker CE
- Installs Nginx
- Installs Certbot with the Hetzner DNS plugin
- Obtains a wildcard Let's Encrypt certificate for `barberapp.com` and `*.barberapp.com`
- Installs the Nginx site config from this repo
- Sets up automatic cert renewal (cron, twice daily)

**Before running**, open `script/server_setup.sh` and fill in:

```bash
DOMAIN="barberapp.com"       # your actual domain
HETZNER_API_TOKEN=""         # your Hetzner API token (create one at console.hetzner.cloud → Security → API Tokens)
```

Also update the Nginx config if your domain differs from `barberapp.com`:

```bash
# config/nginx/barberapp.conf — replace all occurrences of barberapp.com
```

Now copy and run:

```bash
# From your local machine:
scp script/server_setup.sh root@YOUR_SERVER_IP:/root/
scp config/nginx/barberapp.conf root@YOUR_SERVER_IP:/root/

ssh root@YOUR_SERVER_IP "bash /root/server_setup.sh"
```

When the script finishes you should see Nginx running on port 443 with a valid wildcard certificate:

```bash
curl -I https://barberapp.com       # HTTP/2 200
curl -I https://demo.barberapp.com  # HTTP/2 200 (once the app is deployed)
```

---

### 4. Configure Secrets

All secrets are pulled from your shell environment at deploy time. The file `.kamal/secrets` references shell variables — **it does not store values**, so it is safe to commit.

Set the following environment variables on your **local machine** before deploying (add them to `~/.zshrc` or a sourced secrets file):

```bash
# Docker Hub credentials
export KAMAL_REGISTRY_PASSWORD="your_dockerhub_access_token"

# PostgreSQL — must match what the accessory container uses
export POSTGRES_PASSWORD="choose_a_strong_password"
export DATABASE_URL="postgresql://barberapp:choose_a_strong_password@127.0.0.1:5432/barberapp_production"

# Twilio SMS (leave blank to disable — SmsService will log instead)
export TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export TWILIO_AUTH_TOKEN="your_auth_token"
export TWILIO_FROM="+1234567890"

# SMTP — any transactional provider (Postmark, Mailgun, SendGrid, etc.)
export SMTP_ADDRESS="smtp.postmarkapp.com"
export SMTP_USERNAME="your_smtp_username"
export SMTP_PASSWORD="your_smtp_password"
```

The `RAILS_MASTER_KEY` is read directly from `config/master.key` (see `.kamal/secrets`). **Never commit `config/master.key`** — it must exist on the machine you deploy from.

---

### 5. Edit deploy.yml

Open `config/deploy.yml` and replace the two placeholder values:

```yaml
image: YOUR_DOCKERHUB_USERNAME/barberapp   # ← your Docker Hub username
servers:
  web:
    hosts:
      - YOUR_SERVER_IP                     # ← your Hetzner VPS IPv4
accessories:
  db:
    host: YOUR_SERVER_IP                   # ← same IP
```

If you do not have a Docker Hub account, create a free one at [hub.docker.com](https://hub.docker.com) and create a repository named `barberapp`.

---

### 6. Build and Push the Docker Image

Kamal builds the image locally (or on the server) and pushes it to Docker Hub. The Dockerfile targets `amd64` (Hetzner VPS architecture). If you are on Apple Silicon:

```bash
# Ensure Docker Desktop is running with Rosetta / multi-platform support, OR
# let Kamal build remotely on the server:
# In config/deploy.yml, uncomment:
#   builder:
#     remote: ssh://deploy@YOUR_SERVER_IP
```

Build is handled automatically by `kamal deploy` — no manual step needed.

---

### 7. First Deploy

Run the full setup from your local machine:

```bash
kamal setup
```

`kamal setup` does the following in order:
1. SSHes into the server as `deploy`
2. Installs Docker on the server (if not already present)
3. Pulls and starts the **kamal-proxy** container
4. Starts the **PostgreSQL accessory** container
5. Builds your app Docker image locally (or remotely)
6. Pushes it to Docker Hub
7. Pulls the image on the server and starts the app container
8. Runs `bin/rails db:migrate` as a boot hook

After it completes, verify the app is running:

```bash
kamal logs        # tail live logs
kamal app exec "bin/rails runner 'puts Salon.count'"
```

---

### 8. Stop kamal-proxy

kamal-proxy occupies port 80 on the server. Since Nginx is handling port 80 (HTTP→HTTPS redirect) and port 443 (SSL), you must stop kamal-proxy:

```bash
kamal proxy stop
```

Nginx now routes all traffic. Confirm:

```bash
curl -I https://barberapp.com
# HTTP/2 200
```

> **Note:** Every time you run `kamal setup` on a fresh server it will restart kamal-proxy. Run `kamal proxy stop` again afterwards. For routine `kamal deploy` (updates), this is not needed.

---

### 9. Subsequent Deploys

For all future deploys (code updates):

```bash
kamal deploy
```

This builds a new image, pushes it, and does a rolling restart with zero downtime. Migrations are run automatically via the deploy hook.

To roll back to the previous version:

```bash
kamal rollback
```

---

### 10. Useful Kamal Commands

```bash
# View live logs
kamal logs

# Open a Rails console on the server
kamal console

# Open a bash shell inside the running container
kamal shell

# Run a one-off Rails command
kamal app exec "bin/rails db:migrate:status"

# Run a database console
kamal dbc

# Restart the app without deploying a new image
kamal app restart

# Check container status
kamal app details

# View Nginx access logs on the server
ssh deploy@YOUR_SERVER_IP "sudo tail -f /var/log/nginx/access.log"

# Renew SSL certificate manually (auto-renewal runs via cron)
ssh deploy@YOUR_SERVER_IP "sudo certbot renew && sudo systemctl reload nginx"
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
