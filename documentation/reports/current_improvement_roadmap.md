# HalalTrack Current Improvement Roadmap

Date: 2026-04-04

## Purpose

This document consolidates the currently relevant improvement direction for the project based on the latest project reports and proposals.

It is intended to replace the need to infer "what is next" across multiple older documents.

## Source Priority

This roadmap is based on the newest documents first:

1. `documentation/reports/requirements_completion_report.md` (2026-04-04)
2. `documentation/reports/system_fix_log_and_readiness_review.md` (2026-03-30)
3. `documentation/proposals/live_shipment_map_proposal.md` (2026-03-30)
4. `documentation/deployment/vps_docker_nginx_github_actions_deployment_guide.md`

Older guidance in `documentation/reports/production_readiness_security_audit.md` (2026-03-09) should be treated as partially historical because several blockers described there were already resolved in later documents.

## Current Baseline

The project is in a strong demo-ready state, with the main mandatory flows already implemented:

- role-based backend authorization
- onboarding approval workflow
- registration document handling
- public consumer traceability
- checkpoint-based timeline rendering
- checkpoint-based route maps on OpenStreetMap tiles across consumer, admin, and logistics detail flows
- manifest PDF export
- Dockerized backend development flow
- CI/CD scaffolding for backend, frontend, and image build
- passing `flutter analyze`, `flutter test`, and backend automated tests

The roadmap now focuses on three layers:

1. production and deployment readiness
2. verification and confidence hardening
3. next visible product enhancement

## Recommended Improvement Order

### Phase 1: Close Production and Handoff Gaps

This is the highest-priority path if the goal is real deployment, cleaner handoff, or safer final submission.

Focus:

- finalize VPS deployment secrets and runtime configuration
- configure real SMTP credentials and verified mail/domain records
- validate HTTPS, domain routing, and external API behavior after deployment
- remove or harden demo-only shortcuts before real release

Why this phase comes first:

- these items are still explicitly open in the latest project status documents
- they affect real delivery more than feature completeness
- they reduce risk without changing core business behavior

### Phase 2: Complete Validation and Tooling Confidence

This phase improves trust in the system rather than adding new user-facing capability.

Current status:

- completed locally in the repository baseline

Completed focus:

- complete stable `flutter analyze` verification
- complete stable `flutter test` verification
- confirm backend and frontend CI pass consistently
- document the final verification baseline for handoff or submission

Why this phase matters:

- verification should now be preserved as a passing baseline rather than treated as an unresolved gap
- documented test confidence still matters for handoff, maintenance, and presentation credibility

### Phase 3: Build the Next High-Impact Enhancement

The clearest next feature direction is `Live Shipment Map`.

Current status:

- shared route map implemented
- integrated into consumer batch detail
- reused in admin batch detail
- extended into logistics route detail

Delivered scope:

1. implement a shared route map component
2. integrate it into the consumer batch detail screen
3. reuse the same component in admin batch detail
4. extend the same route visibility into logistics route detail

Important implementation note:

- the current feature is a checkpoint-based geographic route map
- it uses real OpenStreetMap tiles and stored checkpoint coordinates
- it is not continuous real-time GPS streaming

Why this feature is next:

- the system already stores real logistics coordinates
- the data layer is mostly ready
- the main missing piece is presentation
- this creates strong demo value with relatively controlled implementation risk

### Phase 4: Expand Optional Product Depth

These items are meaningful, but they are not the current mainline path.

Optional enhancements already identified in existing documentation:

- richer admin export, filtering, and reporting tools
- fuller certificate history and version management
- advanced route deviation analytics
- richer delivery analytics and reporting visuals

These should be treated as follow-on improvements after the map feature or after deployment readiness is complete, depending on project goals.

## Practical Next-Step Decision

Choose the next track based on the actual target:

- If the target is `real deployment`, do Phase 1 first.
- If the target is `submission confidence`, keep Phase 2 as the verification baseline and document it clearly.
- If the target is `stronger presentation/demo impact`, polish the current route map UX rather than expanding into full live GPS tracking.

## Current Summary

The most accurate "current improvement route" is:

1. finish production-facing readiness items
2. preserve the now-passing verification baseline
3. polish the existing checkpoint-based route map only if presentation value is needed
4. defer analytics/reporting expansion until after the main roadmap above

This is the most consistent interpretation of the latest project documentation.
