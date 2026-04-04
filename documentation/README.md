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

- [Current Improvement Roadmap](reports/current_improvement_roadmap.md)
- [Deployment Guide](deployment/vps_docker_nginx_github_actions_deployment_guide.md)
- [Requirements Completion Report](reports/requirements_completion_report.md)
- [System Fix Log and Readiness Review](reports/system_fix_log_and_readiness_review.md)
- [Production Readiness Security Audit](reports/production_readiness_security_audit.md)
- [Live Shipment Map Proposal](proposals/live_shipment_map_proposal.md)

## Current Status Note

- Core multi-role demo flows are implemented and locally runnable.
- Frontend verification is now passing with `flutter analyze` and `flutter test`.
- The shared shipment route map has been implemented with OpenStreetMap tiles and checkpoint coordinates.
- Remaining open work is mainly production-facing deployment, SMTP, and rollout hardening.

## Database Assets

- [halaltrack_db.sql](database/halaltrack_db.sql)
