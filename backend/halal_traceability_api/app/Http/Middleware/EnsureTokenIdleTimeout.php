<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

class EnsureTokenIdleTimeout
{
    private const IDLE_TIMEOUT_MINUTES = 15;

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $token = $user?->currentAccessToken();

        if ($user === null || $token === null) {
            return $next($request);
        }

        $cacheKey = 'sanctum:last-activity:'.$token->id;
        $now = now();
        $lastActivity = Cache::get($cacheKey);

        if ($lastActivity !== null && $now->diffInMinutes($lastActivity) >= self::IDLE_TIMEOUT_MINUTES) {
            Cache::forget($cacheKey);
            $token->delete();

            abort(401, 'Your session expired due to inactivity.');
        }

        Cache::put($cacheKey, $now, now()->addMinutes(self::IDLE_TIMEOUT_MINUTES + 1));

        return $next($request);
    }
}
