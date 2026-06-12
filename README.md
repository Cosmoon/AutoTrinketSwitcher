
AutoTrinketSwitcher
====================

What it does
- Auto switch: Out of combat, equips the highest-priority ready trinket for each slot.
- Preemptive return: When your top priority becomes “switch-ready” (=30s), it preempts lower priority.
- Cross-slot coordination: If both slots want the same trinket, slot 13 gets it; slot 14 takes the next ready item.
- Passive trinkets: Passive items don’t block swaps; usable trinkets only block if they’ll be ready in =30s.
- Mount handling: Auto switching disables while mounted; an optional mount-speed manager can equip speed gear from your bags and restore your previous gear on dismount.
- Glow hint: In combat, a slot glows if a queued trinket will be ready in =35s.
- Manual badge: An “M” appears on a slot when manual mode is active or when auto switching is OFF globally.
- Speed badge: An “S” appears when mount-speed trinket swapping is disabled.

In-game usage
- Minimap button:
  - Left-Click: Show/Hide Trinkets window
  - Alt+Left-Click: Toggle mount-speed trinket swapping
  - Right-Click: Open/Close Options window
  - Shift+Right-Click: Lock/Unlock Buttons
  - Ctrl+Right-Click: Toggle Auto Switching
  - Drag to reposition when LibDBIcon/LibDataBroker are installed (ATS falls back to the static button otherwise).
- Trinket buttons (two buttons for slot 13 and 14):
  - Hover: Shows menu; also shows tooltip if enabled
  - Alt + Hover: Shows full tooltip
- Trinket menu (shows all your trinkets, bag + equipped):
  - Shift-Click: Add/Remove trinket to the priority queue of the clicked slot (Left = slot 13, Right = slot 14)
  - Ctrl-Click: Equip in slot AND toggle manual mode for slot (Left = slot 13, Right = slot 14) or toggle auto queue
- Manual mode “M” badge:
  - Shown on a slot when that slot is manual, or when auto switching is OFF.
  - Manual slots are never auto-swapped.

Priority rules (summary)
- Each slot has its own queue (1 = highest). The first ready (=30s) item in a slot’s queue is chosen.
- If both slots want the same item, slot 13 wins; slot 14 tries its next choice.
- While your slot’s top priority isn’t ready, the currently equipped item for that slot is reserved so the other slot won’t steal it.
- Usable items near ready (=30s) won’t be swapped off unless the incoming trinket is higher priority for that slot.

Slash commands
- /ats: Show quick help
- /ats help: Show quick help


Notes & tips
- Auto switching only happens out of combat; the glow hint is shown in combat when a swap will be possible soon.
- The menu can be configured to appear only out of combat.
- Optional mount-speed manager support covers Carrot on a Stick, Riding Crop, gloves with Riding Skill, and boots with Mithril Spurs. It is on by default; when disabled, ATS uses the old 1.5s resume guard after dismount.
 - Optional: When using tiny tooltips, enable "Hold ALT for full tooltips" in General settings to see full item tooltips while holding ALT on hover (slots and menu).
 - Optional: Enable "Block other addon info in tooltips" to show trinket tooltips using an isolated tooltip that most addons won't modify.

Talent-based queues
- Tracks separate trinket queues per talent build (Classic trees).
- When you change talents, ATS automatically switches to that build’s dedicated pair of queues (slot 13 and 14).
- On first run, your current queues are migrated to the current build; new builds start with empty queues.
- Per-character, saved automatically; no extra setup required.

