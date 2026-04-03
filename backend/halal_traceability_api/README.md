# HalalTrack Backend

Laravel REST API for the HalalTrack platform.

This backend handles authentication, role authorization, batch lifecycle management, checkpoint history, manifest export, registration approval, and public traceability endpoints consumed by the Flutter app and browser clients.

## Main Responsibilities

- Sanctum-based authentication
- role and ownership authorization
- processor batch creation and certificate handling
- logistics checkpoint and incident APIs
- retailer acceptance workflow
- admin approval and governance endpoints
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
3. On `main`, the image is pushed to GHCR
4. The CD workflow can deploy that image to a VPS using Docker Compose

Production deployment assets live at the repository level:

- [backend-ci.yml](../../.github/workflows/backend-ci.yml)
- [cd.yml](../../.github/workflows/cd.yml)
- [docker-compose.prod.yml](../../deploy/compose/docker-compose.prod.yml)

## Notes

- Local testing uses SQLite in-memory, not MariaDB.
- Production secrets should stay in VPS environment files or GitHub secrets, never in the repository.
- This folder contains the application source and image definition; deployment orchestration is kept outside this folder on purpose.

For broader system context, see the root [README](../../README.md).
