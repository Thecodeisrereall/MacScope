# MacroUI Documentation (Source for GPT)

This single file consolidates concise, structured notes for every component in the app. Feed this to your documentation tool (e.g., GPT-5 Pro) to generate full API docs, usage guides, and architectural overviews. The notes are intentionally terse and implementation-agnostic to keep source files clean.

Table of Contents
- 0) Overview
- 1) MacroUIApp
- 2) ContentView
- 3) UITemplatesStruct (BoxedSection)
- 4) BiomesUI
- 5) LogReader
- 6) MariUI
- 7) JesterUI
- 8) AurasUI
- 9) MerchantsUI
- 10) WebhooksUI
- 11) GeneralUI
- 12) Integration Guide: BiomesUI + LogReader
- 13) Testing Matrix and Ideas
- 14) Future Roadmap
- 15) Discord Webhooks Plan (MVP design)
- 16) RollingUI

...

## 16) RollingUI

Purpose
- Configure “Auto Pop” behavior for specific potions when certain biomes are active (Glitched, Dreamspace).

Model
- RollingSettings (Codable):
  - autoPopInGlitched: Bool
  - autoPopInDreamspace: Bool
  - glitchedItems: [String: AutoPopItem]
  - dreamspaceItems: [String: AutoPopItem]
- AutoPopItem (Codable): { use: Bool, amount: Int }

UI Structure
- BoxedSection “Rolling Settings”
  - Glitched group:
    - Title “Auto Pop in Glitched” where “Glitched” is colored #64FC64.
    - Per-item rows:
      - Potion of Bound (max 1) — gradient 0x5CB3FF → 0x3C8DFF (vertical)
      - Heavenly Potion (max 1) — gradient 0xFF7CB9 → 0xFF5FA2 (vertical)
      - Oblivion Potion (max 1) — gradient 0x6A5BB0 → 0x4F4386 (vertical)
      - Godlike Potion (max 999) — three-color HORIZONTAL gradient #FFF800 → #32FFFF → #FF0000
    - Each row: styled name, “max N”, amount TextField (0...max), toggle (on => amount ≥ 1; off => amount = 0).
    - Rows dim when master toggle is off.
  - Dreamspace group:
    - Title “Auto Pop in Dreamspace” where “Dreamspace” is colored #EA6CBC.
    - Same items/rows and behavior as Glitched, backed by dreamspaceItems.

Persistence
- File: ~/Library/Application Support/<bundle id>/rollingsettings.json
- On appear: loadSettings(), ensure items exist and clamp amounts.
- On change: clamp, then save.
- On disappear / background: save.

Future Enhancements
- Wire to LogReader biome changes:
  - When biome transitions to .glitched or .dreamspace, trigger the configured pops.
- Add per-item max customization if needed.
- Add a “Rolling Log” with actions similar to other feature logs.
