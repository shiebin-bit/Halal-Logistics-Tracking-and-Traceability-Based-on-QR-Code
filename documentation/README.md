# Documentation Index

This directory is organized by document type so reports, deployment notes, proposals, and database assets stay separated.

## Structure

- `database/`
  SQL dumps and database-related reference files.
- `deployment/`
  VPS, Docker, Nginx, CI/CD, and production rollout guides.
- `proposals/`
  Feature proposals and exploratory notes.
- `reports/`
  Status reports, audits, readiness reviews, and completion summaries.

## Key Documents

- [AI Assistant And System Verification Report](reports/ai_assistant_and_system_verification_report.md)
- [Enterprise System Explanation Report](reports/enterprise_system_explanation_report.md)
- [Current Improvement Roadmap](reports/current_improvement_roadmap.md)
- [Deployment Guide](deployment/vps_docker_nginx_github_actions_deployment_guide.md)
- [Requirements Completion Report](reports/requirements_completion_report.md)
- [System Fix Log and Readiness Review](reports/system_fix_log_and_readiness_review.md)
- [Production Readiness Security Audit](reports/production_readiness_security_audit.md)
- [Live Shipment Map Proposal](proposals/live_shipment_map_proposal.md)

## Current Status Note

- Core multi-role demo flows are implemented and locally runnable.
- Frontend verification is now passing with `flutter analyze` and `flutter test`.
- The Gemini-backed drawer-based AI assistant is implemented for `processor`, `logistics`, and `retailer`.
- The shared shipment route map has been implemented with OpenStreetMap tiles and checkpoint coordinates.
- The main Docker SQL dump now includes map-friendly demo data for the primary presentation accounts.
- The live Docker backend, database, and seeded demo flows have been re-verified after the AI assistant rollout.
- Backend automated verification is currently fully passing again with `php artisan test`.
- Remaining open work is mainly production-facing deployment, SMTP, and rollout hardening.

## Database Assets

- [halaltrack_db.sql](database/halaltrack_db.sql)
  Docker initialization dump used for fresh MariaDB volumes, including the main demo-user dataset.
