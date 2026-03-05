---
name: database-traceability-validator
description: "Validates database schema integrity, migration safety, and audit-trail completeness for the Halal Traceability system."
risk: medium
source: project
date_added: "2026-03-05"
---

# Database Traceability Validator

## Overview

This skill provides a systematic checklist to validate the database layer of the Halal Traceability system. It verifies that migrations are complete, relationships are correctly defined, audit data is preserved, and the chain of custody cannot be silently broken.

## Core Models to Validate

- `users` — Role, approval status, profile FK
- `batches` — Holder, status, originating processor
- `processor_profiles`, `logistics_profiles`, `retailer_profiles` — Role-specific data
- `logistics_routes` — Assigned routes with geo checkpoints
- `checkpoints` — Individual scan events tied to routes and users
- `incidents` — Reported compliance issues, must be immutable once created

## Step-by-Step Workflow

### Step 1: Migration Completeness Check
- Run `php artisan migrate:status` to confirm all migrations are applied.
- Verify every model has a corresponding migration using:
  ```bash
  php artisan migrate:status
  ```
- Check for any missing foreign key constraints in migration files:
  - `batches.current_holder_id` → `users.id`
  - `processor_profiles.user_id` → `users.id`
  - `logistics_profiles.user_id` → `users.id`
  - `retailer_profiles.user_id` → `users.id`
  - `checkpoints.batch_id` → `batches.id`
  - `incidents.batch_id` → `batches.id`

### Step 2: Cascade & Referential Integrity
- Confirm `onDelete` behavior is intentional:
  - Deleting a `user` should **not** silently delete their associated `batch` records (use `RESTRICT` or `SET NULL`, not `CASCADE`).
  - Deleting a profile should be `CASCADE` from user.
- Check all foreign keys have matching indexes for query performance.

### Step 3: Batch Status State Machine
Verify that the `status` column on `batches` only allows valid sequential values:
```
Processing -> In Transit -> Delivered
                         -> Recalled (at any stage)
```
- Confirm the `BatchController::updateStatus` method enforces this state machine — it must not allow backwards or invalid transitions.

### Step 4: Audit Trail Completeness
- Every custody transfer must be logged as a `checkpoint` record:
  - `user_id` (who scanned)
  - `batch_id` (what was scanned)
  - `location` / GPS coordinates
  - `scanned_at` timestamp
- Incidents must be append-only. Verify there is **no** DELETE endpoint for incidents.
- Confirm `created_at` and `updated_at` timestamps are enabled on all tables (`$timestamps = true` in models).

### Step 5: Data Exposure Check
Run a review of what the public batch endpoint (`GET /public/batches`) exposes:
- **Must expose**: batch ID, product name, status, origin processor name, halal cert number.
- **Must NOT expose**: `user.email`, `user.phone_number`, `user.password`, internal IDs of profiles.
- Use Eloquent `select()` or API Resources to restrict output.

## Security Checks
- [ ] No direct user input used in raw DB queries (SQL injection prevention).
- [ ] `is_approved` column cannot be updated via mass-assignment (`$fillable` check).
- [ ] `role` column cannot be updated via mass-assignment.
- [ ] All `findOrFail()` calls are wrapped properly to return 404 (and not 500) for missing records.
- [ ] Soft deletes (`SoftDeletes` trait) should be considered for `users` to preserve audit history.
