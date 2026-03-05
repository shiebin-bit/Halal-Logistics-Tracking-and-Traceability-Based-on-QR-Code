---
name: laravel-api-best-practices
description: "Enforces Laravel API coding standards including validation, authorization, response formatting, error handling, and security hardening for this project."
risk: low
source: project
date_added: "2026-03-05"
---

# Laravel API Best Practices

## Overview

This skill defines the coding standards and review checklist for all Laravel API controllers and routes in this project. Apply it when writing new endpoints, reviewing pull requests, or refactoring existing controllers.

## Step-by-Step Workflow

### Step 1: Route Definition
- All routes must be declared in `routes/api.php`.
- Public routes (no auth) are placed **before** the `auth:sanctum` middleware group.
- All authenticated routes must be inside `Route::middleware('auth:sanctum')->group(...)`.
- Use RESTful naming conventions (`GET /batches`, `POST /batches`, `GET /batches/{id}`).

### Step 2: Request Validation
- **Never** trust raw request input without validation.
- Use `$request->validate([...])` or a dedicated `FormRequest` class.
- Validate all fields including type, max length, and enum constraints.
- Example:
  ```php
  $request->validate([
      'role' => 'required|in:processor,logistics,retailer,consumer',
      'email' => 'required|email|unique:users,email',
  ]);
  ```

### Step 3: Authorization
- Role checks must be enforced in the **controller constructor** using closure middleware:
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
- Never implement authorization with bare `if` checks inside action methods only—use constructor middleware for controller-wide protection.
- Use `Auth::id()` or `$request->user()->id` for the current user's ID. **Never** accept `user_id` as a client-supplied parameter for identity.

### Step 4: Response Formatting
- All responses must return JSON via `response()->json(...)`.
- Use consistent structure:
  - Success: `{ "data": ..., "message": "..." }`
  - Error: `{ "message": "...", "errors": { ... } }` (with appropriate HTTP status code).
- Common HTTP status codes to use:
  - `200` OK — retrieval / successful action
  - `201` Created — resource created
  - `403` Forbidden — authorization failure
  - `404` Not Found — resource not found (`findOrFail` handles this automatically)
  - `422` Unprocessable Entity — validation failure

### Step 5: Eloquent & Database Safety
- Use `findOrFail($id)` instead of `find($id)` when the resource must exist.
- Use `$fillable` in models to prevent mass-assignment vulnerabilities.
- `is_approved` and `role` must **not** be mass-assignable via untrusted user-facing requests.
- All sensitive queries should leverage Eloquent scopes or filtered `where()` clauses.

### Step 6: Security Checks
- [ ] No raw SQL queries (`DB::statement`, `DB::select` with unsanitized input).
- [ ] Passwords are always hashed (Laravel's `hashed` cast or `Hash::make()`).
- [ ] Tokens are issued via Sanctum (`createToken()`), not custom JWT implementation.
- [ ] Sensitive fields (`password`, `remember_token`) are in the `$hidden` model array.
- [ ] No debug output (`dd()`, `dump()`, `var_dump()`) in production code.
- [ ] `Storage::disk('public')` used for user-uploaded files, not `public_path()` directly.
