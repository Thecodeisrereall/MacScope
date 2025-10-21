# BiomesUI Documentation Source

Purpose
- Manage per-biome settings (counts, webhook toggles, color) and show a recent history of biome events.
- Settings persist to disk; history is in-memory per run.

Key Types
- Biome (enum): normal, windy, snowy, rainy, sandstorm, hell, starfall, corruption, null, glitched, dreamspace.
- BiomeState (struct): UI state per biome (color, triggerCount, webhookEnabled).
- BiomeSettingsFile/BiomeSettingsItem (Codable): File model for settings persistence.
- BiomeEvent (struct): In-memory event record {date, biome}.

Storage
- Settings file: ~/Library/Application Support/<bundle id>/biomesettings.json
- On load:
  - Try reading biomesettings.json.
  - If missing or unreadable, try bundled seed BiomeSettings.json.
  - If both fail, initialize defaults and create the file.
- Encoding compatibility:
  - Decoding accepts top-level keys "items" or "biomes".
  - Encoding always writes "biomes".

Color Handling
- Persist color as 0xRRGGBB (UInt32).
- Convert Color <-> hex via NSColor in sRGB color space.
- Omit alpha in persistence.

UI Structure
- Uses BoxedSection (from UITemplatesStruct.swift) to group content.
- Two sections:
  1) Biome Detection: Flat list of all biomes with color, count, webhook toggle.
  2) Biome History: Scrollable list (most recent first), in-memory only.

Data Hygiene
- On appear:
  - loadSettings()
  - ensureAllBiomesExistAndClamp():
    - Ensure all enum cases exist in `states`.
    - Clamp triggerCount >= 0.
    - Remove any unknown keys defensively.
  - Clear in-memory history.
- On disappear: saveSettings().

Integration with LogReader
- Instantiate LogReader as a @StateObject in BiomesUI when integrating.
- Set reader.onBiomeChange = { event in
  - states[event.biome]?.triggerCount += 1
  - appendHistory(for: event.biome)
  - if states[event.biome]?.webhookEnabled == true: trigger webhook (future)
}
- Call reader.start() in onAppear, reader.stop() in onDisappear.
- LogReader deduplicates repeated biome reports; only emits on change.

Future Enhancements
- Persist biome history in a separate file (biomehistory.json) to keep settings clean.
- Add webhook delivery layer with retry/backoff and per-biome enablement.
- Add color pickers per biome in the UI.
- Provide a “reset counts” action.

Testing Ideas
- Load/save round-trip for BiomeSettingsFile with both "items" and "biomes" keys.
- Color hex conversions (rounding/clamping).
- ensureAllBiomesExistAndClamp behavior with extra/missing keys.
- Integration test with a mocked LogReader that feeds deterministic events.

