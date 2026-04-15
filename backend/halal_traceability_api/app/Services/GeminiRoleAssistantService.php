<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class GeminiRoleAssistantService
{
    public function __construct(
        private readonly RoleAssistantMonthlySummaryService $monthlySummaryService
    ) {
    }

    public function generateReply(
        User $user,
        string $role,
        string $screen,
        string $prompt,
        array $context,
        array $history
    ): array {
        $apiKey = (string) config('services.gemini.api_key');
        if (trim($apiKey) === '') {
            throw new \InvalidArgumentException('The AI assistant is not configured yet. Add GEMINI_API_KEY on the backend.');
        }

        $model = (string) config('services.gemini.model', 'gemini-2.5-flash');
        $baseUrl = rtrim((string) config('services.gemini.base_url', 'https://generativelanguage.googleapis.com/v1beta'), '/');
        $timeout = (int) config('services.gemini.timeout_seconds', 20);

        $response = Http::timeout($timeout)
            ->acceptJson()
            ->withHeaders([
                'x-goog-api-key' => $apiKey,
            ])
            ->post("{$baseUrl}/models/{$model}:generateContent", [
                'contents' => [[
                    'parts' => [[
                        'text' => $this->buildPrompt(
                            user: $user,
                            role: $role,
                            screen: $screen,
                            prompt: $prompt,
                            context: $context,
                            history: $history
                        ),
                    ]],
                ]],
                'generationConfig' => [
                    'temperature' => 0.45,
                    'topP' => 0.9,
                    'maxOutputTokens' => 500,
                ],
            ]);

        if ($response->failed()) {
            throw new \RuntimeException('Gemini upstream call failed with status '.$response->status());
        }

        $text = $this->extractText($response->json());
        if ($text === '') {
            throw new \RuntimeException('Gemini returned an empty response.');
        }

        return [
            'message' => $text,
            'suggestions' => $this->suggestionsFor($role, $screen),
            'disclaimer' => 'AI guidance supports operations only. Confirm final halal, safety, and approval decisions in the official workflow.',
        ];
    }

    private function buildPrompt(
        User $user,
        string $role,
        string $screen,
        string $prompt,
        array $context,
        array $history
    ): string {
        $historyLines = collect(array_slice($history, -6))
            ->map(function (array $message): string {
                $speaker = $message['role'] === 'assistant' ? 'Assistant' : 'User';

                return $speaker.': '.trim((string) $message['content']);
            })
            ->implode("\n");

        $contextJson = json_encode($context, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        $contextJson = $contextJson === false ? '{}' : $contextJson;
        $contextJson = Str::limit($contextJson, 6000, "\n...[truncated]");
        $monthlySummaryJson = json_encode(
            $this->monthlySummaryService->buildFor($user),
            JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
        );
        $monthlySummaryJson = $monthlySummaryJson === false ? '{}' : $monthlySummaryJson;
        $monthlySummaryJson = Str::limit($monthlySummaryJson, 4000, "\n...[truncated]");

        return trim(implode("\n\n", [
            $this->baseInstruction(),
            $this->roleInstruction($role),
            'Current screen: '.$screen,
            'Current user: '.(string) ($user->name ?? 'Partner'),
            'Current context JSON:'."\n".$contextJson,
            'Current month operational summary:'."\n".$monthlySummaryJson,
            $historyLines !== '' ? 'Recent conversation:'."\n".$historyLines : 'Recent conversation: none',
            'Latest user request:'."\n".$prompt,
            'Response rules:'."\n".
            '- Be concise, helpful, and grounded in the provided context only.'."\n".
            '- Give practical next-step guidance for the current workflow.'."\n".
            '- Use the monthly summary when the user asks about this month, recent workload, or dashboard-level activity.'."\n".
            '- If the context is incomplete, say what is missing instead of guessing.'."\n".
            '- Do not claim to submit approvals, checkpoints, or rejections on behalf of the user.'."\n".
            '- Do not mention model limitations unless directly relevant.'."\n".
            '- Prefer 2 to 5 short paragraphs or bullets, not a long essay.',
        ]));
    }

    private function baseInstruction(): string
    {
        return 'You are HalalTrace Role Assistant, an operational AI helper inside a halal logistics and traceability system. Your job is to explain the current workflow, summarize the current record, draft concise operational wording, and suggest the next safe step.';
    }

    private function roleInstruction(string $role): string
    {
        return match ($role) {
            'processor' => 'Processor assistant focus: explain batch creation fields, certificate information, batch readiness, QR preparation, and processing-stage next actions.',
            'logistics' => 'Logistics assistant focus: summarize shipment movement, checkpoint meaning, temperature handling, incident wording, and delivery-state next actions.',
            'retailer' => 'Retailer assistant focus: explain receiving checks, acceptance vs rejection considerations, inventory interpretation, and concise rejection-note drafting.',
            default => 'Provide concise operational assistance.',
        };
    }

    private function extractText(array $payload): string
    {
        $parts = $payload['candidates'][0]['content']['parts'] ?? [];
        $segments = [];

        foreach ($parts as $part) {
            $text = trim((string) ($part['text'] ?? ''));
            if ($text !== '') {
                $segments[] = $text;
            }
        }

        return trim(implode("\n", $segments));
    }

    private function suggestionsFor(string $role, string $screen): array
    {
        return match ($screen) {
            'processor.create_batch' => [
                'Check whether this batch draft is complete.',
                'Explain the certificate fields I still need.',
                'Summarize this draft batch in a short note.',
            ],
            'processor.inventory' => [
                'Summarize the current processor inventory view.',
                'Summarize my batch activity this month.',
                'Explain the current status labels in this list.',
            ],
            'processor.batch_detail' => [
                'Summarize this batch for a supervisor update.',
                'Explain what the current batch status means.',
                'What should the processor do next on this batch?',
            ],
            'logistics.routes' => [
                'Summarize my assigned shipments.',
                'Summarize my logistics activity this month.',
                'Explain which route looks highest priority.',
            ],
            'logistics.checkpoint_scanner' => [
                'Explain what I should confirm before submitting a checkpoint.',
                'Draft a concise checkpoint note from this screen.',
                'What information looks missing here?',
            ],
            'logistics.route_detail' => [
                'Summarize this route detail for dispatch.',
                'Explain any alert signals in this route.',
                'Draft an incident note based on this shipment state.',
            ],
            'retailer.receive_inspect' => [
                'Explain the difference between accept and reject here.',
                'Check which receiving inputs still look incomplete.',
                'Draft a concise rejection reason from this context.',
            ],
            'retailer.incoming' => [
                'Summarize the incoming shipments on this screen.',
                'Summarize my retailer activity this month.',
                'Which shipment should I inspect first?',
            ],
            'retailer.inventory' => [
                'Summarize my delivered inventory.',
                'Summarize what changed this month for the retailer.',
                'Explain what this inventory data says operationally.',
            ],
            default => [
                'Summarize the current screen for me.',
                'What should I do next here?',
                'Explain the important fields on this page.',
            ],
        };
    }
}
