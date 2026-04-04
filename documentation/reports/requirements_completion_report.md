# HalalTrack Requirements Completion Report

Date: 2026-04-04

## Summary

This report summarizes the implementation status of the HalalTrack project after comparing the current system against the project proposal and project design requirements.

Current status:

- Core mandatory requirements are implemented and working for project demo and submission use.
- The system now supports role-based dashboards for `admin`, `processor`, `logistics`, `retailer`, and public `consumer` traceability.
- Backend logic, database schema, and key frontend flows were updated to align with the design document.
- Backend regression tests are passing.
- Frontend verification now passes with `flutter analyze` and `flutter test`.
- Checkpoint-based route maps are now available in consumer, admin, and logistics detail flows.

Overall assessment:

- Mandatory requirements: largely completed
- Optional / enhancement requirements: partially completed
- Remaining risks: mainly production-readiness items, not core demo blockers

## Mandatory Requirements Completed

### 1. Public Consumer Traceability With Data Sanitization

Completed:

- Public batch listing and detail endpoints are available.
- Consumer can search and view traceability information without logging in.
- Public responses no longer expose internal actor identity or internal notes.
- Consumer UI now shows safe fields only, including certificate information and sanitized timeline summaries.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/BatchController.php`
- `frontend/halal_traceability_app/lib/screens/dashboards/consumer_dashboard.dart`

### 2. Email Verification Flow

Completed:

- Registration generates a 6-digit verification code.
- Users can verify email through a dedicated verification flow.
- Users can request a new verification code.
- Unverified accounts are blocked from normal sign-in.

Note:

- In local/demo mode, the system uses debug verification code fallback because no real SMTP server is configured.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/AuthController.php`
- `frontend/halal_traceability_app/lib/screens/email_verification_screen.dart`
- `frontend/halal_traceability_app/lib/screens/registration_screen.dart`
- `frontend/halal_traceability_app/lib/screens/login_screen.dart`

### 3. Role-Based Access Control and Session Control

Completed:

- Admin, processor, logistics, retailer, and consumer flows are separated.
- Protected APIs use Sanctum authentication.
- Idle token timeout was added for session inactivity control.
- Role middleware remains enforced for protected routes.

Implemented in:

- `backend/halal_traceability_api/app/Http/Middleware/EnsureTokenIdleTimeout.php`
- `backend/halal_traceability_api/app/Http/Middleware/RoleMiddleware.php`
- `backend/halal_traceability_api/routes/api.php`

### 4. Batch-Level Certificate Management

Completed:

- Batch records now store certificate snapshot data.
- Batch creation requires valid halal certificate information.
- Batch can use batch-level certificate document upload.
- Certificate authority, certificate number, expiry date, and document path are persisted per batch.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/BatchController.php`
- `backend/halal_traceability_api/app/Models/Batch.php`
- `backend/halal_traceability_api/database/migrations/2026_04_02_000001_add_compliance_columns_to_batches_table.php`
- `frontend/halal_traceability_app/lib/screens/dashboards/processor_dashboard.dart`

### 5. Backend-Generated Secure QR Logic

Completed:

- QR generation is no longer based on frontend hash generation.
- QR payload and signature are generated on the backend.
- QR generation is blocked unless certificate data is valid.
- Revoked certificate state blocks public availability.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/BatchController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/AdminController.php`
- `frontend/halal_traceability_app/lib/screens/dashboards/processor_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/admin_dashboard.dart`

### 6. Logistics Checkpoint Validation

Completed:

- Checkpoint submission validates batch access and business status.
- Invalid states are blocked.
- Temperature validation is enforced.
- Incident severity support was added.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/LogisticsController.php`
- `backend/halal_traceability_api/database/migrations/2026_04_02_000003_add_severity_to_incidents_table.php`

### 7. Retailer Acceptance and Rejection Workflow

Completed:

- Arrival temperature is required for retailer acceptance.
- Mandatory quality checks are enforced.
- Rejection requires reason and temperature.
- Rejected batches are marked for investigation.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/RetailerController.php`
- `frontend/halal_traceability_app/lib/screens/dashboards/retailer_dashboard.dart`

### 8. Admin Approval and Governance Improvements

Completed:

- Admin approval now marks registration status correctly.
- Rejected users are not deleted from the database.
- Pending list excludes rejected users.
- Admin can revoke batch certificate.
- Admin batch detail view now shows certificate and QR state.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/AdminController.php`
- `frontend/halal_traceability_app/lib/screens/dashboards/admin_dashboard.dart`

### 9. Consumer Demo Data and Public Demo Experience

Completed:

- Public demo batches were cleaned and backfilled with realistic certificate and QR data.
- Obvious smoke-test records were removed.
- Consumer-facing sample records now look more realistic.
- UI overflow issues caused by long origin or certificate text were fixed.

Implemented in:

- Docker MariaDB demo data updates
- `frontend/halal_traceability_app/lib/screens/dashboards/consumer_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/admin_dashboard.dart`

### 10. Checkpoint-Based Route Map Visualization

Completed:

- Consumer batch detail now shows a checkpoint-based shipment route map.
- Admin batch detail reuses the same route map component.
- Logistics assigned shipments can open a route detail view with the same map visualization.
- The map uses real checkpoint coordinates on OpenStreetMap tiles.
- The timeline remains visible below the map for event explanation.

Scope note:

- This is a geographic route visualization based on recorded checkpoints.
- It is not continuous live GPS streaming.

Implemented in:

- `backend/halal_traceability_api/app/Http/Controllers/Api/BatchController.php`
- `backend/halal_traceability_api/app/Http/Controllers/Api/LogisticsController.php`
- `frontend/halal_traceability_app/lib/models/checkpoint_map_point.dart`
- `frontend/halal_traceability_app/lib/services/batch_route_mapper.dart`
- `frontend/halal_traceability_app/lib/widgets/route_map_card.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/consumer_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/admin_dashboard.dart`
- `frontend/halal_traceability_app/lib/screens/dashboards/logistics_dashboard.dart`

## Important Demo Notes

To support smooth in-class demo and evaluation, the system currently includes controlled bypass behavior:

- `admin` role can sign in without completing email verification.
- Selected demo accounts can bypass email verification and approval checks.

Configured demo accounts:

- `ali@processor.com`
- `admin@halalchain.my`
- `driver@logistics.com`
- `manager@retailer.com`

This behavior is intended for local/demo convenience. In production deployment, these bypass rules should be removed or disabled by configuration.

Implemented in:

- `backend/halal_traceability_api/app/Models/User.php`
- `backend/halal_traceability_api/config/services.php`

## Testing Status

Completed:

- Laravel backend tests were updated and executed successfully.
- Frontend validation now completes successfully.
- Regression coverage now includes:
  - pending user filtering
  - batch-level certificate creation
  - admin login bypass
  - demo account login bypass
  - revoke certificate without partial failure
  - public batch sanitization
  - logistics route summaries exposing batch detail IDs for route navigation

Latest backend result:

- `php artisan test`
- `18 passed`

Latest frontend result:

- `flutter analyze`
- `No issues found`
- `flutter test`
- `4 passed`

Main test file:

- `backend/halal_traceability_api/tests/Feature/AuthorizationTest.php`

## Remaining Risks / Not Fully Completed

These do not block core demo functionality, but should be noted honestly in submission or presentation:

### 1. Real Email Delivery Is Not Configured

- Verification logic exists.
- Real mail sending is not fully deployed because no SMTP/mail server is configured.
- Local development currently relies on debug verification code fallback.

### 2. Real-Time Streaming Map Tracking Is Not Implemented

- The current route map is based on submitted checkpoint coordinates.
- This is sufficient for demo and traceability use.
- Continuous live GPS streaming, background tracking, and auto-refresh remain out of scope for the current FYP version.

### 3. Some Optional Enhancements Remain Partial

Not fully completed:

- richer admin export/filter/reporting tools
- full certificate history/version management
- advanced route deviation analytics
- richer delivery analytics and reporting visuals

## Final Assessment

For project demonstration and submission purposes, the project is now in a strong nearly-complete state relative to the mandatory design requirements.

Practical conclusion:

- The main mandatory requirements are implemented.
- The system is usable end-to-end across all required roles.
- Public consumer traceability now behaves in a safer and more realistic way.
- The remaining gaps are mostly production-hardening and optional enhancement items rather than missing core assignment functionality.

Recommended presentation wording:

- “The mandatory system requirements are implemented and working. Email verification is implemented with local debug fallback because a real mail server is not configured in the current demo environment.”
- “Several demo accounts were kept accessible for faster in-class testing, while the normal registration flow still follows verification and approval rules.”
- “The shipment map is implemented as a checkpoint-based geographic route view rather than continuous live GPS streaming, which is an intentional scope decision for the FYP project.”
