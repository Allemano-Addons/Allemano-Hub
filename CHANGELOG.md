# Changelog

## 0.3.0 – 2026-09-30
- Errors page: every error the Allemano addons recorded, newest first, the selected one in full, and a
  "Copy report" button that opens a report (game and addon versions, other loaded addons and all errors) to copy
  and paste in the Discord. "Clear all" empties every addon's list (two clicks). `/allemano report` opens the report.
- "Open" runs each addon's own command directly (fixes AltBoard), and the news fits the column.


## 0.2.0 – 2026-09-30
- A new layout: a sidebar with the Hub pages (Overview, Appearance, Guild, Errors) and every Allemano addon, and
  an Overview page with an update banner, a card per addon (Open, or Not installed / Soon) and the latest release
  notes. Appearance, Guild, Errors and the addon pages come next.
- "Update available" and the news come from a release list built into the Hub (tools/gen_releases.lua reads the
  addons' versions and changelogs), since an addon cannot ask the internet.
- The Hub is plain Allemano white now, with the addons' own colors on their marks.


## 0.1.0 – 2026-09-30
- First version: a window listing every Allemano addon with its version and state (loaded, installed but not
  loaded, not installed), Open and Settings shortcuts that run each addon's own commands, a copy box with the
  CurseForge link of addons you do not have yet, and the launcher button.

