AutoTrinketSwitcher
===============

What it does
- Auto switch: Out of combat, equips the highest-priority ready trinket for each slot.
- Preemptive return: When your top priority becomes switch-ready, it preempts lower priority trinkets.
- Cross-slot coordination: If both slots want the same trinket, slot 13 gets it; slot 14 takes the next ready item.
- Passive trinkets: Passive items do not block swaps; usable trinkets only block if they will be ready in 30 seconds or less.
- Mount handling: Auto switching is paused while mounted and restored after dismount.
- Glow hint: In combat, a slot glows if a queued trinket will be ready in 35 seconds or less.
- Ready glow: An equipped on-use trinket can glow when it is ready.
- Manual badge: An "M" appears on a slot when manual mode is active.

In-game usage
- Minimap button:
  - Left-Click: Show/Hide Trinkets window
  - Right-Click: Open/Close Options window
  - Shift + Click (left or right): Lock/Unlock buttons
  - Ctrl + Click (left or right): Toggle auto switching
  - Drag to reposition using the bundled minimap libraries.
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

Slash commands
- `/ats`: Show quick help.
- `/ats clear 13`: Clear slot 13 queue.
- `/ats clear 14`: Clear slot 14 queue.
- `/ats clear both`: Clear both queues.
- `/autotrinketswitcher`: Same as `/ats`.

Notes
- All required libraries are bundled: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0. No separate library installation is needed.
- Auto switching only happens out of combat.
- On WoW Forever clients that do not read addon SavedVariables back, settings are mirrored per character through the Blizzard addon-list table and addon CVars.
- If the client protects item cooldown values in a restricted encounter, cooldown-based switching waits until those values are readable again.
- The trinket menu can be configured to appear only out of combat.
- Tiny tooltips, ALT full tooltips, and clean isolated tooltips can be configured in Options.
- Supports Classic, TBC, MoP, Retail and Forever through automatic client detection.
- Mount gear: Classic riding gear; TBC Skybreaker Whip/Riding Crop/Carrot plus riding enchants; Retail Masterwork Riding Crop (193475, level 61+); Forever The Desert Rose (274648). No mount gear rules are enabled for MoP.
- One riding trinket is equipped at a time. The previous equipment is restored after dismount; failed restoration is retained for retry.
- Mount controls appear only when relevant gear is detected. Alt + Click (left or right) on the minimap toggles mount-speed trinket swapping.
- TBC mages retain Serpent-Coil Braid modes; TBC warriors retain Solarian's Sapphire modes. Options appear for owned, equipped or queued items. Hidden settings are preserved.
- Tests: `python tests/test_compatibility.py` (requires Python and lupa). Mocked Lua 5.1 checks do not replace in-game testing.

Talent-based queues
- AutoTrinketSwitcher tracks separate queue sets per talent build.
- When talents change, AutoTrinketSwitcher automatically switches to that build's dedicated queues.
- On first run, current queues are migrated to the current build.
- Settings are saved per character.

Ready alerts
- Open Options and scroll to Trinket ready alerts. Both alerts are disabled by default.
- Choose Moving (animated border) or Steady (soft, non-moving glow) under Glow style. Both use the configured colors and width; Steady uses width to adjust the glow spread.
- Configure separate macro glow colors for slot 13 ready (green), slot 14 ready (blue), and both ready (gold), plus border width (1-10 px).
- A macro using both slots changes color to show which trinket remains ready; its glow turns off when neither is ready. Single-slot macros use that slot's color.
- Choose a ready sound, set its volume (10-100%), and use Preview to hear it. Sound uses the WoW Master channel.
- Alerts ignore the global cooldown and do not sound on login or when equipping an already-ready trinket. Simultaneous cooldown completions play one sound.
