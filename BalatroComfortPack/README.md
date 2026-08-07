# Balatro Comfort Pack

Version: 1.0.4

Balatro Comfort Pack is an all-in-one helper pack for Balatro. It combines six small mods from this repository into one mod folder, with a config panel that lets you turn each feature on or off.

No Balatro game files, game art, audio, save files, Lovely files, Steamodded files, DLLs, or other third-party assets are included.

## Included Modules

Quality-of-life helpers:

1. Modifier Warning / 覆盖提醒
   Warns when a consumable would replace an existing playing-card enhancement or seal.

2. Run History / 历史战绩
   Records past runs, final Jokers, final deck, vouchers, basic results, filters, and statistics.

3. More Joker Info / 更多小丑牌信息
   Adds clearer Supernova hand bonuses and Baseball Card total X Mult to Joker tooltips.

Balance-affecting helpers:

4. Score Preview / 分数预览
   Shows a pre-play reference score for the selected hand. If the current round score plus the previewed score is enough to clear the blind, the reference row is highlighted.

5. Shop Undo / 商店回退
   Adds a shop undo button for common shop mistakes such as accidental buys, sales, and voucher purchases.

6. Step Back / 对局回退
   Adds in-blind checkpoints before plays and discards, with a history menu and card previews.

## Changelog

### 1.0.4

- Updated the built-in Score Preview module to standalone 1.3.2.
- Expanded sandbox restoration for similar Joker side-effect paths involving card removal and dissolve flags.

### 1.0.3

- Updated the built-in Score Preview module to standalone 1.3.1.
- Fixed Sixth Sense being blocked after the score preview sandbox inspected a single played 6.

### 1.0.2

- Updated the built-in Joker tooltip module to More Joker Info 1.0.3.
- Supernova tooltip info now uses larger high-contrast two-column cards.
- Baseball Card now shows eligible Uncommon Jokers and current total X Mult in its tooltip.

### 1.0.1

- Updated the built-in Run History module to standalone 0.1.3.
- Starting a new run now closes any previous unfinished run-history record as `Unfinished` instead of leaving it stuck as `In Progress`.

## Config Panel

Open the mod's config page in Steamodded to enable or disable each module.

Quality-of-life modules are enabled by default. Balance-affecting modules are disabled by default and can be enabled manually.

The config panel has two status columns:

- `Current`: what is loaded in the current game session.
- `Setting`: the saved on/off setting. This is saved immediately, but loaded modules only change after restarting the game.

This restart rule avoids partially removing hooks while Balatro is already running.

## Compatibility With Standalone Mods

Balatro Comfort Pack is designed to avoid conflicts with the standalone versions of these modules.

If the matching standalone mod is installed and available, Comfort Pack skips its internal copy of that module, marks the row as `Standalone`, and lets the standalone mod handle it.

The config panel only controls Comfort Pack's internal modules. It cannot turn standalone mods on or off. For a clean all-in-one setup, disable or remove the standalone helper mods and use Comfort Pack by itself.

## Language Support

UI text supports:

- English
- Simplified Chinese
- Traditional Chinese

The mod chooses text based on Balatro's current language setting.

## Requirements

- Balatro on PC
- Lovely Injector
- Steamodded / SMODS

## Installation

1. Install Lovely.
2. Install Steamodded / SMODS.
3. Download `BalatroComfortPack-1.0.4.zip`.
4. Extract the zip.
5. Move the `BalatroComfortPack` folder into your Balatro Mods directory:

```text
%AppData%\Balatro\Mods
```

The final layout should look like this:

```text
%AppData%\Balatro\Mods\BalatroComfortPack\manifest.json
%AppData%\Balatro\Mods\BalatroComfortPack\main.lua
%AppData%\Balatro\Mods\BalatroComfortPack\modules\
```

Do not place the mod inside an extra nested folder such as:

```text
%AppData%\Balatro\Mods\BalatroComfortPack-1.0.4\BalatroComfortPack\manifest.json
```

## Safety Notes

- The mod does not edit Balatro's installed game files.
- The mod stores its own settings through Steamodded's normal mod config system.
- Run History stores run records in Balatro profile/settings data and caps the record list to avoid unlimited growth.
- Score Preview is a sandboxed estimate. It is meant as a reference, not a guaranteed replacement for the real scoring animation.
- Step Back and Shop Undo restore checkpoints through Balatro's run save/load data shape. Mods that keep unsaved external state may not restore perfectly.

## Troubleshooting

If something breaks, first test with only Lovely, Steamodded, and Balatro Comfort Pack enabled.

If the issue disappears, re-enable other mods one by one to find the conflict.

## License

GPL-3.0. See the repository `LICENSE`.

Balatro is owned by LocalThunk / Playstack. Lovely and Steamodded/SMODS belong to their respective authors. This mod is not affiliated with or endorsed by them.
