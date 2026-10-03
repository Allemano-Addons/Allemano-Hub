# Changelog

## 0.9.0 – 2026-10-03
- The Errors page can show the errors of every addon, not only Allemano's: switch between "Allemano" and "All addons" at the top. The default is still Allemano.
- In the All addons view the same error is shown once with how many times it happened ("x214"), when it first came, its stack, and the addon it belongs to. Errors that come through a library are put on the addon that called it. Errors that belong to no addon (the game's own) are listed too.
- The stack is saved with every error (and the local variables, when the game provides them) and shown under the message. "Copy this error" opens a box with the whole error (message, stack and locals) to copy and send.
- The sound also rings for other addons' errors while the All addons view is selected.
- A flood of errors cannot fill the memory: at most 150 different errors are kept, and only the first few new kinds each second are stored (the counts of known ones still go up).
- "Clear all" empties both lists.

## 0.8.0 – 2026-10-03
- A sound when an Allemano addon hits an error. On the Errors page: Sound on/off, which sound and a Test button. The list has some of the game's own sounds (Quest failed, Raid warning, Ready check, Whisper, Alarm clock) and every sound other addons have registered with LibSharedMedia, the same list BugSack uses (BigWigs, Details and so on). At most one sound every three seconds, and the same error does not ring again for a minute.
- Long dropdown menus (the sound list, the font list) scroll with the mouse wheel and show a thin scroll bar instead of spreading into many columns. The selected item is brought into view.
- Errors are blamed on the right addon. An error that goes through a library (such as the Ace3 libraries ALC bundles) used to be put on the addon whose copy of the library it was, even if another addon had caused it. The Hub now looks at the first line that is not a library, in the message and in the stack; if that belongs to another addon the error is ignored, if it belongs to an Allemano addon it goes to that one.

## 0.7.1 – 2026-10-02
- Fixed an error when opening the Hub if an Allemano addon without a picture (such as Allemano Arcade) was installed: it now gets a plain icon in the sidebar.
- Session Tracker is now Allemano Ledger: the Hub knows the new folder and saved-data name, and opens it with /ledger.

## 0.7.0 – 2026-10-02
- New Performance page: how much memory every loaded addon uses, with bars (the Allemano addons in their own
  colours), a filter for the Allemano addons or all, and sorting on any column. "Clean up memory" asks the game to
  free what addons no longer use (the page shows the memory before and after; hover the button to see exactly what it
  does).
- CPU per addon, when you turn on script profiling (it needs a reload and costs a little performance, so it is off
  until you ask): milliseconds per second of play, and a Peak column with the highest figure since you opened the
  page. The Hub measures itself while the page is open, so its own row is marked and left out of the totals.
- A reminder in the chat at login, a small "ON" in the menu and a line on the launcher button if profiling was left
  on.
- The page remembers your filter and sorting. `/allemano perf` prints the biggest addons in the chat
  (`/allemano perf mine` for the Allemano ones).
- The report (`/allemano report`) now includes the memory (and, with profiling on, the average CPU) of the Allemano
  addons.
- Arbiter Soft Reserve is in the list of Allemano addons, with its purple mark: in the menu, on the Overview and
  counted with the Allemano addons on the Performance page. Its Open button opens the import box.

## 0.6.0
- The Errors page now catches Lua errors from every Allemano addon, also those that keep no error list of
  their own (Arbiter Loot Council, Hush Feed, Hush LFG, Hush Recruit) and errors outside an addon's protected
  calls (button scripts, timers). Uses BugGrabber when it is installed, otherwise the game's error handler.
  Errors an addon already recorded itself are not shown twice.
- The open Errors page and the error count update at once when a new error arrives.
- The launcher button shows a small number for errors that came in since you last opened the Errors page.
- `/allemano errors test <AddonFolder>` sends a test error as if it came from that addon, for checking.

## 0.5.0 – 2026-09-30
- Guild page: a table of the guild members who run Allemano Hub, with the version of each Allemano addon they have
  (green = the newest known, orange = an update exists, a dash = not installed), online members first, class colors,
  and offline members keep their last list. Only addon names and versions are shared, only with your own guild, and
  "Share my addon list" turns it off. "Ask the guild" (`/allemano sync`) asks for the lists.
- A newer version seen on a guild member counts as an update on the Overview banner ("seen in the guild").
- `/allemano selftest` adds a fake member built from your own list; `/allemano selftest clear` removes it.


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

