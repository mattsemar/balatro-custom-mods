# Balatro Run History / 历史战绩

[中文说明](./README.zh-CN.md)

Author: ZhiSunian

Chinese name: 历史战绩

Version: 0.1.2

## What It Does

Balatro Run History adds a simple run-history viewer to the Options menu.

It records each run while you play, then lets you open a `Run History` screen to review what happened later.

The first version focuses on practical run records:

- Deck, stake, seed, seeded-run flag, challenge flag, result, ante, round, blind, money, and best single-hand score.
- Final Jokers, vouchers, and playing-card deck snapshot.
- Expandable small card previews for final Jokers, the final deck, and redeemed vouchers. Card previews use real card visuals and can be hovered for the normal card tooltip where the game supports it.
- Final deck previews are sorted and grouped by suit.
- Filters and sorting for result, deck, stake, time, best score, and farthest ante.
- Archive stats: win rate, wins/losses, current streak, best streak, highest-stake streak, best single-hand score, farthest ante, farthest endless ante, and per-deck win rate.
- A clear-all history button with confirmation.
- English, Simplified Chinese, and Traditional Chinese UI text.

## Requirements

- Balatro on PC
- Lovely
- Steamodded / SMODS

This mod does not include Balatro, Lovely, Steamodded, or any game files.

## Installation

1. Install Lovely.
2. Install Steamodded / SMODS.
3. Extract the zip.
4. Put the `BalatroRunArchive` folder into:

```text
%AppData%\Balatro\Mods
```

The final layout should be:

```text
%AppData%\Balatro\Mods\BalatroRunArchive\manifest.json
%AppData%\Balatro\Mods\BalatroRunArchive\main.lua
%AppData%\Balatro\Mods\BalatroRunArchive\README.md
%AppData%\Balatro\Mods\BalatroRunArchive\README.zh-CN.md
```

5. Start Balatro and confirm `Balatro Run History` or `Run History / 历史战绩` appears in the Steamodded mod list.

## Compatibility Notes

The mod stores archive data in its own `run_archive.jkr` file inside the current profile's folder, loaded lazily and saved independently of `profile.jkr`. It does not edit Balatro's game files, Steamodded files, or Lovely files.

Known limits:

- The history keeps up to 50 recent runs by default (configurable via `run_history_max_runs`), with an additional size safeguard, so the archive file can never approach LuaJIT's per-chunk constant limit.
- Runs started before installing this mod may only get partial records if continued later.
- Mods that replace the same start-run, shop, use-card, win, or game-over functions may affect what gets recorded.

## Publishing Notes

This mod contains only original Lua mod code and metadata. It does not include Balatro, Lovely, Steamodded, game files, images, audio, save files, or other third-party assets.

## Changelog

### 0.1.2

- Moved the Run History entry from the main menu into the Options menu so it no longer creates an awkward extra row on the title screen.
- The Run History screen now returns to the Options menu when opened from there.

### 0.1.1

- Moved the main-menu Run History button into its own compact row so it no longer pushes the language, profile, social, or mod buttons off screen.

### 0.1.0

- Added the first Run History screen on the main menu.
- Added profile-backed run records with deck, stake, seed, result, final state, and expandable final card previews.
- Added filtering, sorting, a stats page, suit-grouped final deck previews, hoverable final-state card previews, and clear-all history management.
- Added English, Simplified Chinese, and Traditional Chinese UI text.
