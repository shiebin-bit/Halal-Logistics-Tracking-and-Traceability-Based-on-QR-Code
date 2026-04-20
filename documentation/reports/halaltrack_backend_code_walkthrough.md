# HalalTrack Backend Code Walkthrough

这份文档用 code walkthrough 的方式解释 HalalTrack 的后端。重点是让 reader 能看懂这个 Laravel backend 从 request 进入、经过 middleware/controller/service/model/database，到最后返回 API response 的完整逻辑。

Scope note:

- 这份 report 只解释 backend、API、database、Docker、CI/CD、SMTP、Gemini proxy、Cloudflare runtime connection。
- 不解释 Flutter UI、screen layout、widget structure 或 frontend state management。
- 前端在这里只被当成 API client，不作为 report 的分析对象。

## 1. Big Picture

HalalTrack backend 是一个 Laravel 12 REST API backend。它负责 halal logistics traceability system 的核心业务规则：

- user registration, email verification, login, logout
- role-based access control for `admin`, `processor`, `logistics`, `retailer`, and `consumer`
- processor batch creation and certificate validation
- backend-generated QR payload and QR revocation
- logistics checkpoint tracking with temperature, location, signature, and incident reporting
- retailer shipment receiving, acceptance, rejection, and inventory movement
- public batch lookup for QR/consumer traceability
- admin approval, certificate governance, incidents, and dashboard statistics
- PDF manifest generation
- Gemini-powered role assistant through a backend proxy
- Brevo SMTP email sending
- Dockerized local and production-style runtime

At a high level, the backend looks like this:

```text
External API Client
        |
        v
Nginx container / public domain
        |
        v
Laravel API routes
        |
        v
Sanctum auth + custom role middleware
        |
        v
Controller layer
        |
        v
Service layer / Eloquent models
        |
        v
MariaDB database + storage files
```

Current local/public demo routing:

```text
https://halaltrack.shiebindev.com
        |
        v
Cloudflare Tunnel
        |
        v
localhost:8000
        |
        v
Nginx container
        |
        v
Laravel PHP-FPM container
        |
        v
MariaDB container
```

This is not a microservice backend. It is a single Laravel backend with clear role modules. The modularity comes from:

- route groups
- controllers grouped by domain
- Eloquent models
- middleware
- service classes
- database migrations
- Docker/runtime separation

## 2. Request Flow Summary

Every API request follows this mental model:

```text
HTTP request
  -> routes/api.php
  -> optional auth:sanctum middleware
  -> optional token.idle middleware
  -> optional role middleware
  -> controller method
  -> validation
  -> model/service/database work
  -> JSON response or file download
```

Public routes such as `POST /api/login` and `GET /api/public/batches` do not require a token.

Protected routes are inside:

```php
Route::middleware(['auth:sanctum', 'token.idle'])->group(function () {
    // protected API routes
});
```

Role-specific routes use:

```php
Route::middleware('role:processor')->group(...);
Route::middleware('role:logistics')->group(...);
Route::middleware('role:admin')->group(...);
Route::middleware('role:retailer')->group(...);
```

So a protected logistics checkpoint request goes through:

```text
POST /api/logistics/checkpoint
  -> auth:sanctum checks Bearer token
  -> token.idle checks inactivity timeout
  -> role:logistics checks user role
  -> LogisticsController@submitCheckpoint
  -> request validation
  -> Batch lookup and authorization
  -> Batch status/current holder update
  -> Checkpoint creation
  -> JSON response
```

## 3. Backend Directory Structure

Main backend folder:

```text
backend/halal_traceability_api/
├── app/
│   ├── Http/
│   │   ├── Controllers/Api/
│   │   └── Middleware/
│   ├── Models/
│   ├── Providers/
│   └── Services/
├── bootstrap/
│   └── app.php
├── config/
├── database/
│   ├── migrations/
│   └── seeders/
├── docker/
│   └── nginx/
├── public/
├── resources/
│   └── views/
├── routes/
│   └── api.php
├── storage/
├── tests/
├── .dockerignore
├── Dockerfile
├── composer.json
└── phpunit.xml
```

The important backend source files are:

```text
routes/api.php
app/Http/Controllers/Api/AuthController.php
app/Http/Controllers/Api/BatchController.php
app/Http/Controllers/Api/LogisticsController.php
app/Http/Controllers/Api/RetailerController.php
app/Http/Controllers/Api/AdminController.php
app/Http/Controllers/Api/ReportController.php
app/Http/Controllers/Api/AiAssistantController.php
app/Http/Middleware/RoleMiddleware.php
app/Http/Middleware/EnsureTokenIdleTimeout.php
app/Services/GeminiRoleAssistantService.php
app/Services/RoleAssistantMonthlySummaryService.php
app/Models/User.php
app/Models/Batch.php
app/Models/Checkpoint.php
app/Models/Incident.php
```

## 4. Root And Configuration Files

### `composer.json`

`composer.json` defines the Laravel backend dependencies.

Important runtime packages:

- `laravel/framework`
- `laravel/sanctum`
- `barryvdh/laravel-dompdf`
- `laravel/tinker`

Important development/testing packages:

- `phpunit/phpunit`
- `mockery/mockery`
- `nunomaduro/collision`
- `laravel/pint`

Important Composer scripts:

```json
"test": [
  "@php artisan config:clear --ansi",
  "@php artisan test"
]
```

This means `composer test` clears configuration cache first, then runs PHPUnit/Laravel tests.

### `.env.example`

`.env.example` documents runtime variables without committing real secrets.

Important groups:

- application identity: `APP_NAME`, `APP_ENV`, `APP_DEBUG`, `APP_URL`
- database: `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- mail: `MAIL_MAILER`, `MAIL_SCHEME`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`
- Gemini: `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_API_BASE_URL`, `GEMINI_TIMEOUT_SECONDS`

For Brevo SMTP on port `587`, the correct scheme is:

```env
MAIL_MAILER=smtp
MAIL_SCHEME=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
```

The real `.env` must not be committed. It is read by Docker Compose at runtime.

### `bootstrap/app.php`

This file registers Laravel routing and middleware aliases.

Important aliases:

```php
'role' => RoleMiddleware::class,
'token.idle' => EnsureTokenIdleTimeout::class,
```

These aliases allow route definitions like:

```php
Route::middleware(['auth:sanctum', 'token.idle'])->group(...);
Route::middleware('role:admin')->group(...);
```

### `config/services.php`

This file centralizes non-core service settings:

- frontend/reset URL configuration
- email verification lifetime and debug-code behavior
- demo access account emails
- Gemini API key, model, base URL, and timeout

Important entries:

```php
'email_verification' => [
    'expires_minutes' => env('EMAIL_VERIFICATION_EXPIRES_MINUTES', 15),
    'debug_expose_code' => env('EMAIL_VERIFICATION_DEBUG_EXPOSE_CODE', true),
],

'demo_access' => [
    'emails' => ...,
],

'gemini' => [
    'api_key' => env('GEMINI_API_KEY'),
    'model' => env('GEMINI_MODEL', 'gemini-3.1-flash-lite-preview'),
    'base_url' => env('GEMINI_API_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta'),
    'timeout_seconds' => (int) env('GEMINI_TIMEOUT_SECONDS', 20),
],
```

## 5. API Route Map

The backend currently exposes 32 API routes.

### Public Routes

These do not require authentication:

```text
POST /api/register
POST /api/login
POST /api/forgot-password
POST /api/verify-email-code
POST /api/resend-email-code
GET  /api/public/batches
GET  /api/public/batches/{batchId}
```

Purpose:

- registration and login
- email verification
- password reset request
- public traceability lookup

### Authenticated Common Routes

These require a valid Sanctum token:

```text
POST /api/logout
GET  /api/user
POST /api/user/update
GET  /api/batches
GET  /api/batches/{id}
GET  /api/reports/manifest
GET  /api/reports/audit-logs
```

The exact data visible through `GET /api/batches` depends on the authenticated user role.

### Processor Routes

```text
POST /api/batches
POST /api/batches/update-status
POST /api/batches/{id}/generate-qr
```

Processors can:

- create batches
- update allowed batch statuses
- generate QR after certificate validation

### Logistics Routes

```text
GET  /api/logistics/routes
POST /api/logistics/checkpoint
POST /api/logistics/incident
```

Logistics users can:

- view assigned routes
- submit checkpoint updates
- report incident events

### Retailer Routes

```text
GET  /api/retailer/incoming
GET  /api/retailer/inventory
POST /api/retailer/accept
POST /api/retailer/reject
```

Retailers can:

- see incoming shipments matching their outlet/store profile
- see delivered inventory
- accept shipments after required quality checks
- reject shipments with a reason and incident record

### Admin Routes

```text
GET  /api/admin/stats
GET  /api/admin/users
POST /api/admin/approve/{id}
POST /api/admin/reject/{id}
GET  /api/admin/incidents
POST /api/admin/batches/{id}/revoke-certificate
POST /api/admin/batches/{id}/generate-qr
```

Admins can:

- view platform statistics
- approve/reject partner users
- monitor incidents
- revoke certificates
- regenerate QR when allowed

### AI Assistant Route

```text
POST /api/assistant/chat
```

Allowed roles:

```text
processor
logistics
retailer
```

The assistant is not public and not available to `admin` or `consumer`.

## 6. Database Model Map

The backend uses MariaDB in Docker and SQLite in-memory for automated tests.

Main tables:

```text
users
processor_profiles
logistics_profiles
retailer_profiles
batches
checkpoints
incidents
transfers
personal_access_tokens
password_reset_tokens
```

Current model relationships:

```text
User
  hasOne ProcessorProfile
  hasOne LogisticsProfile
  hasOne RetailerProfile
  hasMany Batch as current holder

Batch
  belongsTo User as processor
  belongsTo User as currentHolder
  belongsTo User as driver
  hasMany Checkpoint
  hasMany Incident through batch_id string

Checkpoint
  belongsTo Batch
  belongsTo User

Incident
  belongsTo User as reporter
```

### `User`

`User` stores identity, authentication, role, approval status, email verification fields, and profile image path.

Important fields:

- `name`
- `email`
- `password`
- `role`
- `phone_number`
- `profile_image`
- `is_approved`
- `approved_at`
- `registration_status`
- `email_verified_at`
- `email_verification_code`
- `email_verification_expires_at`

Important methods:

- `isDemoAccessAccount()`
- `bypassesEmailVerification()`
- `bypassesApprovalChecks()`
- `ensureBypassAccessState()`
- profile image normalization getter/setter

The demo bypass logic exists to support FYP demo accounts such as:

```text
ali@processor.com
driver@logistics.com
manager@retailer.com
admin@halalchain.my
```

### `Batch`

`Batch` is the central supply-chain record.

Important fields:

- `batch_id`
- `processor_id`
- `current_holder_id`
- `driver_id`
- `product_type`
- `weight`
- `origin_farm`
- `processing_factory`
- `current_location`
- `destination_address`
- `estimated_arrival`
- `certificate_authority`
- `certificate_no`
- `certificate_valid_until`
- `certificate_document_path`
- `qr_code_hash`
- `qr_code_payload`
- `qr_generated_at`
- `qr_revoked_at`
- `status`
- `freshness_score`
- `halal_status`
- `truck_plate`

Important methods:

```php
hasValidCertificate()
hasActiveQr()
```

`hasValidCertificate()` checks whether the batch has enough certificate data and the certificate is not expired.

`hasActiveQr()` checks whether a QR hash exists, the QR has not been revoked, and the batch is not marked invalid.

### `Checkpoint`

`Checkpoint` is the audit trail for batch movement.

It stores:

- batch reference
- submitting user
- location name
- latitude/longitude
- temperature
- action type
- notes
- signature path

This table powers:

- logistics tracking history
- public traceability timeline
- manifest/audit logs
- map coordinate data

### `Incident`

`Incident` stores issue reports:

- `batch_id`
- `user_id`
- `issue_type`
- `description`
- `location`
- `status`
- `severity`

Incidents are created by logistics users during transit and by retailers during rejection.

## 7. Authentication Module

Main file:

```text
app/Http/Controllers/Api/AuthController.php
```

Responsibilities:

- register users
- validate role-specific registration fields
- create role profile records
- send email verification codes
- verify email codes
- resend email codes
- login
- forgot password
- logout

### Registration Flow

The registration flow starts at:

```text
POST /api/register
```

High-level process:

```text
request enters AuthController@register
  -> basic validation
  -> role-specific validation
  -> generate 6-digit email verification code
  -> DB transaction
      -> create user
      -> store verification document if required
      -> create processor/logistics/retailer profile
  -> dispatch verification email through Laravel Mail
  -> return user, approval state, and delivery result
```

Roles with admin approval requirement:

```text
processor
logistics
retailer
```

Consumers do not require admin approval.

Processor registration requires:

- company registration number
- halal certificate number
- halal expiry date
- factory address
- verification document

Logistics registration requires:

- vehicle plate number
- driver license number
- vehicle type
- GDL/verification document

Retailer registration requires:

- store name
- business registration number
- outlet address

### Email Verification

Verification route:

```text
POST /api/verify-email-code
```

The backend checks:

- email exists
- code matches
- expiry timestamp exists
- code is not expired

If approved, the backend can issue a Sanctum token after verification. If the user is still waiting for admin approval, the response explains that approval is still required.

### Login Flow

Login route:

```text
POST /api/login
```

High-level process:

```text
Auth::attempt(email, password)
  -> find user
  -> apply demo/admin bypass state if eligible
  -> reject unverified non-bypass users
  -> reject rejected users
  -> reject pending approval users
  -> load role profile
  -> create Sanctum token
  -> return token and user data
```

Token type:

```text
Laravel Sanctum personal access token
```

### Password Reset

Password reset route:

```text
POST /api/forgot-password
```

The backend uses Laravel Password broker:

```php
Password::sendResetLink($request->only('email'))
```

The response intentionally avoids exposing whether an email exists:

```text
If the email exists, a reset link has been sent.
```

This is a security-aware pattern because it reduces email enumeration.

## 8. Authorization And Session Security

### `RoleMiddleware`

File:

```text
app/Http/Middleware/RoleMiddleware.php
```

This middleware checks:

```php
if (!$user || !in_array($user->role, $roles, true)) {
    abort(403, 'This action is unauthorized for your role.');
}
```

So even if a user has a valid token, they cannot use endpoints outside their role.

### `EnsureTokenIdleTimeout`

File:

```text
app/Http/Middleware/EnsureTokenIdleTimeout.php
```

This middleware tracks token activity in Laravel cache:

```text
sanctum:last-activity:{token_id}
```

If the token is inactive for 15 minutes:

- the cache entry is removed
- the token is deleted
- the request returns `401`

This makes sessions safer without requiring frontend-side logout logic to be perfect.

## 9. Batch And QR Module

Main file:

```text
app/Http/Controllers/Api/BatchController.php
```

Responsibilities:

- list role-visible batches
- create processor batches
- update processor batch status
- generate QR signatures
- show private batch detail
- show public batch listing/detail
- sanitize public traceability response

### Role-Based Batch Visibility

The method `visibleBatchesQueryFor(User $user)` defines what each role can see:

```text
admin      -> all batches
processor  -> batches where processor_id = user id
logistics  -> batches where driver_id = user id OR current_holder_id = user id
retailer   -> batches where current_holder_id = user id
others     -> no private batches
```

This is an important backend rule because it prevents users from directly requesting private batch IDs that do not belong to them.

### Processor Batch Creation

Route:

```text
POST /api/batches
```

Only `processor` role can create batches.

Validation includes:

- unique `batch_id`
- product type
- weight
- slaughter date not after today
- processing date not before slaughter date and not after today
- origin farm
- processing factory
- current location
- optional certificate metadata
- optional certificate document
- optional destination address
- optional estimated arrival

The backend resolves certificate data through:

```php
resolveCertificateSnapshot()
```

This method uses either submitted batch-level certificate data or processor profile certificate data.

It enforces:

- certificate number is required
- certificate expiry date is required
- certificate document is required
- certificate must not be expired

After creating the batch, it creates an initial checkpoint:

```text
action_type = batch_created
notes = Batch created in system.
```

### QR Generation

Routes:

```text
POST /api/batches/{id}/generate-qr
POST /api/admin/batches/{id}/generate-qr
```

Processor can generate QR for their own batch. Admin can generate/regenerate when allowed.

The backend creates a signature:

```php
$signature = hash_hmac(
    'sha256',
    implode('|', [$batch->batch_id, $batch->certificate_no, $issuedAt->toIso8601String()]),
    (string) config('app.key')
);
```

Then it builds a QR payload:

```text
BATCH:{batch_id}|SIG:{signature}
```

It stores:

- `qr_code_hash`
- `qr_code_payload`
- `qr_generated_at`
- clears `qr_revoked_at`
- sets status to `QR Generated`

It also creates a checkpoint:

```text
action_type = qr_generated
notes = Secure QR code generated.
```

### Batch Status Update

Route:

```text
POST /api/batches/update-status
```

Only the owning processor can update status.

Allowed transitions are intentionally narrow. For example:

```text
Pending Documentation -> Ready for QR Generation
Processing -> Ready for QR Generation
```

Delivered, rejected, revoked, and QR-generated states are not freely moved by processor status update.

This prevents unrealistic or unsafe workflow jumps.

### Public Batch Lookup

Routes:

```text
GET /api/public/batches
GET /api/public/batches/{batchId}
```

Public listing only includes batches with:

- `qr_code_hash` present
- `qr_revoked_at` null
- status not equal to `Invalid - Certificate Revoked`

Public detail hides internal actor fields such as internal user IDs, holder IDs, and private profile information.

Public checkpoint output is sanitized to:

- location name
- latitude/longitude
- temperature
- action type
- created timestamp
- alert indicator
- simple summary

If older demo data has `qr_code_hash` but no `qr_code_payload`, the backend rebuilds public payload in:

```php
publicQrPayload()
```

This supports legacy seeded records without breaking the current QR lookup business flow.

## 10. Logistics Module

Main file:

```text
app/Http/Controllers/Api/LogisticsController.php
```

Responsibilities:

- list assigned routes
- submit checkpoint updates
- report incidents
- enforce logistics ownership/assignment

### Assigned Routes

Route:

```text
GET /api/logistics/routes
```

The backend returns batches where:

```text
driver_id = current logistics user
OR current_holder_id = current logistics user
```

It excludes:

```text
Delivered
Rejected
Invalid - Certificate Revoked
```

The response includes route summary fields:

- internal batch database ID
- raw `batch_id`
- truck ID/plate
- destination
- ETA
- formatted current temperature
- status
- progress

Temperature display ignores placeholder `0` readings and returns `N/A` when there is no meaningful temperature checkpoint.

### Checkpoint Submission

Route:

```text
POST /api/logistics/checkpoint
```

Validation includes:

- valid `batch_id`
- temperature between `-40` and `20`
- location string
- optional latitude/longitude
- required signature
- optional notes

Business rules:

- batch must have active QR
- delivered/rejected batches cannot receive checkpoints
- logistics user must be assigned, current holder, or allowed processor handover case

When checkpoint is accepted:

- batch `current_holder_id` becomes logistics user if needed
- batch status becomes `In Transit`
- batch `driver_id` becomes logistics user
- batch current location updates
- truck plate is copied from logistics profile
- checkpoint row is created

Temperature alert rule:

```text
temperature < 0 OR temperature > 4
```

If triggered, notes are prefixed with:

```text
[TEMP ALERT]
```

### Incident Reporting

Route:

```text
POST /api/logistics/incident
```

Validation includes:

- batch ID
- issue type
- description
- location
- optional severity
- optional coordinates

Business rules:

- batch must have active QR
- delivered/rejected batches cannot receive new logistics incidents
- logistics user must be allowed to access the batch

The backend creates:

- `Incident`
- matching `Checkpoint` with `action_type = incident`

This keeps incident reporting visible in both incident lists and traceability timeline.

## 11. Retailer Module

Main file:

```text
app/Http/Controllers/Api/RetailerController.php
```

Responsibilities:

- list incoming shipments
- list delivered inventory
- accept shipment
- reject shipment
- restrict retailer actions to matching outlet/current holder

### Incoming Shipments

Route:

```text
GET /api/retailer/incoming
```

The backend builds search terms from retailer profile:

- store name
- outlet address
- meaningful address words

Then it finds batches whose destination address matches those terms and whose status is:

```text
QR Generated
In Transit
```

This lets demo shipment matching work even without a dedicated shipment assignment table.

### Inventory

Route:

```text
GET /api/retailer/inventory
```

Inventory means:

```text
current_holder_id = retailer user id
AND status = Delivered
```

So accepted shipments become retailer inventory.

### Acceptance Flow

Route:

```text
POST /api/retailer/accept
```

Validation includes:

- batch ID
- quality checks array
- arrival temperature

Required quality checks:

```text
packaging_intact
temperature_check
halal_cert_present
quantity_match
expiry_valid
```

Business rules:

- retailer must be current holder or destination must match retailer profile
- batch must have active QR
- rejected batch cannot be accepted
- unresolved incidents block acceptance

When accepted:

- `current_holder_id` becomes retailer user
- status becomes `Delivered`
- current location becomes outlet/store
- arrival checkpoint is created

### Rejection Flow

Route:

```text
POST /api/retailer/reject
```

Validation includes:

- batch ID
- reason
- arrival temperature
- optional severity

Business rules:

- retailer must be authorized for the batch
- batch must have active QR
- delivered batch cannot be rejected
- already rejected batch cannot be rejected again

When rejected:

- batch status becomes `Rejected`
- halal status becomes `investigation`
- incident is created with issue type `Retail Rejection`
- arrival checkpoint is created

This means rejection is not just a UI status. It also becomes an auditable backend event.

## 12. Admin Module

Main file:

```text
app/Http/Controllers/Api/AdminController.php
```

Responsibilities:

- platform statistics
- user approval/rejection
- incident listing
- certificate revocation
- admin QR generation through BatchController route

### Admin Stats

Route:

```text
GET /api/admin/stats
```

Response includes:

- total batches
- pending users
- active issues
- status breakdown
- certificate summary

Status breakdown:

```text
ready_for_qr
qr_generated
in_transit
delivered
rejected
revoked
```

Certificate summary:

```text
active
expiring_soon
expired
revoked
```

This endpoint is a backend analytics/reporting helper for the admin role.

### User Approval

Routes:

```text
POST /api/admin/approve/{id}
POST /api/admin/reject/{id}
```

Approve sets:

```text
is_approved = true
approved_at = now
registration_status = approved
```

Reject sets:

```text
is_approved = false
approved_at = null
registration_status = rejected
```

Rejected users are not deleted. This preserves registration history.

### Certificate Revocation

Route:

```text
POST /api/admin/batches/{id}/revoke-certificate
```

This runs inside a DB transaction.

It updates batch:

```text
qr_revoked_at = now
status = Invalid - Certificate Revoked
halal_status = breached
```

Then it creates checkpoint:

```text
notes = Certificate revoked by administrator.
```

The transaction matters because the batch should not become revoked without the audit checkpoint also being recorded.

## 13. Report Module

Main file:

```text
app/Http/Controllers/Api/ReportController.php
```

Responsibilities:

- audit log API
- manifest PDF download

### Audit Logs

Route:

```text
GET /api/reports/audit-logs
```

Admins see recent checkpoints across the system.

Non-admin users see logs only for relevant batches:

- processor sees own produced batches
- logistics sees assigned/current holder batches
- retailer sees batches currently held by retailer

The response maps checkpoint rows into simple audit entries:

- batch ID
- action
- timestamp
- location

### Manifest PDF

Route:

```text
GET /api/reports/manifest
```

The backend uses:

```text
barryvdh/laravel-dompdf
```

It renders:

```text
resources/views/reports/manifest.blade.php
```

Then downloads:

```text
halal-manifest-report.pdf
```

Admins can include all batches. Other roles only include batches related to them.

## 14. AI Assistant Backend Proxy

Main files:

```text
app/Http/Controllers/Api/AiAssistantController.php
app/Services/GeminiRoleAssistantService.php
app/Services/RoleAssistantMonthlySummaryService.php
```

The AI assistant is intentionally backend-proxied.

That means:

- Gemini API key stays on Laravel backend
- API client never receives the Gemini API key
- role validation happens server-side
- the prompt includes controlled context
- the model is used as an operational assistant, not as an autonomous action executor

### Assistant Endpoint

Route:

```text
POST /api/assistant/chat
```

Allowed roles:

```text
processor
logistics
retailer
```

Input validation:

- `role` must match allowed roles
- `screen` required, max 80 chars
- `prompt` required, 2 to 2000 chars
- `context` optional array
- `history` optional array
- history role must be `user` or `assistant`
- history content max 4000 chars

If more than 8 history items are sent, the controller trims to the last 8.

### Role Authorization

The controller checks:

```php
abort_unless(
    $user && $user->role === $validated['role'],
    403,
    'This assistant request is not authorized for your role.'
);
```

So a user cannot pretend to be another role in the assistant payload.

### Gemini Service

`GeminiRoleAssistantService`:

- reads API key from `config('services.gemini.api_key')`
- reads model from `GEMINI_MODEL`
- calls Gemini `generateContent`
- builds a role-specific prompt
- adds current context JSON
- adds current-month operational summary
- adds recent conversation
- returns normalized JSON

Normalized response:

```json
{
  "message": "...",
  "suggestions": ["...", "..."],
  "disclaimer": "AI guidance supports operations only..."
}
```

### Monthly Summary Service

`RoleAssistantMonthlySummaryService` builds role-scoped monthly context.

Processor summary includes:

- batches created this month
- status breakdown
- recent batches

Logistics summary includes:

- routes touched this month
- status breakdown
- checkpoints submitted
- incidents reported
- recent routes

Retailer summary includes:

- visible shipments this month
- status breakdown
- delivered inventory count
- rejection count
- recent shipments

This lets the assistant answer questions like “what happened this month” without exposing unrestricted database querying.

## 15. SMTP And Email Delivery

The backend uses Laravel Mail.

Current email use cases:

- registration verification code
- resend verification code
- password reset link

Brevo SMTP configuration is stored in `.env`.

Important production-style values:

```env
MAIL_MAILER=smtp
MAIL_SCHEME=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=your-brevo-smtp-login
MAIL_PASSWORD=your-brevo-smtp-key
MAIL_FROM_ADDRESS="no-reply@shiebindev.com"
MAIL_FROM_NAME="${APP_NAME}"
```

Important detail:

- `MAIL_USERNAME` is the Brevo SMTP login, not the project name.
- `MAIL_PASSWORD` is the Brevo SMTP key.
- For Brevo port `587`, `MAIL_SCHEME=smtp`.

The backend has been smoke-tested by sending a test email through Brevo.

## 16. Docker Runtime

Main files:

```text
Dockerfile
.dockerignore
docker-compose.yml
deploy/compose/docker-compose.prod.yml
```

### `Dockerfile`

The backend image is based on:

```text
php:8.2-fpm-bookworm
```

It installs:

- git
- unzip
- curl
- GD dependencies
- zip dependencies
- `pdo_mysql`
- `gd`
- `zip`
- Composer

Then it copies source code, creates required runtime folders, installs Composer dependencies, fixes ownership, and starts:

```text
php-fpm
```

### `.dockerignore`

The `.dockerignore` file prevents sensitive or runtime-only files from being copied into the image.

Excluded:

- `.env`
- `.env.*`
- `.phpunit.result.cache`
- uploaded public storage files
- framework cache/session/testing/view files
- logs
- node modules
- git metadata

Allowed exception:

```text
!.env.testing
```

This supports test execution without putting real runtime secrets in the image.

### Local `docker-compose.yml`

Local services:

```text
app    -> Laravel PHP-FPM
nginx  -> HTTP entry point on port 8000
db     -> MariaDB on host port 3308
```

The app service reads:

```yaml
env_file:
  - ./backend/halal_traceability_api/.env
```

This means secrets are injected at runtime, not baked into the image.

The app service still overrides DB connection values for local Docker networking:

```yaml
DB_HOST: db
DB_PORT: 3306
DB_DATABASE: halaltrack_db
DB_USERNAME: root
DB_PASSWORD: root
```

MariaDB uses a named volume:

```text
halaltrack_db_data
```

Important database note:

- Editing `documentation/database/halaltrack_db.sql` only affects a fresh volume.
- Existing Docker database data lives in the named volume.
- Rebuilding the backend image does not automatically reset the database.

## 17. Cloudflare Tunnel Runtime

Current public demo origin:

```text
https://halaltrack.shiebindev.com
```

Tunnel mapping:

```text
https://halaltrack.shiebindev.com -> http://localhost:8000
```

This exposes the local Nginx/Laravel backend through Cloudflare without buying a VPS yet.

Important implications:

- Cloudflare Tunnel handles public inbound HTTPS.
- Laravel still runs locally in Docker.
- MariaDB still runs locally in Docker.
- SMTP still works independently because Laravel makes outbound SMTP connections to Brevo.
- This is suitable for FYP demo/testing, not final production hosting.

For a VPS later, the same Laravel app can run behind real server Nginx and Docker Compose instead of Cloudflare Tunnel.

## 18. CI/CD And Security Scanning

Main workflow:

```text
.github/workflows/backend-ci.yml
```

Backend CI stages:

```text
backend-tests
  -> setup PHP 8.2
  -> install Composer dependencies
  -> prepare test environment
  -> run composer test

backend-docker-build
  -> build backend Docker image
  -> run Trivy image scan
  -> upload Trivy image SARIF
  -> run Trivy config scan
  -> upload Trivy config SARIF
  -> upload SARIF artifacts
  -> push backend image to GHCR on main
```

Trivy is currently configured as a reporting scan:

```text
--exit-code 0
```

So the CI can pass while still producing reports and Security tab findings.

Image target:

```text
ghcr.io/{github_owner}/halal-track-backend
```

Docker Hub can also be used manually by tagging:

```powershell
docker tag fyp_project-app:latest shiebin/fyp_project-app:latest
docker push shiebin/fyp_project-app:latest
```

Important security note:

- The latest backend image build excludes `.env`, logs, cache, and uploaded runtime files.
- Old public images should be treated as exposed if they were pushed before `.dockerignore` hardening.
- Secrets should be rotated if there is uncertainty about whether they were pushed.

## 19. Testing Strategy

Backend test configuration:

```text
phpunit.xml
```

Tests force:

```text
APP_ENV=testing
DB_CONNECTION=sqlite
DB_DATABASE=:memory:
MAIL_MAILER=array
CACHE_STORE=array
SESSION_DRIVER=array
QUEUE_CONNECTION=sync
```

This is important because it prevents PHPUnit from accidentally using the live Docker MariaDB database.

Current backend tests include:

- admin authorization
- admin stats/reporting breakdown
- partner approval flow
- rejected login prevention
- demo account bypass access
- processor batch creation with certificate document
- logistics checkpoint authorization
- logistics assigned route formatting
- AI assistant authorization and upstream failure handling
- certificate revocation transaction behavior
- retailer acceptance authorization
- public batch listing
- public batch detail privacy
- legacy QR payload fallback
- revoked batch public rejection
- manifest PDF download

Current verified test result:

```text
24 passed, 96 assertions
```

## 20. Step-By-Step Request Examples

### A. Login

```text
POST /api/login
  -> AuthController@login
  -> Auth::attempt
  -> demo/admin bypass state if eligible
  -> email verification check
  -> approval/rejection check
  -> profile relation loaded
  -> Sanctum token created
  -> response returns user + token
```

The next protected request sends:

```text
Authorization: Bearer {token}
```

### B. Processor Creates Batch

```text
POST /api/batches
  -> auth:sanctum
  -> token.idle
  -> role:processor
  -> BatchController@store
  -> validate request
  -> resolve certificate snapshot
  -> DB transaction
      -> create Batch
      -> create batch_created Checkpoint
  -> optional QR generation
  -> response returns batch
```

Key backend protection:

- only processor can create
- user must be verified/approved unless demo bypass applies
- expired certificate is rejected
- missing certificate document is rejected

### C. QR Generation

```text
POST /api/batches/{id}/generate-qr
  -> find visible batch
  -> ensure owner processor or admin
  -> ensure valid certificate
  -> ensure batch status allows QR
  -> create HMAC signature
  -> store qr_code_hash and qr_code_payload
  -> set status QR Generated
  -> create qr_generated checkpoint
```

### D. Logistics Checkpoint

```text
POST /api/logistics/checkpoint
  -> role:logistics
  -> validate location, temperature, signature
  -> find batch by batch_id
  -> ensure active QR
  -> ensure batch not delivered/rejected
  -> ensure logistics user can access batch
  -> update batch holder, driver, location, status
  -> create checkpoint
```

### E. Retailer Accepts Shipment

```text
POST /api/retailer/accept
  -> role:retailer
  -> validate quality_checks and arrival_temperature
  -> find batch
  -> ensure retailer can manage batch
  -> ensure all required checks are true
  -> ensure active QR
  -> ensure no unresolved incidents
  -> set status Delivered
  -> set current_holder_id to retailer
  -> create arrival checkpoint
```

### F. Retailer Rejects Shipment

```text
POST /api/retailer/reject
  -> role:retailer
  -> validate reason and arrival temperature
  -> find batch
  -> ensure retailer can manage batch
  -> ensure active QR
  -> prevent delivered/rejected conflict
  -> set status Rejected
  -> set halal_status investigation
  -> create Retail Rejection incident
  -> create arrival checkpoint
```

### G. Public Traceability Lookup

```text
GET /api/public/batches/{batchId}
  -> BatchController@publicShow
  -> load checkpoints
  -> ensure hasActiveQr()
  -> return sanitized batch fields
  -> return sanitized checkpoint timeline
```

Public consumers do not receive internal user/holder/driver details.

### H. AI Assistant Chat

```text
POST /api/assistant/chat
  -> auth:sanctum
  -> role:processor,logistics,retailer
  -> validate role/screen/prompt/context/history
  -> ensure request role equals authenticated user role
  -> GeminiRoleAssistantService@generateReply
  -> build prompt with role instruction, context, monthly summary
  -> call Gemini API
  -> return message, suggestions, disclaimer
```

## 21. What Is Already Complete

Backend functionality currently supports the main FYP business flows:

- registration with role profiles
- email verification through SMTP
- admin approval/rejection
- Sanctum login/logout
- role-protected API access
- processor batch creation
- certificate validation
- QR generation and revocation
- public batch traceability
- logistics assigned routes
- logistics checkpoint submission
- logistics incident reporting
- retailer incoming shipment view
- retailer acceptance/rejection
- retailer inventory movement
- admin stats and incidents
- audit logs
- manifest PDF generation
- Gemini role assistant proxy
- Docker local runtime
- Cloudflare Tunnel public demo access
- backend CI with tests, Docker build, Trivy report artifacts, and GHCR push

## 22. Current Limitations And Production Notes

This backend is strong for FYP demo and evaluation, but these notes matter before real production:

- Cloudflare Tunnel currently exposes local Docker; VPS hosting is still the cleaner long-term deployment.
- Local Docker uses simple DB credentials for demo convenience.
- Demo accounts can bypass some verification/approval checks.
- Trivy currently reports findings without failing the CI pipeline.
- Retailer shipment matching uses destination/profile search terms rather than a dedicated assignment table.
- The AI assistant is an operational helper, not an official halal/legal decision engine.
- Public traceability depends on checkpoint submissions, not continuous GPS streaming.
- Old Docker Hub images should be replaced if they were pushed before `.dockerignore` hardening.

## 23. How To Run The Backend

From repository root:

```powershell
docker compose up -d --build
```

Clear Laravel config cache:

```powershell
docker exec halaltrack_app php artisan config:clear
```

Run migrations if needed:

```powershell
docker exec halaltrack_app php artisan migrate --force
```

Run tests:

```powershell
docker exec halaltrack_app php artisan test
```

Public local API:

```text
http://127.0.0.1:8000/api
```

Current Cloudflare demo API:

```text
https://halaltrack.shiebindev.com/api
```

Public batch endpoint:

```text
https://halaltrack.shiebindev.com/api/public/batches
```

## 24. Best Files To Read First

If you are trying to understand the backend source code, read in this order:

1. `routes/api.php`
2. `app/Http/Middleware/RoleMiddleware.php`
3. `app/Http/Middleware/EnsureTokenIdleTimeout.php`
4. `app/Models/User.php`
5. `app/Models/Batch.php`
6. `app/Http/Controllers/Api/AuthController.php`
7. `app/Http/Controllers/Api/BatchController.php`
8. `app/Http/Controllers/Api/LogisticsController.php`
9. `app/Http/Controllers/Api/RetailerController.php`
10. `app/Http/Controllers/Api/AdminController.php`
11. `app/Services/GeminiRoleAssistantService.php`
12. `database/migrations/`
13. `tests/Feature/AuthorizationTest.php`
14. `tests/Feature/ExampleTest.php`

## 25. Important Mental Model

HalalTrack backend is not just a CRUD API. The important thing is the workflow:

```text
User registration
  -> email verification
  -> admin approval for partners
  -> processor creates certified batch
  -> backend generates signed QR
  -> logistics records checkpoints and incidents
  -> retailer accepts or rejects shipment
  -> public can verify sanitized traceability
  -> admin can monitor, report, and revoke certificate
```

The backend protects this workflow using:

- Sanctum tokens
- role middleware
- owner/visibility queries
- certificate validation
- QR active/revoked state
- checkpoint audit trail
- transaction boundaries for sensitive changes
- public response sanitization
- runtime-only secrets

If you understand those pieces, you understand the core of this application.
