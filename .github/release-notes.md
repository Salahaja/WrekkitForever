**The first public release: a threat list and mob frames for WoW Forever.**

## What it does
- **Threat list.** Everyone in your group on your target, or on your target's target when you're targeting a friendly player. Sorted by threat, each bar shows how close that player is to pulling. The tank's row shows its **hold**: 100 minus the closest player's pull %. Rows also show threat per second and Blizzard's aggro colours, and your own row can be pinned.
- **Mob frames.** Every enemy in combat, found from your target and focus, enemy nameplates, what your group is targeting, and boss frames. Each mob shows:
  - its health
  - its raid marker
  - **who has it**, and how close you are to pulling it, e.g. `Tankyboi  82%`, or `hold 41%` when it's yours
  - a thin threat bar
  - up to five of **your own debuffs**, with timers
- **Options page.** Esc > Options > AddOns > Wrekkit Forever, or `/wf config`. Lock the windows, show sample rows to place them, and set rows, width and size per window.

## When the game hides numbers
WoW Forever uses Midnight's addon rules. In some states (combat, boss encounters, some maps) the game hides exact threat and aura numbers from addons. Wrekkit Forever keeps working when that happens:
- The bars and percentages still show, because the game lets addons display hidden numbers.
- They just can't be sorted, so the threat list keeps group order with you first.
- The game itself colours whoever has aggro.

`/wf check`, with a mob targeted, tells you what's hidden right now.

Everything comes from Blizzard's own addon API. There are no DLLs or anything outside the game.

## Install
Download `WrekkitForever-0.3.0.zip` and extract it into `World of Warcraft\_forever_\Interface\AddOns\`. You should end up with `Interface\AddOns\WrekkitForever\WrekkitForever.toc`. Do **not** use the "Source code" links. Then restart the game fully: a new addon isn't picked up by `/reload`.

Turn on enemy nameplates (V) so the mob frames can see mobs nobody is targeting.
