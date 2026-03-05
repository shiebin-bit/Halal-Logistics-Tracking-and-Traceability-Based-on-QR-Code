---
name: flutter-ui-design
description: "Design and implement high-quality Flutter UI screens with modern layout, responsive design, and strong visual hierarchy."
risk: low
source: project
date_added: "2026-03-05"
---

# Flutter UI Design Skill

## Overview

This skill guides the creation of production-grade Flutter user interfaces for the Halal Traceability app. Apply it when building new screens, refactoring existing widgets, or polishing the visual design.

## When to Use

- Building new screens (dashboards, forms, detail pages, QR scanner views).
- Reviewing or refactoring existing screens under `lib/screens/`.
- Creating shared reusable widgets.
- Establishing or updating the app-wide design system.

---

## Design Principles

### 1. Material Design 3

The app already uses Material 3 with a **Forest Green** seed color (`0xFF1B5E20`).

- Use `Theme.of(context).colorScheme` for colors — never hardcode hex values in widgets.
- Use `Theme.of(context).textTheme` for typography (e.g., `titleLarge`, `bodyMedium`).
- Follow Material 3 spacing: `4`, `8`, `12`, `16`, `24`, `32` logical pixels.
- Use `FilledButton`, `OutlinedButton`, `Card.filled()` — the M3 widget variants.

### 2. Widget Composition

- Extract repeated UI patterns into reusable widgets (e.g., `StatusBadge`, `BatchCard`, `DashboardStatTile`).
- Keep `build()` methods under ~40 lines — extract helper methods or child widgets.
- Use `const` constructors on all stateless widgets and static children.

### 3. Responsive Layout

- Use `MediaQuery.sizeOf(context)` for screen-aware sizing.
- `Expanded` and `Flexible` inside `Row`/`Column` for proportional layouts.
- `LayoutBuilder` for widgets that need to adapt to their parent constraint.
- Test on both 360dp-width (small phone) and 412dp-width (standard phone) at minimum.

### 4. Visual Hierarchy

- Primary actions use `colorScheme.primary` with `FilledButton`.
- Secondary actions use `OutlinedButton`.
- Section headers: `textTheme.titleMedium` with `SizedBox(height: 16)` spacing above.
- Cards: Use `Card` with `elevation: 0` and `shape: RoundedRectangleBorder(borderRadius: 12)` for modern flat look.

### 5. Color & State Feedback

For batch status and role-specific screens, use consistent semantic colors:

| Meaning | Color |
|---|---|
| Active / Approved | `Colors.green` shades |
| Pending / In Transit | `Colors.orange` shades |
| Error / Recalled | `Colors.red` shades |
| Info / Neutral | `Colors.blue` shades |

---

## Step-by-Step Workflow

### Step 1: Understand the Screen
- Which role sees this screen? (`admin`, `processor`, `logistics`, `retailer`, `consumer`)
- What data does it display? (batches, stats, user profiles, incidents)
- What actions can the user take? (create, approve, scan, report)

### Step 2: Skeleton Layout
- Start with `Scaffold` → `AppBar` + `body`
- Use `SafeArea` → `SingleChildScrollView` or `ListView` as the body.
- Place primary action in a `FloatingActionButton` if applicable.

### Step 3: Build Sections Top-to-Bottom
- Stats row → use `Row` of `Card` widgets.
- Data lists → use `ListView.builder` with extracted `ListTile` or card widgets.
- Forms → use `Form` + `TextFormField` with consistent `InputDecorationTheme`.

### Step 4: Apply Theme
- Pull all colors from `Theme.of(context).colorScheme`.
- Pull all text styles from `Theme.of(context).textTheme`.
- Use the `InputDecorationTheme` already defined in `main.dart` — don't override per-field.

### Step 5: Add Polish
- Loading: Show `CircularProgressIndicator` centered while API calls resolve.
- Empty state: Show an icon + text message instead of a blank screen.
- Error state: Show a `SnackBar` or inline error with retry button.
- Micro-animations: Use `AnimatedContainer`, `AnimatedOpacity`, or `Hero` for transitions.

---

## Security-Relevant UI Checks

- [ ] Login screens obscure password with `obscureText: true`.
- [ ] Token is **never** shown in the UI or debug console.
- [ ] Role-based navigation guards prevent users from typing a route URL for another role's dashboard.
- [ ] Profile image uploads validate file size client-side before sending.
- [ ] All text inputs that submit to the API use `TextFormField` with a validator.
