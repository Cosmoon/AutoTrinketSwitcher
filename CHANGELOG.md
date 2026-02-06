Changelog
=========

All notable changes to AutoTrinketSwitcher are documented here.

2.0.1 - 2026-02-06
- Fixed talent-profile keying so dual-spec switches no longer jump to empty queues or appear to "delete" saved rotations.
- Added safer active spec-group detection across Classic/BCC API variants to keep primary/secondary profiles separated correctly.
- Added profile recovery fallback: when a newly selected profile is empty, ATS now reuses existing non-empty queues (sibling spec or previous active profile).

2.0.0 - 2026-01-15
- Updated for Burning Crusade client compatibility (Interface 20505 + cooldown API normalization).
- Fixed trinket button clicks to respect ActionButtonUseKeyDown.
- Improved cooldown tracking to prevent swap oscillation and missing overlays.
- Simplified tooltip option to a single "Show tooltips" checkbox (removed right-click mode).
- Menu settings sliders now render a visible track in the options UI.

1.9.1 - 2025-12-30
- Added two queue-set buttons to swap between two saved trinket rotations per talent profile. So if you change gear set you also can quickly change trinket rotation.
- Prevent auto swapping or manual restore attempts while the player is dead or a ghost.

1.5 - 2025-09-20
- Minimap button now uses LibDBIcon/LibDataBroker so it can be dragged and remembers its position.
- Falls back to the built-in minimap button if the libraries are missing.

1.4 - 2025-09-19
- Added a ready glow that reuses the mounted border whenever an equipped on-use trinket comes off cooldown.
- Added a "Trinket ready glow" toggle and color picker so the effect can be customized or disabled.
- Mount override persistence fixes: the red mounted indicator now survives login/reload and reactivates while mounted.
- Trinket menus now align with the top of the buttons when placed near the top half of the screen and with the bottom when placed near the bottom.
- General polish and small bug fixes around tooltip/menu refresh and cooldown handling while mounted.

1.3 - 2025-09-16
- Added talent-based profiles: separate trinket queues per talent build and automatic profile switching on talent change.
- Added menu sorting modes: Queued first (13-only -> 14-only -> both -> others), Name, Item level.
- Menu visuals: queued items now glow with slot colors; removed candidate-only highlight.
- Missing items: show grayed-out in menu; automatically prune missing from queues on login and after talent switch.
- Ctrl-click behavior: toggles only the clicked slot. Auto -> Manual equips the clicked trinket; Manual -> Auto resumes queue logic immediately.
- Global toggles unified (options + minimap): ON sets both slots to auto; OFF sets both to manual. Options checkbox reflects derived state (ON if at least one slot is auto).
- Mounted UX: red glow around both trinket buttons while mounted; per-slot manual badges now reflect only true per-slot state.
- Options layout: moved "Sort by" to second line; renamed to "Queue font size"; increased third-line spacing; Colour settings now four columns.
- Menu sizing: frame width/height adapts to wrapping like before.
- Slash commands: added `/ats clear 13`, `/ats clear 14`, `/ats clear both`; help output reformatted.
- Internal cleanup: split tooltip and talent-profile logic into `Tooltips.lua` and `Profiles.lua`.

1.0
- Initial release.
- Out-of-combat automatic trinket switching per-slot based on queue priority.
- Cross-slot coordination when both want the same item.
- Respect usable trinkets near ready, passive trinkets don't block swaps.
- Glow hint in combat when a swap will be possible soon.
- Mount handling: temporarily disable auto switching when mounted and restore after dismount (with settle guard).
- Trinket menu with queue management and cooldown overlays.
- Minimap button, options window, and tooltip controls (hover/right-click modes, tiny/clean tooltips, default anchor).
- Menu configuration: position, wrap at, wrap direction, queue number size.
- Colour customization for slot 13/14, glow, and manual badge.
