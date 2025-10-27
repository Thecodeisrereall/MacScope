# Biome Log (Debugging) – Documentation Source

Audience
- Internal developer notes to remember current UX/details of the Biome Log section, plus sandbox/file-access considerations and our current solution.

What this section is
- A live, read-only “log” (not a command console) embedded in the Biomes screen for quick visibility into detection, parsing, and persistence activity.

Current UI (2025-09-21)
- Section title: “Biome Log” (BoxedSection)
- Header controls (left to right):
  - Clear
    - Label: “Clear”
    - Icon: SF Symbol "trash"
    - Behavior: Empties the in-memory log array and appends “Log cleared.”
  - Probe Logs
    - Label: “Probe Logs”
    - Icon: SF Symbol "text.page.badge.magnifyingglass"
    - Behavior: Calls LogReader.getLatestBiomeSnapshot() once, logs directory reachability, and prints the latest parsed biome (or a not-found message).
  - Dump
    - Label: “Dump”
    - Icon: SF Symbol "square.and.arrow.down"
    - Behavior: Opens NSSavePanel to export the current on-screen log lines to a UTF-8 .txt file. Default filename: BiomeLog_<yyyy-MM-dd_HHmmss>.txt (UTC, POSIX, safe characters). Success/failure/cancel is written back into the log.
  - Choose Logs Folder…
    - Label: “Choose Logs Folder…”
    - Icon: SF Symbol "folder.badge.plus"
    - Behavior: Opens NSOpenPanel for a directory. Saves a security-scoped bookmark and restarts LogReader to tail the chosen folder.
- Status badge (right-aligned): “Last Biome: <Name>” or “—” if none detected yet.

Log output area
- Nested ScrollView inside the BoxedSection; the whole page scrolls, and the log area scrolls independently.
- LazyVStack of monospaced, copyable lines; each is “[HH:MM:SS] message” with time: .standard, date omitted.
- Visuals: rounded rect background using NSColor.textBackgroundColor, 1pt separator stroke, consistent with macOS appearance.
- Auto-scrolls to bottom on new line append with a short ease-out animation; scroll is deferred to next run loop to avoid layout timing glitches.

Sizing and limits
- Viewport min height: max(consoleMinHeight, consoleMinLines * consoleLineHeight)
  - consoleMinLines = 20, consoleLineHeight = 14.0, consoleMinHeight = 320
- Viewport max height: consoleMaxHeight = 480
- In-memory line cap: consoleMaxLines = 500 (FIFO trimming when exceeded)

Event flow recap
1) LogReader tails newest *.log in a configured logs directory.
2) On parsed biome change (deduplicated), LogReader emits BiomeDetectionEvent via onBiomeChange.
3) BiomesUI:
   - Updates per-biome triggerCount (clamped to >= 0).
   - Updates “Last Biome” badge.
   - Appends a human-readable summary line.
   - Saves settings (trigger counts, webhook toggles, colors).
4) Manual probe:
   - Safe-copy read of the newest log; finds the latest biome and logs the result.

Parsing rules (mirrors Python)
- Extract the first balanced JSON object per line (brace-depth scan).
- Check either:
  - message.properties.HoverText
  - data.largeImage.hoverText (BloxstrapRPC payloads)
- Case-insensitive mapping to Biome:
  normal, windy, snowy, rainy, sandstorm, hell, starfall, corruption, null, glitched, dreamspace

Dump/export details
- NSSavePanel with allowedContentTypes = [.plainText].
- Default filename: BiomeLog_<yyyy-MM-dd_HHmmss>.txt (UTC).
- Encoding: UTF-8; explicit guard for data conversion (no silent no-ops).
- Writes atomically; logs outcome to the on-screen log.

Why we renamed “Console” to “Log”
- The view is read-only and does not accept commands. “Log” better communicates its purpose and avoids implying shell/terminal interactivity.

Rationale for icon choices
- Clear: "trash" is the standard, recognizable delete/clear metaphor on macOS.
- Probe Logs: "text.page.badge.magnifyingglass" communicates “inspect a document”.
- Dump: "square.and.arrow.down" is a canonical “save/export” metaphor.
- Choose Logs Folder…: "folder.badge.plus" conveys adding a folder selection.

Sandbox file access: the problem and our fix
- Problem
  - With App Sandbox enabled, direct reads from ~/Library/Logs/Roblox are denied unless the user explicitly grants access. The default path works only outside sandbox or with broad entitlements we don’t want to request.
- Symptoms
  - LogReader.history stays empty; reachability checks fail; the log prints “Logs directory not reachable: …” even when Roblox is running.
- Our fix (least-privilege, user-consented)
  - We added a security-scoped bookmark flow so the user selects the Roblox Logs folder once, and the app can read it thereafter.
  - New utilities in SecurityScopedBookmarks.swift:
    - promptForRobloxLogsFolder(completion:) uses NSOpenPanel to choose the folder, then saves a bookmark in UserDefaults ("RobloxLogsBookmark"). It starts security-scoped access for the session.
    - resolveRobloxLogsBookmark() resolves the saved bookmark at launch/view appear, starts security-scoped access, and returns the URL (handles stale bookmarks by regenerating).
    - stopAccess(url:) stops access when appropriate (e.g., on disappear/termination).
  - LogReader override:
    - Added overrideLogsDirectory, and logsDirectory now prefers this override. No parsing/tailing logic changed.
  - BiomesUI wiring:
    - On appear, we resolve the bookmark; if found, set reader.overrideLogsDirectory and start. If not found, we prompt once, save, and then start.
    - Added a “Choose Logs Folder…” button to re-run the selection, update the bookmark, and restart the reader.
  - Entitlements:
    - App Sandbox enabled.
    - User Selected File: Read/Write enabled.
- Why this works
  - Security-scoped bookmarks grant persistent, user-approved access to the selected directory within the sandbox, satisfying macOS privacy/security requirements without broad file access entitlements.

Troubleshooting quick list
- Directory reachability: expect “Logs directory reachable: …” on probe.
- Rotation: LogReader switches to the newest *.log automatically.
- Encoding: UTF-8 first, ISO-8859-1 fallback during live tail; dump always writes UTF-8.
- No detections: verify real logs contain the JSON shapes described above with recognized hoverText values.
- Bookmark not working?
  - Re-select the folder via “Choose Logs Folder…”.
  - Check entitlements are present:
    - com.apple.security.app-sandbox = true
    - com.apple.security.files.user-selected.read-write = true

Verification checklist (build/distribution)
- In Xcode → Target → Signing & Capabilities:
  - App Sandbox: ON
  - File Access → User Selected File: Read/Write: ON
- Post-build entitlements:
  codesign -d --entitlements :- "/path/to/YourApp.app"
  Ensure the two keys above are present.

Change log
- 2025-09-21
  - Introduced nested, bounded scrolling log with auto-scroll and 500-line cap.
  - Added “Probe Logs” action.
  - Added “Dump” export with NSSavePanel and UTF-8 write guard.
  - Renamed “Biome Console” to “Biome Log”.
  - Finalized icon set: Clear = trash, Probe = text.page.badge.magnifyingglass, Dump = square.and.arrow.down, Choose Folder = folder.badge.plus.
  - Sandbox fix: security-scoped bookmark workflow; LogReader overrideLogsDirectory; “Choose Logs Folder…” button; docs updated with rationale and troubleshooting.
