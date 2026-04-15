<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'frontend' => [
        'url' => env('FRONTEND_URL'),
        'password_reset_url' => env('PASSWORD_RESET_URL'),
    ],

    'email_verification' => [
        'expires_minutes' => env('EMAIL_VERIFICATION_EXPIRES_MINUTES', 15),
        'debug_expose_code' => env('EMAIL_VERIFICATION_DEBUG_EXPOSE_CODE', true),
    ],

    'demo_access' => [
        'emails' => array_values(array_filter(array_map(
            static fn (string $email) => strtolower(trim($email)),
            explode(',', (string) env(
                'DEMO_ACCESS_EMAILS',
                'ali@processor.com,admin@halalchain.my,driver@logistics.com,manager@retailer.com'
            ))
        ))),
    ],

    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model' => env('GEMINI_MODEL', 'gemini-2.5-flash'),
        'base_url' => env('GEMINI_API_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta'),
        'timeout_seconds' => (int) env('GEMINI_TIMEOUT_SECONDS', 20),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
