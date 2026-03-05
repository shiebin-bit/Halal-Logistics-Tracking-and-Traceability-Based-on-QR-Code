---
name: halal-traceability-audit
description: "Comprehensive audit workflow for the Halal Traceability system, checking role-based access, data integrity, and compliance."
tags: ["halal", "traceability", "supply-chain", "laravel"]
risk: medium
source: project
date_added: "2026-03-05"
---

# Halal Traceability Audit Skill

## Overview

This skill provides a systematic, actionable audit of the Halal Traceability backend API. It ensures that halal certification requirements, chain-of-custody immutability, and role-based access control (RBAC) are strictly enforced throughout the system.

## When to Use This Skill

- Before major releases or deployments to production.
- When reviewing pull requests touching core models (`Batch`, `User`, profiles, `Incident`).
- When investigating reported security, tampering, or compliance incidents.
- When onboarding a new developer who needs to understand system boundaries.

---

## Phase 1: Role-Based Access Control (RBAC) Integrity

The system has 5 roles: `admin`, `processor`, `logistics`, `retailer`, `consumer`.

### Step 1.1 — Verify Endpoint Protection

Check `routes/api.php` against this role map:

| Route Prefix | Allowed Role(s) |
|---|---|
| `POST /register`, `POST /login` | Public |
| `GET /public/batches` | Public |
| `GET /admin/*` | `admin` only |
| `POST /batches`, `GET /batches` | `processor`, `admin` |
| `POST /logistics/checkpoint`, `/incident` | `logistics` |
| `GET /reports/*` | `admin`, `processor` |
| `GET /user`, `POST /user/update` | Any authenticated |

- [ ] Every non-public route is inside `Route::middleware('auth:sanctum')->group(...)`.
- [ ] Every role-restricted controller has a constructor middleware enforcing the role check — **not just a comment**.

### Step 1.2 — Verify Constructor Middleware Exists

For each role-restricted controller, confirm a constructor like this is present:
```php
public function __construct()
{
    $this->middleware(function ($request, $next) {
        if (auth()->user()->role !== 'admin') {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }
        return $next($request);
    });
}
```
- [ ] `AdminController` — requires `admin`
- [ ] `ReportController` — confirm which roles are allowed

### Step 1.3 — Approval Gate
- [ ] Users with `is_approved = 0` cannot perform business operations (create batches, submit checkpoints).
- [ ] Verify `BatchController::store` and `LogisticsController::submitCheckpoint` enforce the approval check.

---

## Phase 2: Chain of Custody Validation

### Step 2.1 — Batch Origination
- [ ] Only approved `processor` users can call `POST /batches`.
- [ ] The `halal_cert_no` written to the batch is sourced from the processor's `ProcessorProfile`, **not** from raw request input.

### Step 2.2 — Custody Transfer State Machine
Verify the allowed status transitions in `BatchController::updateStatus`:

```
Processing → In Transit → Delivered
     ↓              ↓
  Recalled       Recalled
```
- [ ] Invalid or backward transitions (e.g. `Delivered → In Transit`) are rejected with a `422` or `400` error.
- [ ] The new `current_holder_id` on a batch update is an **approved** user of the expected role.
- [ ] Checkpoints submitted by logistics (`POST /logistics/checkpoint`) are linked to assigned routes only.

### Step 2.3 — Public Consumer Endpoint Safety

Audit `GET /public/batches` response payload:
- [ ] **Exposed**: batch ID, product name, status, processor name, halal cert number, current stage.
- [ ] **Not exposed**: `user.email`, `user.phone_number`, `user.password`, internal profile IDs, any PII.
- [ ] An Eloquent `select()` clause or API Resource class is used to restrict fields.

---

## Phase 3: Incident & Data Integrity

### Step 3.1 — Incident Immutability
- [ ] There is **no** `DELETE /incidents/{id}` endpoint.
- [ ] There is **no** `PUT/PATCH /incidents/{id}` that allows status to be changed by non-admin users.
- [ ] Incident records contain: `batch_id`, `reported_by` (user_id), `description`, `status`, `created_at`.
- [ ] Only `admin` can update incident status (e.g. mark as Resolved).

### Step 3.2 — Reporting Defenses
- [ ] `GET /reports/manifest` and `GET /reports/audit-logs` enforce strict role authorization before generating output.
- [ ] Generated reports reflect live DB data — no caching that could serve stale or tampered data.
- [ ] File downloads set correct headers (`Content-Disposition: attachment`) to prevent inline execution.

---

## Common Vulnerability Patterns to Check

| Pattern | What to Look For |
|---|---|
| **Missing constructor middleware** | Controller comments say "role-checked" but no `$this->middleware(...)` exists |
| **IDOR** | `user_id` accepted as client input instead of using `Auth::id()` |
| **Approval gate bypass** | No check for `is_approved` before allowing business actions |
| **Mass assignment** | `role` or `is_approved` included in a model's `$fillable` without guard |
| **PII leakage** | Public endpoints returning full `User` models including email/phone |
| **Broken state machine** | No validation on batch status transitions |

## Security Checklist

- [ ] All admin endpoints return `403` for non-admin authenticated users.
- [ ] `password` and `remember_token` are in `$hidden` on the `User` model.
- [ ] No `dd()`, `dump()`, or `var_dump()` in production code.
- [ ] `APP_DEBUG=false` and `APP_ENV=production` in the production `.env`.
- [ ] File uploads (profile images) validate MIME type and enforce file size limits.
- [ ] Token issuance uses Sanctum `createToken()` only — no custom JWT logic.
