<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GeminiRoleAssistantService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AiAssistantController extends Controller
{
    public function chat(Request $request, GeminiRoleAssistantService $assistant)
    {
        $incomingHistory = $request->input('history', []);
        if (is_array($incomingHistory) && count($incomingHistory) > 8) {
            $request->merge([
                'history' => array_slice($incomingHistory, -8),
            ]);
        }

        $validated = $request->validate([
            'role' => ['required', 'string', Rule::in(['processor', 'logistics', 'retailer'])],
            'screen' => ['required', 'string', 'max:80'],
            'prompt' => ['required', 'string', 'min:2', 'max:2000'],
            'context' => ['nullable', 'array'],
            'history' => ['nullable', 'array'],
            'history.*.role' => ['required', 'string', Rule::in(['user', 'assistant'])],
            'history.*.content' => ['required', 'string', 'max:4000'],
        ]);

        $user = $request->user();

        abort_unless(
            $user && $user->role === $validated['role'],
            403,
            'This assistant request is not authorized for your role.'
        );

        try {
            $response = $assistant->generateReply(
                user: $user,
                role: $validated['role'],
                screen: trim((string) $validated['screen']),
                prompt: trim((string) $validated['prompt']),
                context: $validated['context'] ?? [],
                history: $validated['history'] ?? []
            );

            return response()->json($response);
        } catch (\InvalidArgumentException $exception) {
            return response()->json([
                'message' => $exception->getMessage(),
            ], 503);
        } catch (\Throwable $exception) {
            report($exception);

            return response()->json([
                'message' => 'The AI assistant is temporarily unavailable. Please try again shortly.',
            ], 502);
        }
    }
}
