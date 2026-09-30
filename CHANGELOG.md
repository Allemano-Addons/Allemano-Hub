# Changelog

## 0.4.1 – 2026-09-30
- Fix: the window jumped while the scale slider was dragged (it grew under the mouse). The number follows the
  slider and the window changes when the mouse button is released.


## 0.4.0 – 2026-09-30
- Appearance page: font (automatic = EllesmereUI's Expressway when it is installed, else the game font, or any font
  the client accepts), text size, accent color (Allemano white, class or a preset), window background and scale, and
  the launcher button, with a live preview.
- WoW Forever refuses font files shipped in nearly all addon folders (only the game's fonts and a few addons'
  work), so the Hub cannot bring Manrope or JetBrains Mono. `/allemano fonttest` lists the fonts the client accepts.


## 0.3.1 – 2026-09-30
- Fix: an error in the list could not be selected (the page rebuilt the list on every refresh and forgot the
  selection); clicking a row now shows that error on the right and keeps it selected.


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

