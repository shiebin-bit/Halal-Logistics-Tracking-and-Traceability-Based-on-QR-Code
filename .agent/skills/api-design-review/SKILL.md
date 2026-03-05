---
name: api-design-review
description: "Reviews REST API design for this project, covering route structure, HTTP semantics, response consistency, security headers, and versioning."
risk: low
source: project
date_added: "2026-03-05"
---

# API Design Review

## Overview

This skill provides a structured review of the REST API exposed by the Halal Traceability Laravel backend. Apply it when designing new endpoints, reviewing `routes/api.php`, or auditing the consistency of the API surface.

## Step-by-Step Workflow

### Step 1: Route Naming & HTTP Method Semantics
Review every route in `routes/api.php` against these rules:

| Action | HTTP Method | Example Path |
|---|---|---|
| List all | `GET` | `/batches` |
| Get one | `GET` | `/batches/{id}` |
| Create | `POST` | `/batches` |
| Full replace | `PUT` | `/batches/{id}` |
| Partial update | `PATCH` | `/batches/{id}` |
| Delete | `DELETE` | `/batches/{id}` |
| Custom action | `POST` | `/batches/update-status` |

- Flag any `GET` routes that mutate state (e.g., `GET /approve/{id}` is wrong; should be `POST`).
- Prefer noun-based resource paths (`/admin/users`, not `/admin/getUsers`).

### Step 2: Consistent Response Structure
All API responses must follow this envelope:

**Success (single resource)**:
```json
{ "data": { ... } }
```

**Success (collection)**:
```json
{ "data": [ ... ] }
```

**Success (action)**:
```json
{ "message": "User Approved" }
```

**Error**:
```json
{ "message": "Validation failed", "errors": { "field": ["..."] } }
```

- Review every `response()->json(...)` call to ensure it meets this structure.
- Flag any endpoint that returns raw arrays at the top level.

### Step 3: HTTP Status Code Accuracy
Check that the correct status codes are returned:
- `200` — Successful retrieval or action.
- `201` — Resource created successfully (add `->setStatusCode(201)` on create endpoints).
- `400` — Bad request (malformed input before validation).
- `401` — Unauthenticated (Sanctum handles this automatically).
- `403` — Authenticated but not authorized (Admin role check failures).
- `404` — Resource not found (`findOrFail` raises this automatically).
- `422` — Laravel validation failure (automatic from `$request->validate()`).
- `500` — Unexpected server error (should never be intentional).

### Step 4: Authentication & Authorization Design
- Confirm ALL non-public routes are wrapped in `auth:sanctum`.
- Confirm role-restricted routes have controller-level checks (not just comments).
- Map every route to its required role(s):

| Route Prefix | Allowed Roles |
|---|---|
| `/admin/*` | `admin` only |
| `/batches` (write) | `processor` |
| `/logistics/*` | `logistics` |
| `/reports/*` | `admin`, `processor` |
| `/user` | any authenticated |

- Flag any route missing a role check where one is required.

### Step 5: Input Filtering & Sanitization
- Confirm every POST/PUT/PATCH route validates its inputs.
- Ensure only expected fields are acted upon (use `$request->only([...])`, not `$request->all()`).
- Watch for fields like `role` or `is_approved` being accepted from client payload in update requests.

### Step 6: Security Checks
- [ ] No sensitive data (`password`, `remember_token`) returned in any response.
- [ ] Pagination applied to all list endpoints that could return large datasets.
- [ ] Rate limiting considered for public and auth endpoints.
- [ ] CORS properly configured in `config/cors.php` — not set to wildcard `*` in production.
- [ ] File upload endpoints validate MIME type and file size.
- [ ] No endpoint leaks internal stack traces (ensure `APP_ENV=production` and `APP_DEBUG=false` in production `.env`).
