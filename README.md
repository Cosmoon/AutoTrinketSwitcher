AutoTrinketSwitcher
===================

What it does
- Auto switch: Out of combat, equips the highest-priority ready trinket for each slot.
- Preemptive return: When your top priority becomes switch-ready, it preempts lower priority trinkets.
- Cross-slot coordination: If both slots want the same trinket, slot 13 gets it; slot 14 takes the next ready item.
- Passive trinkets: Passive items do not block swaps; usable trinkets only block if they will be ready in 30 seconds or less.
- Mount handling: ATS can equip Carrot on a Stick, Riding Crop, Skybreaker Whip, Riding Skill gloves, and Mithril Spurs boots from bags while mounted.
- Special trinkets: Supported trinkets can expose item-specific modes in Options when detected in bags, equipped slots, queues, or saved settings.
- Glow hint: In combat, a slot glows if a queued trinket will be ready in 35 seconds or less.
- Manual badge: An "M" appears on a slot when manual mode is active.
- Speed badge: An "S" appears when mount-speed trinket swapping is disabled.

In-game usage
- Minimap button:
  - Left-Click: Show/Hide Trinkets window
  - Right-Click: Open/Close Options window
  - Alt + Right-Click: Toggle mount-speed trinket swapping
  - Shift + Right-Click: Lock/Unlock buttons
  - Ctrl + Right-Click: Toggle auto switching
  - Drag to reposition when LibDBIcon/LibDataBroker are installed; ATS falls back to a static button otherwise.
- Trinket buttons:
  - Hover: Show the trinket menu and tooltip.
  - Left-Click: Use the equipped trinket.
- Trinket menu:
  - Shift + Left/Right-Click: Add/remove a trinket from slot 13/14 queue.
  - Ctrl + Left/Right-Click: Equip in slot 13/14 and toggle that slot's manual mode.

Priority rules
- Each slot has its own queue; position 1 is highest priority.
- The first ready trinket with 30 seconds or less cooldown remaining is chosen.
- If both slots want the same item, slot 13 wins; slot 14 tries its next choice.
- While a slot's top priority is not ready, the currently equipped queued item for that slot is reserved so the other slot will not steal it.
- Usable items near ready will not be swapped off unless the incoming trinket is higher priority for that slot.

Special trinkets
- Serpent-Coil Braid supports:
  - Off
  - Show mana gem cooldown
  - Use mana gem cooldown for switching
- More special trinkets can be added in `Modules\SpecialTrinkets.lua`.

Slash commands
- `/ats`: Show quick help.
- `/ats clear 13`: Clear slot 13 queue.
- `/ats clear 14`: Clear slot 14 queue.
- `/ats clear both`: Clear both queues.

Notes
- Auto switching only happens out of combat.
- The trinket menu can be configured to appear only out of combat.
- Mount-speed manager is on by default and can be disabled in Options.
- Tiny tooltips, ALT full tooltips, and clean isolated tooltips can be configured in Options.

Talent-based queues
- ATS tracks separate queue sets per talent build.
- When talents change, ATS automatically switches to that build's dedicated queues.
- On first run, current queues are migrated to the current build.
- Settings are saved per character.
