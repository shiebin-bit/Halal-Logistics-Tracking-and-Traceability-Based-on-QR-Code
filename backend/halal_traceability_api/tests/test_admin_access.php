<?php

require __DIR__ . '/../vendor/autoload.php';
$app = require_once __DIR__ . '/../bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Http\Request;

// 1. Create a non-admin user
$user = User::firstOrCreate([
    'email' => 'testprocessor@example.com'
], [
    'name' => 'Test Processor',
    'password' => bcrypt('password123'),
    'role' => 'processor',
    'phone_number' => '1234567890',
    'is_approved' => 1
]);

// 2. Generate a token
$token = $user->createToken('test-token')->plainTextToken;
echo "Token: $token\n";

// 3. Make a request to /api/admin/stats
$request = Request::create('/api/admin/stats', 'GET');
$request->headers->set('Authorization', "Bearer $token");
$request->headers->set('Accept', 'application/json');

$response = app()->handle($request);

echo "Status Code: " . $response->getStatusCode() . "\n";
echo "Response Content: " . $response->getContent() . "\n";
