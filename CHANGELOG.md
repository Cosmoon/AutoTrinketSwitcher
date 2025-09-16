Changelog
=========

All notable changes to AutoTrinketSwitcher are documented here.

1.3 - 2025-09-16
- Added talent-based profiles: separate trinket queues per talent build and automatic profile switching on talent change.
- Added menu sorting modes: Queued first (13-only → 14-only → both → others), Name, Item level.
- Menu visuals: queued items now glow with slot colors; removed candidate-only highlight.
- Missing items: show grayed-out in menu; automatically prune missing from queues on login and after talent switch.
- Ctrl-click behavior: toggles only the clicked slot. Auto → Manual equips the clicked trinket; Manual → Auto resumes queue logic immediately.
- Global toggles unified (options + minimap): ON sets both slots to auto; OFF sets both to manual. Options checkbox reflects derived state (ON if at least one slot is auto).
- Mounted UX: red glow around both trinket buttons while mounted; per-slot manual badges now reflect only true per-slot state.
- Options layout: moved “Sort by” to second line; renamed to “Queue font size”; increased third-line spacing; Colour settings now 4 columns.
- Menu sizing: frame width/height adapts to wrapping like before.
- Slash commands: added `/ats clear 13`, `/ats clear 14`, `/ats clear both`; help output reformatted.
- Internal cleanup: split tooltip and talent-profile logic into `Tooltips.lua` and `Profiles.lua`.

1.0
- Initial release.
- Out-of-combat automatic trinket switching per-slot based on queue priority.
- Cross-slot coordination when both want the same item.
- Respect usable trinkets near ready, passive trinkets don’t block swaps.
- Glow hint in combat when a swap will be possible soon.
- Mount handling: temporarily disable auto switching when mounted and restore after dismount (with settle guard).
- Trinket menu with queue management and cooldown overlays.
- Minimap button, options window, and tooltip controls (hover/right-click modes, tiny/clean tooltips, default anchor).
- Menu configuration: position, wrap at, wrap direction, queue number size.
- Colour customization for slot 13/14, glow, and manual badge.
