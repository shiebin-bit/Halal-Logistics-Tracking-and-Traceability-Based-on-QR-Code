# HalalTrack

HalalTrack is a halal logistics and traceability system built for multi-role supply chain monitoring. The project provides a Laravel REST API, a Flutter mobile app, public consumer traceability, and Docker-based local backend infrastructure.

## Project Scope

The system is designed around five user roles:

- `admin`
- `processor`
- `logistics`
- `retailer`
- `consumer`

Main capabilities:

- role-based login and dashboard access
- batch creation and halal certificate tracking
- backend-generated QR traceability
- logistics checkpoint and incident reporting
- retailer acceptance and rejection workflow
- public consumer traceability view
- admin approval and certificate governance

## Tech Stack

### Backend

- Laravel 12
- Laravel Sanctum
- MariaDB

### Frontend

- Flutter
- Dart

### Infrastructure

- Docker
- Docker Compose
- Nginx

## Repository Structure

```text
FYP_project/
├── backend/
│   └── halal_traceability_api/
├── frontend/
│   └── halal_traceability_app/
├── documentation/
├── docker-compose.yml
└── docker-compose.dev.yml
```

## Current Status

The project is in a strong demo-ready state.

Completed:

- core mandatory design requirements are largely implemented
- backend, API, and database are running correctly in Docker
- consumer public traceability is working with sanitized data
- batch-level certificate and backend QR generation are implemented
- retailer and logistics validation logic is implemented
- admin approval and revoke certificate flows are implemented
- backend regression tests are passing

Remaining production-oriented work:

- deploy to VPS / production server
- connect a real mail provider / SMTP service
- finalize CI/CD workflows
- remove or disable demo-only bypass rules for production

Detailed completion notes:

- [requirements_completion_report_2026-04-02.md](documentation/requirements_completion_report_2026-04-02.md)

## Local Development

### Backend with Docker

From the repository root:

```powershell
docker compose up -d --build
docker exec halaltrack_app php artisan migrate --force
```

Backend services:

- API: `http://127.0.0.1:8000`
- MariaDB host port: `3308`

### Frontend with Flutter

From:

```text
frontend/halal_traceability_app
```

Run:

```powershell
flutter pub get
flutter run
```

Android emulator API origin is configured to use:

```text
http://10.0.2.2:8000
```

## Demo Accounts

These demo accounts are available for local demonstration:

- `admin@halalchain.my`
- `ali@processor.com`
- `driver@logistics.com`
- `manager@retailer.com`

Note:

- public `consumer` traceability does not require login
- local demo mode currently includes limited bypass behavior for faster testing
- real production deployment should remove or disable those demo-only bypass rules

## Testing

Backend test suite:

```powershell
cd backend/halal_traceability_api
php artisan test
```

Current backend result:

- `17 passed`

## Key Documentation

- [Requirements Completion Report](documentation/requirements_completion_report_2026-04-02.md)
- [System Fix Log and Readiness Review](documentation/system_fix_log_and_readiness_review_2026-03-30.md)
- [Deployment Guide](documentation/vps_docker_nginx_github_actions_deployment_guide_2026-03-27.md)

## Notes

- Backend local runtime is Docker-based.
- Frontend does not need Docker for local development.
- CI can test backend, frontend, and Docker build independently from local setup.
- CD can later deploy the Dockerized backend to a VPS through GitHub Actions.
