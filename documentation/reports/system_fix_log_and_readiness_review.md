# FYP Project System Fix Log and Readiness Review

Date: 2026-03-30

## Scope

This document summarizes the major issues found during the recent end-to-end review of the project, how each issue was resolved, what was verified, and what still remains before final handoff or presentation.

It covers:

- Local Docker and API access fixes
- Performance fixes for local Windows + Docker development
- Avatar/static file serving fixes
- GPS integration
- Password reset / email preparation
- Consumer traceability timeline improvements
- QR payload parsing fixes
- Audit log and processor UI corrections
- Backend authorization and ownership fixes
- Registration approval workflow
- Registration document handling
- Admin review workflow enhancement
- Test coverage added during the review

## Current Architecture Summary

The current local architecture is:

`Flutter app / browser -> Nginx container -> Laravel app container -> MariaDB container`

Key local access points:

- Browser: `http://127.0.0.1:8000/api`
- Android Emulator: `http://10.0.2.2:8000/api`
- Docker MariaDB from host tools: `127.0.0.1:3308`

Important distinction:

- The frontend does not call PHP-FPM directly.
- Requests go through Docker Nginx first.
- Emulator access uses `10.0.2.2`, not `127.0.0.1`.

## 1. Docker Base URL Mismatch

### Problem

The backend generated pagination and API URLs using an origin that did not match the actual local access point. This caused incorrect links when testing the public API from the host machine.

### Root Cause

`APP_URL` in the Docker environment and Laravel `.env` did not match the real local URL being used for testing.

### Fix

Aligned both Docker and Laravel runtime config to:

`http://127.0.0.1:8000`

### Result

Public endpoints now return correct pagination URLs such as:

`http://127.0.0.1:8000/api/public/batches?page=1`

## 2. Local Docker Performance Was Too Slow on Windows

### Problem

The backend was reachable from browser and emulator, but requests were noticeably slow.

### Root Cause

The `app` container originally used a Windows bind mount for the entire Laravel directory. Under Docker Desktop on Windows, this is significantly slower for PHP file access.

### Fix

Changed the default Docker setup to a fast mode:

- The `app` container runs code from the image instead of a Windows bind mount
- `nginx` only mounts the public-facing files it needs

Also added a separate dev override file for future hot-reload style development:

- `docker-compose.dev.yml`

### Result

The API became much faster for local testing while preserving a separate opt-in dev mode for bind-mounted workflows.

## 3. Avatar Images Were Missing

### Problem

User avatars were not loading in the frontend even though user data was returned successfully.

### Root Cause

The uploaded storage path used by Laravel and the files served by Nginx were not properly shared between containers.

### Fix

Shared the Laravel public storage directory correctly between `app` and `nginx`.

### Result

Avatar file URLs now resolve correctly through Docker Nginx.

## 4. GPS Integration Was Not Real Yet

### Problem

The project originally presented GPS-style behavior, but some logistics and processor location values were still static or hardcoded.

### Root Cause

The Flutter app had no real device location integration and some dashboards used placeholder coordinates.

### Fix

Integrated real device/emulator location using `geolocator`.

Implemented:

- Flutter location service abstraction
- Android location permissions
- iOS location usage description
- Logistics and processor screens calling real location services
- Backend logistics endpoint accepting and storing `latitude` and `longitude`

### Result

The app now reads real location data from the device/emulator instead of relying on hardcoded demo coordinates.

## 5. Processor Address Display Was Wrong

### Problem

Processor UI displayed raw latitude/longitude as the current address, which was confusing during emulator testing.

### Root Cause

Processor batch creation and address display were using location-derived coordinate text instead of the processor's factory address.

### Fix

Changed processor behavior to prefer the processor profile's factory address for the current factory location display and batch submission.

### Result

Processor UI now behaves more like a factory-side interface, while logistics continues to use live GPS.

## 6. Password Reset Email Flow Was Not Deployment-Ready

### Problem

The project had password reset logic, but the reset link flow depended on incomplete default behavior and was not ready for future SMTP deployment.

### Root Cause

Reset URL generation and reset page handling were not explicitly wired for this project structure.

### Fix

Implemented:

- Configurable reset URL generation
- Backend-hosted password reset page
- Reset submission route
- Additional environment variables for future frontend/backend reset URL separation

Environment preparation added:

- `FRONTEND_URL`
- `PASSWORD_RESET_URL`

### Result

The password reset flow is now structurally ready. Once SMTP credentials are provided in production, email reset can work without extra code changes.

## 7. Consumer Traceability Was Static Instead of Real

### Problem

The consumer traceability view showed a mostly hardcoded stage-based supply chain timeline instead of real logistics and checkpoint events.

### Root Cause

The consumer screen only used summary batch data and did not load the actual checkpoint history.

### Fix

Added a public batch detail endpoint that returns real checkpoint data, then changed the consumer detail screen to render the timeline dynamically from those checkpoints.

### Result

Consumer traceability now reflects the actual event log stored in the database, including:

- Location names
- Action types
- Temperatures
- Notes
- Actor names and roles
- Timestamps

## 8. Demo Data Was Too Thin for Cross-Validation

### Problem

Some batches did not have enough checkpoints to clearly demonstrate traceability in presentation.

### Root Cause

Existing seed data did not include enough contrast cases for full route verification.

### Fix

Added additional seeded demo batches:

- `B-2026-201`
- `B-2026-202`

These provide clearer examples of:

- Normal completed cold-chain delivery
- In-transit issue / investigation scenario

### Result

The public consumer route, logistics flow, and incident visibility can now be demonstrated with stronger sample data.

## 9. QR Scan Worked Visually but Not Logically

### Problem

Processor-generated QR content included a structured payload, but the scanning flows treated the raw payload as if it were already a clean `batch_id`.

### Root Cause

Processor QR generation encoded data in the format:

`BATCH:...|TYPE:...|LOC:...|HASH:...`

However, logistics, retailer, and consumer flows initially passed the full raw string onward without extracting the actual batch ID.

### Fix

Added a QR payload parser service in Flutter and updated all scan entry points to extract the real `batch_id` before continuing.

Affected scan flows:

- Logistics
- Retailer
- Consumer

### Result

QR scanning now maps correctly to actual batch records instead of passing malformed identifiers to the backend.

## 10. Audit Logs Were Over-Exposed

### Problem

Processor audit views appeared to show global audit history instead of only the relevant records for that user.

### Root Cause

Audit log retrieval was not sufficiently filtered by role and ownership.

### Fix

Updated the audit log backend logic so the returned records are filtered according to the authenticated user's role and accessible scope.

### Result

Processor users now see their own relevant audit trail rather than unrelated global data.

## 11. Backend Authorization Was Incomplete

### Problem

Several protected endpoints were only behind authentication, not actual role-based access control.

This meant that an authenticated user with the wrong role could still call endpoints such as:

- Admin stats
- Logistics checkpoint submission
- Retailer acceptance
- Processor batch creation

### Root Cause

Routes were grouped under `auth:sanctum`, but not consistently protected by role middleware and ownership checks.

### Fix

Implemented backend role middleware and applied it to route groups:

- `role:admin`
- `role:processor`
- `role:logistics`
- `role:retailer`

Also tightened controller-level ownership checks so users can only act on batches they are actually allowed to manage.

### Result

Role restrictions now work at the backend level, not just in frontend navigation.

## 12. Retailer and Logistics Could Previously Operate on the Wrong Batch

### Problem

Retailer acceptance/rejection and logistics checkpoint/incident operations could be attempted on batches not actually assigned to that actor.

### Root Cause

The original backend validation mostly checked whether the batch existed, not whether the current user was allowed to operate on it.

### Fix

Added business-level authorization rules:

- Retailers can only manage shipments that belong to them or clearly match their assigned destination context
- Logistics users must be the assigned driver/current holder, or must be taking over from the processor in the intended handover case
- Delivered batches cannot continue receiving transit-style logistics updates

### Result

The logistics and retailer flows now better match the actual business rules of custody and delivery.

## 13. Manifest Export Failed Because of Schema Drift

### Problem

The manifest report endpoint failed because code and SQL data expected shipping-related columns that were missing from the migration definition.

### Root Cause

The schema used by the SQL dump and controller logic had fields not fully represented in migrations, including:

- `driver_id`
- `truck_plate`
- `destination_address`
- `estimated_arrival`

### Fix

Updated the original batch migration for consistency and added a follow-up migration to safely add missing columns on existing databases.

### Result

Manifest generation now works again and no longer fails due to missing columns.

## 14. Registration Approval Workflow Was Contradictory

### Problem

The system had admin approval UI and login-side "pending approval" checks, but partner registration still auto-approved every new account immediately.

### Root Cause

Registration hardcoded `is_approved = true`.

### Fix

Changed registration logic so:

- `processor`, `logistics`, and `retailer` registrations become pending by default
- only approved accounts can log in
- admin approval sets approval timestamp
- registration screen now redirects applicants back to login instead of auto-logging them into dashboards

Consumers remain auto-usable because that role is public-facing and not part of the partner approval queue.

### Result

The onboarding flow now matches the intended admin approval business model.

## 15. Registration Document Upload Was a Fake Requirement

### Problem

The registration screen forced some users to upload a supporting document, but the backend did not actually store that file in the role profile records.

### Root Cause

The frontend sent a loosely named file field and the backend registration logic ignored it.

### Fix

Implemented real document handling in registration:

- Processor registration stores the uploaded file into `cert_document_path`
- Logistics registration stores the uploaded file into `gdl_license_path`
- Files are stored under the Laravel public disk

Also corrected the registration UI:

- Processor and logistics users are required to upload a document
- Retailer users are no longer incorrectly blocked by a document field that had no backend storage target

### Result

Supporting document upload is now a real part of partner onboarding instead of a cosmetic form requirement.

## 16. Phone Update Field Mapping Was Broken

### Problem

Profile update requests could appear successful while failing to update the phone number correctly.

### Root Cause

Frontend and backend update flow used `phone`, while the actual user model field is `phone_number`.

### Fix

Aligned the update request field and backend handling to use `phone_number`.

### Result

Phone number profile updates now map correctly to the database.

## 17. Tests Were Too Weak and Some Did Not Reflect Real Behavior

### Problem

The test suite was too shallow, and some earlier tests were either failing for unrelated reasons or not covering the real risk areas.

### Root Cause

The original test coverage did not target the business-critical issues found during live review:

- role authorization
- partner approval
- manifest generation
- registration document storage

### Fix

Added or updated tests for:

- non-admin access to admin stats
- partner registration requiring approval before login
- processor document upload during registration
- non-logistics access to logistics checkpoint
- retailer ownership restrictions
- public batches endpoint
- manifest generation

Also configured testing to use isolated SQLite settings for PHPUnit.

### Result

The backend test suite now exercises the main business-risk areas discovered during this review.

Final backend test result:

`8 passed (21 assertions)`

## 18. Admin Review Workflow Was Too Thin for Presentation

### Problem

The admin dashboard had approval and rejection actions, but the review experience was still too shallow for a convincing demo:

- no submitted timestamp on the card
- no document readiness status
- no dedicated review step before approve/reject
- no clean way to open uploaded verification files from a review flow

### Root Cause

The pending approval UI only showed a small subset of account data and did not package the role-specific details into a real review panel.

### Fix

Enhanced the admin approval UI so pending applications now show:

- submitted timestamp
- document readiness state
- role-specific business/profile details
- a `REVIEW` action that opens a dedicated dialog
- document open action inside the review dialog
- approve/reject actions inside the review dialog

### Result

The admin approval flow now looks and behaves more like an actual review panel and is more suitable for presentation and supervisor walkthroughs.

## 19. Batch State Changes Were Not Atomic

### Problem

Batch creation and batch status updates could write part of the business event successfully while failing the audit trail portion.

### Root Cause

In `BatchController`, the batch record write and the checkpoint/audit record write were separate operations without a database transaction.

That meant a failure in checkpoint creation could leave:

- a created batch without its initial audit entry, or
- an updated batch status without the corresponding audit log

### Fix

Wrapped both flows in database transactions:

- batch creation + initial checkpoint
- batch status update + status-change checkpoint

### Result

Batch lifecycle writes are now atomic, so the persisted batch state stays consistent with the traceability/audit history.

## Files Most Relevant to the Fixes

Backend:

- `backend/halal_traceability_api/routes/api.php`
- `backend/halal_traceability_api/app/Http/Middleware/RoleMiddleware.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/AuthController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/AdminController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/BatchController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/LogisticsController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/RetailerController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/UserUpdateController.php`
- `backend/halal_traceability_api/app/Providers/AppServiceProvider.php`
- `backend/halal_traceability_api/database/migrations/2026_01_09_132613_create_batches_table.php`
- `backend/halal_traceability_api/database/migrations/2026_03_30_000001_add_shipping_columns_to_batches_table.php`
- `backend/halal_traceability_api/tests/Feature/AuthorizationTest.php`

Frontend:

- `frontend/halal_traceability_app/lib/screens/registration_screen.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/processor_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/logistics_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/retailer_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/consumer_dashboard.dart`
- `frontend/halal_traceability_app/lib/services/location_service.dart`
- `frontend/halal_traceability_app/lib/services/qr_payload_service.dart`

Infrastructure and seed data:

- `docker-compose.yml`
- `docker-compose.dev.yml`
- `backend/halal_traceability_api/docker/nginx/default.conf`
- `documentation/database/halaltrack_db.sql`

## What Was Verified Live

The following were verified directly on the rebuilt local Docker stack:

- `docker compose down -v`
- `docker compose up -d --build`
- all 3 containers started correctly
- public batches endpoint returned valid JSON
- database import restored demo data
- manifest endpoint returned `200` and `application/pdf`
- partner registration returned `requires_approval = true`
- pending partner login returned `403`

## Remaining Gaps

The project is much more stable now, but a few things are still worth noting:

### 1. SMTP is structurally ready but still needs real credentials

The password reset flow is implemented, but real mail delivery still depends on production SMTP credentials and domain verification.

### 2. Route map is now implemented, but continuous live tracking is still out of scope

The app now provides a checkpoint-based route map using recorded shipment coordinates, but it does not attempt continuous live GPS streaming or auto-refresh tracking.

## Readiness Conclusion

Compared with the earlier state of the project, the system is now significantly closer to presentation-ready and handoff-ready.

The main reasons are:

- backend authorization now matches business roles
- QR scan flow now resolves real batch IDs
- traceability uses real checkpoint data
- local Docker behavior is stable and fast enough for demo work
- onboarding approval logic is coherent
- manifest export works
- registration documents are now actually stored
- automated backend tests cover the most important failure cases found during review

If needed, the next best follow-up document would be a separate presentation script / demo checklist describing the safest order to demonstrate:

- Processor
- Logistics
- Retailer
- Consumer
- Admin approval
