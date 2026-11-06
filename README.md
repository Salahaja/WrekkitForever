# Wrekkit Forever

A threat list and mob frames for **WoW Forever** (interface 16001), cut down from [Wrekkit](https://github.com/Salahaja/Wrekkit), the 1.12 raid analyzer.

## Features
- **Threat list.** Your group's threat on your target: how close each player is to pulling, the tank's hold, threat per second, and your row pinned.
- **Mob frames.** Every enemy in combat, with its health, raid marker, who has it, your pull % or hold, a threat bar, and your own debuffs with timers.
- **Options.** Esc > Options > AddOns > Wrekkit Forever, or `/wf config`.

## Hidden numbers
Forever uses Midnight's addon restrictions. In combat, encounters and some maps, the game may hand addons *secret* values: an addon can show them, but can't compare, sort or add them up. Wrekkit Forever checks every reading (`canaccessvalue`).
- When numbers are hidden, it puts them on screen unchanged and lets the game colour whoever has aggro.
- Otherwise it sorts and works out hold and threat per second.

`/wf check` shows what is hidden right now.

## Install
Download the zip from [Releases](../../releases). Extract it into `World of Warcraft\_forever_\Interface\AddOns\`, then restart the game.

## Commands
| Command | |
|---|---|
| `/wf config` | options page |
| `/wf test` | sample rows, to place the windows |
| `/wf lock` | lock both windows |
| `/wf check` | what the game hides right now |
| `/wf` | all commands |

## Development
`lua tools/test.lua` runs the addon against a stubbed game API, once with readable numbers and once with every threat, GUID and aura time hidden.

The API was checked against Blizzard's generated documentation for the Forever build, which is mirrored in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever) (`Blizzard_APIDocumentationGenerated`).
