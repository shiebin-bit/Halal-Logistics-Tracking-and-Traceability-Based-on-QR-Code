<?php

namespace Tests\Feature;

// use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    /** The debug root endpoint accepts POST requests and echoes payload data. */
    public function test_the_root_debug_endpoint_accepts_post_requests(): void
    {
        $response = $this->postJson('/', [
            'email' => 'qa@example.com',
        ]);

        $response
            ->assertStatus(200)
            ->assertJsonPath('message', 'User registered successfully')
            ->assertJsonPath('data.email', 'qa@example.com');
    }
}
