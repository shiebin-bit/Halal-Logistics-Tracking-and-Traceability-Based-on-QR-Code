<p align="center">
  <img src="frontend/halal_traceability_app/assets/images/logo.png" alt="HalalTrack Logo" width="120">
</p>

<h1 align="center">HalalTrack</h1>

<p align="center">
  A multi-role halal logistics and traceability platform for batch verification, cold-chain events, approval workflows, and public consumer transparency.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Laravel-12-FF2D20?style=for-the-badge&logo=laravel&logoColor=white" alt="Laravel 12">
  <img src="https://img.shields.io/badge/Flutter-Mobile%20App-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions">
</p>

## Why This Project Exists

HalalTrack is built to make halal supply chain handling easier to verify, easier to audit, and easier to present. It combines a Laravel backend, a Flutter mobile app, public traceability access, and Docker-based infrastructure into one workflow-driven system.

Instead of treating traceability as a static record, the platform captures actual batch movement, role ownership, checkpoint submissions, incident reporting, and certificate governance across the supply chain.

## What It Covers

- Multi-role access for `admin`, `processor`, `logistics`, `retailer`, and `consumer`
- Backend-generated QR traceability for halal product batches
- Public consumer lookup with sanitized batch visibility
- Batch lifecycle management with certificate metadata and manifest export
- Logistics checkpoint verification with temperature, notes, and signatures
- Checkpoint-based route map rendering on real OpenStreetMap tiles for consumer, admin, and logistics views
- Lightweight admin reporting snapshot and certificate governance summary views
- Gemini-powered role assistant for `processor`, `logistics`, and `retailer` through a Laravel backend proxy
- Brevo-backed SMTP email delivery for production-style demo mail flows
- Retailer acceptance and rejection workflow
- Admin approval flow for partner onboarding and certificate control
- Dockerized backend runtime for local development and production deployment
- GitHub Actions CI for backend tests, frontend checks, and Docker image build
- GHCR-ready backend image publishing and VPS deployment workflow scaffolding

## Role Snapshot

| Role | Main Responsibility |
| --- | --- |
| `admin` | approve users, review pending registrations, view platform stats, govern certificates |
| `processor` | create batches, attach halal certificate details, manage processor inventory |
| `logistics` | scan QR batches, submit checkpoints, report incidents, update custody trail |
| `retailer` | receive assigned shipments, accept or reject delivery handoff |
| `consumer` | verify public batch traceability without login |

## Stack

### Backend

- Laravel 12
- Laravel Sanctum
- MariaDB
- DOMPDF

### Frontend

- Flutter
- Dart

### Infrastructure

- Docker
- Docker Compose
- Nginx
- Cloudflare Tunnel for current public demo access
- Brevo SMTP for email delivery
- GitHub Actions
- GitHub Container Registry
- Docker Hub for optional manual backend image publishing

## Architecture

```text
Flutter App / Browser
        |
        v
     Nginx
        |
        v
 Laravel API
        |
        v
    MariaDB
```

Repository layout:

```text
FYP_project/
├── .github/
│   └── workflows/
├── backend/
│   └── halal_traceability_api/
├── deploy/
│   ├── compose/
│   └── README.md
├── frontend/
│   └── halal_traceability_app/
├── documentation/
│   ├── database/
│   ├── deployment/
│   ├── proposals/
│   ├── reports/
│   └── README.md
├── docker-compose.yml
└── docker-compose.dev.yml
```

## Current State

The project is already in a strong demo-ready state.

Implemented:

- role-based backend authorization
- partner approval workflow before login
- registration document handling
- public batch traceability view
- real checkpoint-based timeline rendering
- checkpoint-based route map rendering using OpenStreetMap tiles
- lightweight admin reporting and certificate governance views
- drawer-based Gemini role assistant for `processor`, `logistics`, and `retailer`
- current-screen plus current-month AI context summaries through the backend proxy
- Brevo SMTP configuration and live email smoke test
- Cloudflare Tunnel public API domain for phone/demo testing
- hardened backend Docker image build that excludes `.env`, logs, cache, and uploaded runtime files
- manifest PDF export
- QR payload parsing across app flows
- Dockerized local backend stack
- backend CI, frontend CI, backend image build, and CD scaffolding

Still production-facing work:

- move from local Cloudflare Tunnel demo hosting to VPS deployment when ready
- finalize VPS deployment secrets and runtime configuration
- harden or remove demo-only shortcuts before real release

Important scope note:

- the current map is a real geographic map based on stored checkpoint coordinates
- it does not require Google Maps API keys
- it is not continuous live GPS streaming; route updates happen when checkpoints are submitted

Detailed status:

- [AI Assistant And System Verification Report](documentation/reports/ai_assistant_and_system_verification_report.md)
- [Current Improvement Roadmap](documentation/reports/current_improvement_roadmap.md)
- [Requirements Completion Report](documentation/reports/requirements_completion_report.md)

## Quick Start

### 1. Run the Backend Locally

From the repository root:

```powershell
docker compose up -d --build
docker exec halaltrack_app php artisan migrate --force
```

For day-to-day backend code refresh without resetting the database:

```powershell
docker compose up -d --build app nginx
```

Local services:

- API: `http://127.0.0.1:8000`
- MariaDB host port: `3308`

Current public demo API through Cloudflare Tunnel:

- API origin: `https://halaltrack.shiebindev.com`
- Public batches endpoint: `https://halaltrack.shiebindev.com/api/public/batches`

Seed note:

- `documentation/database/halaltrack_db.sql` is the Docker initialization dump for fresh MariaDB volumes
- it includes map-friendly demo data for `ali@processor.com`, `driver@logistics.com`, `manager@retailer.com`, and `admin@halalchain.my`
- if a database volume already exists, editing the SQL file alone will not update the running database until you recreate the volume or patch the live DB

Optional bind-mount development mode:

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

### 2. Run the Flutter App

From `frontend/halal_traceability_app`:

```powershell
flutter pub get
flutter run
```

Android emulator API origin defaults to:

```text
http://10.0.2.2:8000
```

## Testing

Backend:

```powershell
cd backend/halal_traceability_api
php artisan test
```

Frontend:

```powershell
cd frontend/halal_traceability_app
flutter analyze
flutter test
```

Current local validation completed in this repository:

- backend `php artisan test` passes
- frontend `flutter analyze` passes
- frontend `flutter test` passes
- backend Docker image builds successfully
- backend Docker image has been hardened so committed images do not include the real `.env`, logs, cache, or uploaded storage files
- live Docker backend, database, and seeded role flows have been smoke-tested successfully
- live Gemini assistant proxy flow has been smoke-tested successfully
- live Brevo SMTP delivery has been smoke-tested successfully

Business logic status:

- the core multi-role demo flows are implemented and locally runnable
- the remaining incomplete items are production-facing infrastructure and rollout items, not the main FYP business workflows

## CI/CD

Current GitHub Actions workflows:

- [backend-ci.yml](.github/workflows/backend-ci.yml)
  Backend tests, Docker image build, Trivy SARIF/report artifact generation, and GHCR push on `main`
- [frontend-ci.yml](.github/workflows/frontend-ci.yml)
  Flutter analyze and test
- [cd.yml](.github/workflows/cd.yml)
  VPS deployment workflow template over SSH using GHCR images

Production deployment assets:

- [deploy/compose/docker-compose.prod.yml](deploy/compose/docker-compose.prod.yml)
- [deploy/README.md](deploy/README.md)

Image publishing note:

- CI publishes the backend image to GHCR.
- Docker Hub can also be used manually by tagging the local image, for example `docker tag fyp_project-app:latest shiebin/fyp_project-app:latest`.
- The backend image should receive secrets only at runtime through `.env`, Docker Compose `env_file`, VPS environment files, or CI/CD secrets.

## Demo Accounts

Local demo accounts available for presentation:

- `admin@halalchain.my`
- `ali@processor.com`
- `driver@logistics.com`
- `manager@retailer.com`

Notes:

- public consumer traceability does not require login
- the seeded demo database includes checkpoint-rich shipment routes for the main demo accounts above
- local demo mode still includes limited shortcuts for testing speed
- production rollout should tighten or remove those bypasses

## Documentation

- [AI Assistant And System Verification Report](documentation/reports/ai_assistant_and_system_verification_report.md)
- [Enterprise System Explanation Report](documentation/reports/halaltrack_enterprise_report.md)
- [Documentation Index](documentation/README.md)
- [Deployment Guide](documentation/deployment/vps_docker_nginx_github_actions_deployment_guide.md)
- [Requirements Completion Report](documentation/reports/requirements_completion_report.md)
- [System Fix Log and Readiness Review](documentation/reports/system_fix_log_and_readiness_review.md)
- [Production Readiness Security Audit](documentation/reports/production_readiness_security_audit.md)
- [Live Shipment Map Proposal](documentation/proposals/live_shipment_map_proposal.md)

## Notes

- Local backend runtime is Docker-based.
- Frontend development does not require Docker.
- The current public demo can run through Cloudflare Tunnel; the planned production-style deployment remains VPS plus Docker Compose.
- Production deployment is designed around GHCR image pull plus remote Docker Compose, with optional Docker Hub publishing for demonstration.
- Sensitive values such as production `.env`, Brevo SMTP keys, Gemini API keys, VPS SSH keys, and registry credentials should never be committed.
