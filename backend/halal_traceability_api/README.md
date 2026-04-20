# HalalTrack Backend

Laravel REST API for the HalalTrack platform.

This backend handles authentication, role authorization, batch lifecycle management, checkpoint history, manifest export, registration approval, and public traceability endpoints consumed by the Flutter app and browser clients.

## Main Responsibilities

- Sanctum-based authentication
- role and ownership authorization
- processor batch creation and certificate handling
- logistics checkpoint and incident APIs
- logistics assigned-route summaries and batch-detail data for route maps
- logistics summary temperature formatting that ignores placeholder `0` readings in route previews
- retailer acceptance workflow
- admin approval and governance endpoints
- Gemini-backed role assistant proxy for `processor`, `logistics`, and `retailer`
- Brevo-compatible SMTP mail delivery through Laravel Mailer
- public batch listing and detail endpoints
- manifest PDF generation

## Stack

- PHP 8.2
- Laravel 12
- Laravel Sanctum
- MariaDB
- DOMPDF
- PHPUnit

## Local Development

This backend is usually run through the repository root Docker setup.

From the project root:

```powershell
docker compose up -d --build
docker exec halaltrack_app php artisan migrate --force
```

To rebuild the API container after backend code changes while keeping the existing database volume:

```powershell
docker compose up -d --build app nginx
```

If you want to work directly inside this folder without Docker:

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

## Testing

Run the backend test suite:

```powershell
composer test
```

Test configuration uses SQLite in memory through [phpunit.xml](./phpunit.xml).

Current verification status:

- `php artisan test` passes
- the affected upload tests are stabilized for this Windows-based local environment
- the live Docker API has been re-verified after the AI assistant rollout

## Useful Composer Scripts

- `composer setup`
- `composer dev`
- `composer test`

## Structure

```text
app/
config/
database/
public/
resources/
routes/
tests/
Dockerfile
phpunit.xml
composer.json
```

## Deployment Model

The current repository flow is:

1. GitHub Actions runs backend tests
2. GitHub Actions builds the Docker image from [Dockerfile](./Dockerfile)
3. Trivy scans the backend image and repository configuration, then uploads SARIF/report artifacts
4. On `main`, the image is pushed to GHCR
5. The CD workflow can deploy that image to a VPS using Docker Compose

Production deployment assets live at the repository level:

- [backend-ci.yml](../../.github/workflows/backend-ci.yml)
- [cd.yml](../../.github/workflows/cd.yml)
- [docker-compose.prod.yml](../../deploy/compose/docker-compose.prod.yml)

## Runtime Environment

The backend reads operational settings from `.env` at container runtime. The Docker image should not contain real secrets.

Important runtime values:

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://halaltrack.shiebindev.com

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=halaltrack_db
DB_USERNAME=your_database_user
DB_PASSWORD=your_database_password

MAIL_MAILER=smtp
MAIL_SCHEME=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=your_brevo_smtp_login
MAIL_PASSWORD=your_brevo_smtp_key
MAIL_FROM_ADDRESS="no-reply@shiebindev.com"
MAIL_FROM_NAME="${APP_NAME}"

GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-3.1-flash-lite-preview
```

For Brevo on port `587`, use `MAIL_SCHEME=smtp`. Use `smtps` only when a provider requires port `465`.

The backend image is protected by [.dockerignore](./.dockerignore), which excludes real `.env` files, runtime logs, cache, and uploaded storage files from the build context.

## Notes

- Local testing uses SQLite in-memory, not MariaDB.
- Core API flows for the FYP demo are implemented and covered by passing backend tests.
- The AI assistant is exposed through `POST /api/assistant/chat` and keeps the Gemini API key server-side in Laravel.
- Assistant prompts are role-restricted and context-aware; they are not unrestricted natural-language database queries.
- SMTP delivery is configured through Laravel Mailer and has been smoke-tested with Brevo.
- The repository-level Docker SQL dump contains demo-ready shipment checkpoints for the main presentation accounts.
- VPS runtime secrets and external deployment validation remain deployment tasks rather than missing API business logic.
- Production secrets should stay in VPS environment files or GitHub secrets, never in the repository.
- This folder contains the application source and image definition; deployment orchestration is kept outside this folder on purpose.

For broader system context, see the root [README](../../README.md).
