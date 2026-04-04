# HalalTrack Enterprise System Explanation Report

Prepared on: 2026-04-04  
Repository: `E:\xampp\htdocs\FYP_project`

## 1. Executive Summary

HalalTrack is a multi-role halal supply chain and cold-chain traceability platform built for degree-level final year project delivery, but structured using patterns that resemble a small enterprise application. The system combines a Laravel 12 REST API, a Flutter mobile client, Dockerized local runtime, and a documentation/deployment layer that supports both local demonstration and future production rollout.

The core business objective is to preserve trust and auditability across halal product movement from processor to logistics to retailer, while also exposing a safe public verification path for consumers. Instead of storing only static product records, the platform models the movement of each batch as a sequence of checkpoints, approvals, QR activation, incidents, retail acceptance decisions, and certificate governance events.

At the time of writing, the core functional scope is complete for demo and evaluation use. The remaining work is production-facing: VPS deployment, domain and HTTPS hardening, and real SMTP configuration.

## 2. Business Context and Problem Statement

Traditional food logistics records often fail in four areas:

1. Batch provenance is fragmented across different actors.
2. Logistics movement is not visible in a structured audit trail.
3. Retail handover and rejection logic is weak or manual.
4. Consumer verification is often reduced to static labels with limited traceability depth.

HalalTrack addresses these gaps by creating one consistent digital flow:

- `processor` creates a batch and attaches halal certificate context
- `admin` governs platform users and batch-level certificate integrity
- `logistics` records movement checkpoints and incidents
- `retailer` performs controlled handover acceptance or rejection
- `consumer` verifies only the public-safe portion of the batch history

This makes the system suitable for explaining traceability, governance, and operational control in one coherent application.

## 3. Solution Overview

HalalTrack is composed of the following major layers:

- A Laravel backend that owns authentication, authorization, validation, domain logic, QR state, traceability data, reports, and admin governance.
- A Flutter frontend that renders role-specific mobile experiences for processor, logistics, retailer, admin, and public consumer flows.
- A MariaDB database that stores users, role-specific profiles, batches, checkpoints, incidents, and access tokens.
- A Docker runtime that standardizes local backend execution and mirrors the production deployment model.
- GitHub Actions workflows that validate backend and frontend quality and prepare the backend container image for GHCR/VPS deployment.

## 4. High-Level Architecture

### 4.1 Runtime Topology

```text
Flutter App / Browser
        |
        v
     Nginx
        |
        v
 Laravel 12 API
        |
        v
    MariaDB
```

### 4.2 Repository Layout

```text
FYP_project/
├── backend/halal_traceability_api/
├── frontend/halal_traceability_app/
├── documentation/
│   ├── database/
│   ├── deployment/
│   ├── proposals/
│   └── reports/
├── deploy/
│   └── compose/
├── .github/workflows/
├── docker-compose.yml
└── docker-compose.dev.yml
```

### 4.3 Why This Architecture Was Chosen

- `Laravel 12` provides fast REST API development, built-in validation, Eloquent relationships, middleware aliasing, and clean controller organization.
- `Laravel Sanctum` is appropriate for token-based mobile authentication without needing a full OAuth server.
- `Flutter` supports one consistent UI codebase for Android-focused demo delivery and role-specific dashboards.
- `MariaDB` is a simple, widely understood relational database that fits transactional batch and checkpoint workflows.
- `Docker Compose` reduces local setup variability and aligns local and production backend topologies.
- `OpenStreetMap + flutter_map` avoids paid map dependencies and API key management, which is a practical engineering choice for an FYP scope.

## 5. Backend Architecture

## 5.1 Backend Technology Stack

- PHP 8.2
- Laravel 12
- Laravel Sanctum
- MariaDB
- Barryvdh DOMPDF
- PHPUnit

## 5.2 Request Routing and Middleware Model

Backend API routing is defined in `backend/halal_traceability_api/routes/api.php`.

The platform uses two main middleware aliases registered in `backend/halal_traceability_api/bootstrap/app.php`:

- `role`
  Enforces role-based access at route-group level.
- `token.idle`
  Expires Sanctum tokens after 15 minutes of inactivity.

This produces a layered backend protection model:

1. Route is grouped under `auth:sanctum`.
2. Idle timeout middleware validates recent token activity.
3. Role middleware narrows access by actor type.
4. Controller methods still apply record-level ownership checks.

That fourth layer is important because enterprise-style access control should not depend only on route grouping. HalalTrack also checks whether the authenticated user actually owns or is assigned to the batch they are trying to manage.

## 5.3 Main Backend Domain Modules

### Authentication and Registration

Controller: `AuthController`

Responsibilities:

- registration
- email verification code generation and dispatch
- login
- approval-aware access gating
- password reset link request
- logout

Key enterprise-style behaviors:

- partner roles (`processor`, `logistics`, `retailer`) require admin approval
- email verification must be completed before normal login
- demo accounts can bypass approval and verification using configured allowlists
- registration stores role-specific profile data and documents transactionally

### Batch Management and Public Traceability

Controller: `BatchController`

Responsibilities:

- list visible batches for authenticated users
- create batches
- update status
- generate QR payload
- expose public batch listing
- expose public batch detail with sanitized checkpoint history

This controller is the center of the traceability domain. It decides who can see which batches and controls the transition from processor-created records into QR-enabled traceability assets.

### Logistics Operations

Controller: `LogisticsController`

Responsibilities:

- assigned shipment summaries
- checkpoint submission with GPS coordinates and signature
- incident reporting
- logistics-side ownership enforcement

This controller turns the batch into a moving operational object. It updates custody, location, temperature history, and incident state during transit.

### Retailer Operations

Controller: `RetailerController`

Responsibilities:

- incoming shipment list
- retailer inventory list
- accept shipment
- reject shipment

Retailer acceptance is not a cosmetic UI action. It is a business state transition with validation rules, quality-check requirements, checkpoint creation, and incident generation on rejection.

### Admin Governance

Controller: `AdminController`

Responsibilities:

- dashboard statistics
- pending/approved/rejected user listing
- user approval and rejection
- incident monitoring
- certificate revocation

The admin module acts as the governance layer, not just a reporting layer. Certificate revocation directly changes batch public validity and halal breach state.

### Reporting

Controller: `ReportController`

Responsibilities:

- manifest PDF export
- audit log feed generated from checkpoints

This is a classic audit-support feature: the system reuses checkpoints as the primary trace log, then reshapes that data into printable and review-friendly artifacts.

## 5.4 Core Data Model

The main database entities are:

- `users`
- `processor_profiles`
- `logistics_profiles`
- `retailer_profiles`
- `batches`
- `checkpoints`
- `incidents`
- `personal_access_tokens`

### Users and Role Profiles

The `users` table stores common identity and access information:

- name
- email
- password
- role
- phone number
- approval state
- verification state
- profile image

Role-specific business attributes are intentionally moved into profile tables:

- `processor_profiles`
  company registration number, halal certificate number, expiry, factory address, certificate document
- `logistics_profiles`
  vehicle plate, driver license, vehicle type, supporting document
- `retailer_profiles`
  store name, business registration, outlet address

This separation makes the schema cleaner and avoids one very wide user table full of mostly null columns.

### Batches

The `batches` table is the business center of the application. It stores:

- batch identifier
- processor ownership
- current holder ownership
- driver assignment
- product metadata
- certificate snapshot
- QR payload/hash state
- destination and ETA
- freshness and halal status
- runtime shipment location

`current_holder_id` is especially important. It models responsibility transfer across roles and helps enforce who is allowed to act on a batch at a given moment.

### Checkpoints

The `checkpoints` table is the operational audit log. Each record can contain:

- batch reference
- acting user
- location label
- latitude and longitude
- temperature
- action type
- notes
- signature path
- timestamps

This table supports:

- logistics route visualization
- public consumer traceability
- audit log generation
- alert detection
- retailer arrival confirmation
- certificate governance side effects

### Incidents

The `incidents` table stores issue escalation events such as:

- delay
- temperature breach
- spoilage risk
- broken seal
- retail rejection

Incidents are treated as separate governance events rather than being buried only inside checkpoint notes.

## 5.5 Important Business Rules in the Backend

### Rule 1: Batch Creation Requires Certificate Context

When a processor creates a batch:

- a certificate number must exist
- a certificate expiry date must exist
- a certificate document path must exist
- expired certificates are rejected

This ensures the system does not create traceable halal batches without the minimal certification context.

### Rule 2: QR Generation Requires Valid Certificate State

QR generation is blocked unless the batch has a valid certificate snapshot. This prevents public verification from being activated for incomplete or invalid batches.

### Rule 3: Public Verification Is Conditional

The public API only exposes batches that:

- have an active QR
- are not revoked

Sensitive internal actor details are not exposed through the public endpoints.

### Rule 4: Logistics Cannot Record Checkpoints Arbitrarily

Logistics actions require:

- active QR
- non-delivered, non-rejected state
- batch assigned to the driver, held by the driver, or currently handing over from processor to logistics

This prevents unauthorized logistics accounts from modifying unrelated shipments.

### Rule 5: Retail Acceptance Requires Quality Checks

Retail acceptance only succeeds if all mandatory checks are true:

- packaging intact
- temperature check
- halal certificate present
- quantity match
- expiry valid

The batch also cannot have unresolved incidents at acceptance time.

### Rule 6: Certificate Revocation Is a Hard Governance Event

When admin revokes a certificate:

- `qr_revoked_at` is set
- batch status becomes `Invalid - Certificate Revoked`
- halal status becomes `breached`
- a checkpoint is written for audit continuity

This is important because certificate governance is directly connected to public trust and traceability access.

## 6. Frontend Architecture

## 6.1 Frontend Technology Stack

- Flutter
- Dart
- `http`
- `mobile_scanner`
- `geolocator`
- `flutter_secure_storage`
- `flutter_map`
- `latlong2`
- `signature`
- `open_file`
- `url_launcher`

## 6.2 Frontend Role Model

The Flutter application routes users into role-specific dashboards:

- admin dashboard
- processor dashboard
- logistics dashboard
- retailer dashboard
- consumer/public traceability flows

This is useful because the backend is role-driven and the frontend mirrors the same operational separation.

## 6.3 Frontend Service Responsibilities

Important frontend service modules include:

- `auth_session_service`
  token persistence and session retrieval
- `location_service`
  current GPS capture for logistics
- `profile_image_service`
  image URL normalization and cache-friendly refresh handling
- `qr_payload_service`
  QR payload decoding and batch identifier extraction
- `batch_route_mapper`
  maps checkpoint payloads into route-friendly UI models

## 6.4 Map Design Decision

The current route map is:

- a real geographic map
- rendered on OpenStreetMap tiles
- based on saved checkpoint coordinates
- visible in consumer, admin, and logistics detail views

The current route map is not:

- continuous live GPS streaming
- a websocket tracker
- a Google Maps API integration

This is a deliberate scope decision. For an FYP, checkpoint-based route visualization gives strong demonstration value without the complexity of continuous background tracking, streaming infrastructure, or commercial map billing.

## 7. End-to-End Business Flows

## 7.1 Partner Registration and Approval Flow

Actors:

- processor
- logistics
- retailer
- admin

Flow:

1. User submits registration.
2. Backend validates role-specific fields and uploaded documents.
3. Backend creates base user plus role-specific profile in one transaction.
4. Email verification code is generated.
5. User verifies email.
6. Admin reviews and approves or rejects the account.
7. Approved user logs in and receives a Sanctum token.

Why this matters:

- it separates identity verification from business approval
- it creates a more realistic enterprise onboarding model
- it allows admin governance before privileged operations begin

## 7.2 Processor Batch Creation and QR Activation

Actors:

- processor
- optional admin

Flow:

1. Processor creates a batch with product and source details.
2. Backend resolves certificate snapshot from request data or processor profile defaults.
3. Batch is stored with `current_holder_id = processor`.
4. System writes an initial checkpoint (`Batch created in system`).
5. Processor or admin generates a secure QR payload.
6. Batch moves to `QR Generated` state.
7. Public verification becomes possible once QR is active and not revoked.

Why this matters:

- it binds halal certificate state to the traceability object
- it creates a public-safe verification layer
- it produces a machine-readable batch identity for later logistics and consumer flows

## 7.3 Logistics Transit Flow

Actors:

- logistics

Flow:

1. Logistics views assigned routes.
2. Driver scans or selects a batch with active QR.
3. App acquires current GPS position.
4. Driver submits checkpoint with:
   - batch ID
   - location
   - latitude
   - longitude
   - temperature
   - notes
   - signature
5. Backend updates batch:
   - status to `In Transit`
   - current holder to logistics
   - driver assignment
   - current location
   - truck plate from logistics profile
6. Backend stores checkpoint.
7. Route map and audit history update from checkpoint data.

If an issue occurs:

1. Driver reports incident.
2. Backend writes an incident record.
3. Backend also writes an incident-style checkpoint for route history continuity.

Why this matters:

- checkpoint submission is the main source of route intelligence
- the map, audit log, and temperature visibility all depend on this layer

## 7.4 Retailer Acceptance and Rejection Flow

Actors:

- retailer

Acceptance flow:

1. Retailer opens incoming shipment list.
2. Retailer selects a batch assigned to or matching the retailer destination.
3. Retailer completes mandatory quality checks.
4. Backend verifies active QR and absence of unresolved incidents.
5. Batch status becomes `Delivered`.
6. Ownership changes to retailer.
7. Arrival checkpoint is written.

Rejection flow:

1. Retailer opens shipment.
2. Retailer enters rejection reason and arrival temperature.
3. Backend marks batch as `Rejected`.
4. Backend changes halal status to `investigation`.
5. Incident record is created.
6. Arrival checkpoint is still written to preserve the event trace.

Why this matters:

- the system treats retailer acceptance as a controlled handover, not a simple status toggle
- rejection is preserved as a governed exception path

## 7.5 Admin Governance and Reporting Flow

Actors:

- admin

Flow:

1. Admin opens dashboard statistics.
2. Admin reviews:
   - total batches
   - pending users
   - active issues
   - status breakdown
   - certificate summary
3. Admin can approve or reject registrations.
4. Admin can inspect incidents.
5. Admin can revoke a batch certificate.
6. Admin can view batch details, route maps, checkpoint timelines, and certificate governance summaries.

Why this matters:

- it demonstrates oversight, not just operations
- it lets the project show governance and trust controls in addition to normal logistics flow

## 7.6 Consumer Public Verification Flow

Actors:

- consumer

Flow:

1. Consumer searches or scans a batch using the public endpoint path.
2. Backend checks whether the batch still has an active public QR state.
3. Backend returns only sanitized batch metadata plus public-safe checkpoint history.
4. Frontend renders:
   - batch overview
   - status
   - freshness
   - certificate summary
   - route/timeline derived from checkpoints

Why this matters:

- public trust is a visible outcome of the internal workflow
- consumers do not need privileged access to benefit from the traceability system

## 8. API Catalogue

## 8.1 Public Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/register` | create a new account and role-specific profile |
| `POST` | `/api/login` | authenticate and issue Sanctum token |
| `POST` | `/api/forgot-password` | request password reset email |
| `POST` | `/api/verify-email-code` | verify email using six-digit code |
| `POST` | `/api/resend-email-code` | resend email verification code |
| `GET` | `/api/public/batches` | public paginated batch search |
| `GET` | `/api/public/batches/{batchId}` | public-safe batch detail and checkpoint history |

## 8.2 Authenticated Common Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/logout` | revoke current token |
| `GET` | `/api/user` | fetch current profile with role relation |
| `POST` | `/api/user/update` | update profile and role-specific fields |
| `GET` | `/api/batches` | list visible batches for authenticated user |
| `GET` | `/api/batches/{id}` | batch detail within role visibility |
| `GET` | `/api/reports/manifest` | download manifest PDF |
| `GET` | `/api/reports/audit-logs` | get recent checkpoint-based audit log |

## 8.3 Processor Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/batches` | create a new batch |
| `POST` | `/api/batches/update-status` | update processor-managed batch status |
| `POST` | `/api/batches/{id}/generate-qr` | generate secure QR for a batch |

## 8.4 Logistics Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/api/logistics/routes` | shipment summary cards for logistics dashboard |
| `POST` | `/api/logistics/checkpoint` | record checkpoint with GPS and signature |
| `POST` | `/api/logistics/incident` | report logistics incident |

## 8.5 Admin Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/api/admin/stats` | dashboard stats and reporting breakdowns |
| `GET` | `/api/admin/users` | user list with approval status filtering |
| `POST` | `/api/admin/approve/{id}` | approve account |
| `POST` | `/api/admin/reject/{id}` | reject account |
| `GET` | `/api/admin/incidents` | incident monitoring feed |
| `POST` | `/api/admin/batches/{id}/revoke-certificate` | revoke certificate and public validity |
| `POST` | `/api/admin/batches/{id}/generate-qr` | admin-side QR generation |

## 8.6 Retailer Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/api/retailer/incoming` | inbound shipment list |
| `GET` | `/api/retailer/inventory` | delivered inventory list |
| `POST` | `/api/retailer/accept` | accept shipment with quality checks |
| `POST` | `/api/retailer/reject` | reject shipment and open issue workflow |

## 9. Configuration and Runtime Model

## 9.1 Local Docker Runtime

The root `docker-compose.yml` defines:

- `app`
  Laravel PHP-FPM container
- `nginx`
  public HTTP entrypoint on port `8000`
- `db`
  MariaDB on host port `3308`

Important behavior:

- `documentation/database/halaltrack_db.sql` is mounted as the MariaDB initialization script for fresh volumes
- storage is persisted via Docker volume for database data
- backend code is built into the image by default

Standard local startup:

```powershell
docker compose up -d --build
docker exec halaltrack_app php artisan migrate --force
```

Code-only refresh without resetting database state:

```powershell
docker compose up -d --build app nginx
```

## 9.2 Optional Bind-Mount Development Mode

`docker-compose.dev.yml` bind-mounts the backend source into `/var/www`. This is useful when rapid backend iteration is preferred over image rebuilds.

## 9.3 Production Compose Model

`deploy/compose/docker-compose.prod.yml` uses:

- prebuilt backend image from GHCR
- separate named volumes for public files, storage, logs, and database
- environment values from a production `.env`

This is a cleaner enterprise-style production model than mounting the local source tree directly.

## 9.4 Nginx Configuration

The Nginx layer:

- serves `/var/www/public`
- forwards PHP requests to `app:9000`
- denies `.ht*` access
- uses `try_files` fallback to Laravel front controller

This keeps the HTTP layer minimal and conventional.

## 9.5 Frontend API Configuration

The Flutter app centralizes API origin handling in `frontend/halal_traceability_app/lib/config.dart`.

Behavior:

- web defaults to `http://127.0.0.1:8000`
- Android emulator defaults to `http://10.0.2.2:8000`
- production or device builds should pass `--dart-define=API_ORIGIN=...`

This separation is important because emulator networking and real-device networking are not the same.

## 9.6 Email and SMTP Configuration

Mail configuration currently defaults to:

- `MAIL_MAILER=log`

This is appropriate for local development because verification flows still work through:

- debug-exposed verification code in local/testing environments
- log-based or fallback mail handling

For production, the following must be set to real values:

- `MAIL_MAILER`
- `MAIL_SCHEME`
- `MAIL_HOST`
- `MAIL_PORT`
- `MAIL_USERNAME`
- `MAIL_PASSWORD`
- `MAIL_FROM_ADDRESS`
- `MAIL_FROM_NAME`

## 9.7 Demo Access Configuration

The backend supports a configured demo access list using `DEMO_ACCESS_EMAILS`.

Current demo-oriented behavior:

- bypass email verification for demo access accounts
- bypass admin approval checks for demo access accounts

This is useful for FYP demonstration speed, but it should be hardened or removed in a real production rollout.

## 10. CI/CD and Delivery Pipeline

## 10.1 Backend CI

Workflow: `.github/workflows/backend-ci.yml`

Pipeline:

1. checkout repository
2. install PHP 8.2 with required extensions
3. install Composer dependencies
4. prepare testing environment
5. run backend tests
6. build backend Docker image
7. push to GHCR on `main`

## 10.2 Frontend CI

Workflow: `.github/workflows/frontend-ci.yml`

Pipeline:

1. checkout repository
2. install Flutter
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test`

## 10.3 CD Workflow

Workflow: `.github/workflows/cd.yml`

Planned production path:

1. resolve image tag
2. SSH into VPS
3. login to GHCR
4. pull backend image
5. run production compose update
6. optionally run migrations once VPS environment is confirmed stable

This means the project already has a credible deployment story even though the final VPS is not yet in place.

## 11. Security and Control Design

The system includes several practical control mechanisms:

- token-based API authentication with Sanctum
- idle session invalidation after inactivity
- route-level role middleware
- record-level authorization inside controllers
- certificate-validity checks before QR generation
- public endpoint sanitization
- retailer acceptance gating based on unresolved incidents
- certificate revocation that disables public trust state
- uploaded file storage under Laravel public disk conventions

Current limitations:

- local Docker and demo mode still use convenience settings
- SMTP is not yet production-backed
- HTTPS and domain hardening are not complete because VPS rollout is not finished

## 12. Testing and Quality Assurance

The current repository already validates core behavior through:

- backend feature tests
- backend unit tests
- frontend analyze checks
- frontend widget/service tests

Verified status at the current project stage:

- `php artisan test` passing
- `flutter analyze` passing
- `flutter test` passing

The backend tests cover important control points such as:

- admin-only access enforcement
- approval and verification gating
- batch certificate behavior
- QR generation access
- retailer access restrictions
- logistics route detail linkage

## 13. Current Completion Status

From an FYP delivery perspective, the system is functionally complete in its core scope.

Completed:

- multi-role registration and login
- admin approval governance
- processor batch creation
- certificate snapshot enforcement
- QR traceability activation
- logistics checkpoint submission
- incident reporting
- retailer accept/reject workflow
- consumer public verification
- route maps for consumer, admin, and logistics views
- lightweight admin reporting
- manifest PDF export
- Dockerized backend runtime
- CI/CD scaffolding
- demo-ready seeded data for primary presentation accounts

Remaining production-facing tasks:

- purchase and configure VPS
- deploy production stack on VPS
- configure real SMTP and domain mail records
- finalize production `.env`, HTTPS, and runtime secrets
- perform final live-environment validation after deployment

## 14. Why the Current Design Is Appropriate for This Project

This design is appropriate because it balances realism and scope discipline.

What was done well:

- real business roles instead of a single-user demo
- real audit trail through checkpoints
- real route visualization on geographic maps
- real admin governance over onboarding and certificates
- real deployment pathway using containers and CI/CD

What was intentionally not overbuilt:

- no full live GPS streaming platform
- no websocket location bus
- no heavy analytics engine
- no enterprise IAM platform
- no production cloud infrastructure yet

That tradeoff is reasonable. It shows engineering judgment rather than unnecessary complexity.

## 15. Conclusion

HalalTrack is a structured supply chain traceability application that demonstrates identity control, batch governance, movement auditing, retail handover validation, and public transparency within one coherent platform.

Its backend is the strongest architectural layer: it enforces the business rules, controls state transitions, separates public and private data exposure, and anchors all user-facing features in a traceable domain model. The Flutter frontend then translates those governed backend workflows into role-specific operational dashboards.

In summary:

- the app is functionally complete for academic demo and evaluation
- the architecture is consistent and explainable
- the backend business logic is substantial and well-structured
- the remaining work is deployment and production mail integration, not missing core system logic
