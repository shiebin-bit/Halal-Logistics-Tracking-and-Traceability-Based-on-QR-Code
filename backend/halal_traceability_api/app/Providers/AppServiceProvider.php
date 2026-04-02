<?php

namespace App\Providers;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        ResetPassword::createUrlUsing(function (object $notifiable, string $token): string {
            $query = http_build_query([
                'token' => $token,
                'email' => $notifiable->getEmailForPasswordReset(),
            ]);

            $customResetUrl = config('services.frontend.password_reset_url');
            if (is_string($customResetUrl) && $customResetUrl !== '') {
                return $customResetUrl.(str_contains($customResetUrl, '?') ? '&' : '?').$query;
            }

            $frontendUrl = config('services.frontend.url');
            if (is_string($frontendUrl) && $frontendUrl !== '') {
                return rtrim($frontendUrl, '/').'/reset-password?'.$query;
            }

            return url('/reset-password?'.$query);
        });
    }
}
