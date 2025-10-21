# Discord Webhooks – Design, Behavior, and Implementation Notes

Audience
- Future maintainers and contributors. This is the authoritative reference for how MacroUI integrates with Discord webhooks: UI, persistence, payload design, rate-limit handling, security, testing, and roadmap.

Status
- UI implemented (WebhooksUI.swift): toggle, Discord webhook URL, Private Server Link, validation, persistence.
- Dispatcher (network delivery) not yet implemented; this document specifies how to build it.

Contents
- 1. Goals and Non-Goals
- 2. User Experience (WebhooksUI)
- 3. Data Model and Persistence
- 4. Security and Privacy
- 5. Discord Webhook API: Key Facts
- 6. Payload Design (Biome Change Events)
- 7. Dispatcher Architecture (Async/await)
- 8. Rate Limiting and Retries
- 9. Integration with BiomesUI and LogReader
- 10. Testing Strategy
- 11. Operational Notes and Troubleshooting
- 12. Future Extensions and Migration Paths
- 13. Implementation Checklist

---

## 1) Goals and Non-Goals

Goals
- Notify a Discord channel when the Roblox biome changes.
- Respect per-biome enablement toggles in BiomesUI and a global “Enable Webhooks” toggle in WebhooksUI.
- Provide reliable delivery with basic retry/backoff and rate-limit handling.
- Keep messages readable and useful (Discord embed with color and fields).
- Avoid leaking sensitive information (webhook URLs).

Non-Goals (initial MVP)
- Multiple endpoints (we start with one).
- Queue persistence across app launches (in-memory only for MVP).
- Bot-token-based integrations (we only use Discord webhook URLs).

---

## 2) User Experience (WebhooksUI)

Screen: “Webhooks”
- Enable Webhooks [Toggle]
- Discord Webhook URL [TextField]
  - Required; must be HTTPS and look like https://discord.com/api/webhooks/…
  - Validation badge (Valid/Invalid).
- Private Server Link [TextField]
  - Required; must be HTTPS; included in messages so recipients can join quickly.
  - Validation badge (Valid/Invalid).
- Send Test [Button]
  - Enabled only when all validations pass and the toggle is on.
  - For now, only shows a readiness alert; when dispatcher is implemented, it should post a test embed.

Behavior
- Inputs are disabled and visually dimmed when the master toggle is off.
- Settings auto-save on change and load on appear.

---

## 3) Data Model and Persistence

File
- Path: ~/Library/Application Support/<bundle id>/webhooks.json
- Encoding: UTF-8

Schema (single-endpoint MVP)
- enabled: Bool
- webhookURL: String (HTTPS; Discord webhook endpoint)
- privateServerLink: String (HTTPS; Roblox private server link)

Example
{
  "enabled": true,
  "webhookURL": "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz_ABCDEF-123456",
  "privateServerLink": "https://www.roblox.com/games/1234567890/Game?privateServerLinkCode=abcdef123456"
}

Migration path (multi-endpoint future)
- Move to:
  {
    "enabled": true,
    "endpoints": [{ id, name, url, enabled, username?, avatarURL? }],
    "privateServerLink": "https://…"
  }
- Provide a one-time migration that reads the single URL and builds endpoints[0].

---

## 4) Security and Privacy

- Webhook URLs are secrets. Anyone with the URL can post to the channel.
- Storage: Application Support JSON is acceptable for MVP. Consider Keychain storage later (URL as “password”) if threat model requires it.
- Redaction: Never write full webhook URLs to logs or dumps.
  - Redact except last ~6 chars, e.g., https://discord.com/api/webhooks/…/…abcd12
  - If you must log for debugging, strip protocol/host and most of the token.
- Network entitlements (macOS App Sandbox):
  - com.apple.security.network.client = true

---

## 5) Discord Webhook API: Key Facts

Endpoint
- Standard webhook URL created in Discord: https://discord.com/api/webhooks/{id}/{token}

HTTP
- Method: POST
- Content-Type: application/json
- TLS/HTTPS required

Payloads
- Simple content:
  { "content": "Hello world" }
- Embeds (recommended):
  {
    "embeds": [
      {
        "title": "Biome Changed",
        "description": "Now: Normal",
        "color": 16777215,
        "fields": [{ "name": "Previous", "value": "Snowy", "inline": true }],
        "timestamp": "2025-09-21T18:05:00Z"
      }
    ],
    "username": "MacroUI",
    "avatar_url": "https://…/avatar.png"
  }

Limits (typical; confirm via Discord docs)
- Content length: up to 2000 chars.
- Embeds: up to 10 embeds per message.
- Per embed:
  - title: ~256 chars
  - description: ~4096 chars
  - fields: up to 25; each name ~256, value ~1024
  - footer text ~2048
  - author name ~256
- color: 24-bit integer (0xRRGGBB).
- Mentions: content supports @here/@role; ensure you’re okay with that.

Rate limiting
- Webhooks are rate limited. Expect 429 with headers:
  - X-RateLimit-Remaining
  - X-RateLimit-Reset-After (seconds, can be fractional)
- Respect Reset-After before retrying.

---

## 6) Payload Design (Biome Change Events)

Preferred: single embed with optional content
- content: Optional short prefix, e.g., “Biome update”
- embeds[0]:
  - title: “Biome Changed”
  - description: “Now: <BiomeName>”
  - color: per-biome color (convert Color -> hex -> Int)
  - fields:
    - Previous: <PrevBiome or “—”>
    - Count: <TriggerCount for current biome>
    - Private Server: <privateServerLink> (or include as content if linkification is desired)
    - App: MacroUI vX.Y (Build Z)
  - timestamp: ISO8601 UTC (e.g., 2025-09-21T18:05:00Z)

Example color conversion
- Stored as 0xRRGGBB hex (UInt32).
- Convert to Int for Discord’s color field.

Redaction in debug logs
- When logging payloads for debugging, redact webhook URL and private server link unless user explicitly enables verbose logging.

---

## 7) Dispatcher Architecture (Async/await)

Component: WebhookDispatcher (actor)
- Responsibilities:
  - Accept events (enqueue)
  - Serialize payloads
  - POST with URLSession (async/await)
  - Handle rate limits and retries
  - Emit debug messages via callback (wired to BiomesUI console)

Public API (conceptual)
- func configure(settings: WebhooksSettings)
- func enqueueBiomeChange(event: BiomeDetectionEvent, snapshot: BiomeStateSnapshot)
- func sendTest() async throws

Internals
- Queue: [DispatchItem] with type (biomeChange/test) and prepared payload
- Draining task: serially sends items; applies small inter-send delay (e.g., 300–500 ms)
- Retry policy: see section 8
- Redaction helper for logs
- Validation guard: drop/skip if settings.enabled == false or URL invalid

Threading model
- Use actor isolation for queue and mutable state
- Use URLSession.shared or a dedicated URLSession with reasonable timeout (e.g., 10s)

---

## 8) Rate Limiting and Retries

Policy (MVP)
- For 2xx: success; continue.
- For 4xx (except 429): treat as permanent failure; log, drop item.
- For 429: parse Reset-After (seconds). Sleep for that duration + small jitter, then retry.
- For 5xx or network errors/timeouts: retry with exponential backoff and jitter up to N attempts (e.g., 3 attempts: 1s, 2s, 4s).
- Add a minimal inter-request delay (e.g., 300 ms) to avoid bursts.

Cooldown (optional)
- If you observe flip-flops in biomes (e.g., Normal -> Snowy -> Normal rapidly), add a cooldown (e.g., 10–30 seconds) to suppress notifications for the same biome within that window.

---

## 9) Integration with BiomesUI and LogReader

Flow
- LogReader detects biome changes and calls onBiomeChange(event).
- BiomesUI.handleBiomeChange:
  - Updates trigger counts/history
  - If global webhooks enabled AND per-biome webhookEnabled == true:
    - Build a snapshot (previous biome, current biome, color hex, counts, app version/build, timestamp, privateServerLink)
    - Call dispatcher.enqueueBiomeChange(event, snapshot)
- WebhooksUI:
  - Edits WebhooksSettings (enabled, webhookURL, privateServerLink)
  - On change: save and reconfigure dispatcher

Debug visibility
- Dispatcher emits lines to onDebug callback:
  - “Webhook queued: biome=Normal”
  - “POST 200 OK”
  - “429 rate limited, retry in 1.2s”
  - “Permanent failure 400: Bad Request”
- BiomesUI appends these to the “Biome Log”.

---

## 10) Testing Strategy

Local tests
- Use a disposable Discord webhook URL.
- Or stand up a local HTTP server (e.g., Python http.server) and point dispatcher there while developing; inspect payloads.

Scenarios to cover
- Valid send (200/204)
- Invalid URL (fail validation; no send)
- 400 Bad Request (malformed payload): ensure permanent failure path
- 404 (deleted webhook): permanent failure
- 429 (rate limit): ensure Reset-After is respected and retry works
- 5xx (server errors): backoff retries up to N attempts
- Network timeout: retry/backoff then drop
- Unicode/emoji in content/description
- Long values truncated or field counts limited per Discord constraints

Manual cURL examples
- Content:
  curl -X POST -H "Content-Type: application/json" -d '{"content":"Test from curl"}' "https://discord.com/api/webhooks/ID/TOKEN"
- Embed:
  curl -X POST -H "Content-Type: application/json" -d '{"embeds":[{"title":"Biome Changed","description":"Now: Normal","color":65280}]}' "https://discord.com/api/webhooks/ID/TOKEN"

---

## 11) Operational Notes and Troubleshooting

Common issues
- 404 Not Found: webhook deleted or URL mistyped.
- 401/403: invalid token or permissions changed (rare for webhooks).
- 429 Too Many Requests: respect Reset-After header with a sleep.
- Messages not appearing:
  - Validate URL and that the channel exists
  - Check that the embed payload respects Discord limits
  - Verify App Sandbox network entitlement is present

Logging
- Keep BiomesUI “Biome Log” free of secrets; redact URLs.
- Consider a “Verbose webhook logging” toggle if deeper diagnostics are needed.

---

## 12) Future Extensions and Migration Paths

Multiple endpoints
- Replace single webhookURL with endpoints: [WebhookEndpoint]
- Add per-feature routing (biomes -> endpoint(s), merchants -> endpoint(s))

Queue persistence
- Save pending items to ~/Library/Application Support/.../webhook-queue.json on graceful shutdown and reload on startup.

Templates
- Allow users to customize message templates (content/embeds) per feature.

Keychain
- Store webhook URLs in Keychain, keeping only display names in JSON.

Audit log
- Persist a local delivery log with status and response snippets (redacted).

---

## 13) Implementation Checklist

Before coding
- Add com.apple.security.network.client entitlement.
- Confirm WebhooksUI validation meets your needs (both fields required, HTTPS).

Dispatcher
- Create WebhookDispatcher actor:
  - configure(settings:)
  - enqueueBiomeChange(event:snapshot:)
  - sendTest()
- Implement queue drain loop with:
  - Inter-request delay
  - Retry/backoff
  - 429 Reset-After handling
- Build payloads:
  - Embed with color from hex
  - Fields: previous, current, count, privateServerLink, app/version, timestamp
- Redaction helpers for logs

Integration
- Inject dispatcher where needed (singleton or EnvironmentObject).
- BiomesUI.handleBiomeChange:
  - Check global enable + per-biome toggle
  - Build snapshot and enqueue
- WebhooksUI.Send Test:
  - Call dispatcher.sendTest() and show success/failure

Testing
- Add Swift tests for payload construction and rate-limit handling (mock URLProtocol).
- Manual cURL validation.

Docs
- Keep this document updated as behavior evolves.

