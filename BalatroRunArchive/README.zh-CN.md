# Balatro Run History / 历史战绩

[English README](./README.md)

作者：ZhiSunian

版本：0.1.2

## 功能

Balatro Run History / 历史战绩 会在选项菜单里添加一个“历史战绩”入口，用来查看之前每一局的大致情况。

这个首版先做稳定、实用的记录功能：

- 记录每局使用的卡组、难度、Seed、是否指定 Seed、是否挑战、胜负结果、底注、回合、盲注、最终金钱和最高单手得分。
- 记录结束时的小丑牌、优惠券和最终牌组快照。
- 最终状态里的小丑牌、牌组和优惠券可以展开查看真实缩小牌面；游戏支持时，光标移上去会显示原本的卡牌提示。
- 最终牌组会按花色排序并分组显示。
- 支持按胜负结果、卡组、难度筛选，并按时间、最高分、最远底注排序。
- 统计页会显示总胜率、胜负数、当前连胜、最高连胜、最高难度连胜、最高单手分数、最远底注、最远无尽底注和按卡组胜率。
- 支持二次确认后清空全部记录。
- 支持英文、简体中文、繁体中文界面。

## 依赖

- PC 版 Balatro
- Lovely
- Steamodded / SMODS

本压缩包不包含 Balatro、Lovely、Steamodded 或任何游戏文件。

## 安装

1. 安装 Lovely。
2. 安装 Steamodded / SMODS。
3. 解压本压缩包。
4. 将 `BalatroRunArchive` 文件夹放入：

```text
%AppData%\Balatro\Mods
```

最终结构应为：

```text
%AppData%\Balatro\Mods\BalatroRunArchive\manifest.json
%AppData%\Balatro\Mods\BalatroRunArchive\main.lua
%AppData%\Balatro\Mods\BalatroRunArchive\README.md
%AppData%\Balatro\Mods\BalatroRunArchive\README.zh-CN.md
```

5. 启动 Balatro，并确认 Steamodded 模组列表中出现 `Balatro Run History` 或 `Run History / 历史战绩`。

## 兼容性说明

本模组会把历史战绩写入 Balatro 当前配置档案，并通过 Balatro 原本的设置保存流程保存。它不会修改 Balatro、Steamodded 或 Lovely 的安装文件。

已知限制：

- 战绩保存在存档目录下独立的 `run_archive.jkr` 文件中，按需加载并单独保存，不再写入 `profile.jkr`。
- 默认最多保留最近 50 局（可通过 `run_history_max_runs` 配置），并额外限制文件体积，确保战绩文件永远不会逼近 LuaJIT 单个代码块的常量上限。
- 安装本模组之前已经开始的旧对局，如果之后继续游玩，可能只能生成部分记录。
- 如果其他模组替换了同一批开始对局、商店、用牌、胜利或失败函数，可能会影响记录内容。

## 发布说明

本压缩包只包含原创 Lua 模组代码和元数据，不包含 Balatro、Lovely、Steamodded、游戏文件、图片、音频、存档或其他第三方资产。

## 更新日志

### 0.1.2

- 将“历史战绩”入口从主菜单移到选项菜单，避免主界面多出一整条只有一个按钮的黑框。
- 从选项菜单进入历史战绩后，返回按钮会回到选项菜单。

### 0.1.1

- 将主菜单“历史战绩”按钮移到独立的小型上排按钮，不再挤压语言、配置、社交和模组按钮。

### 0.1.0

- 在主菜单添加首版“历史战绩”入口。
- 添加随配置档案保存的对局记录：卡组、难度、Seed、结果、最终状态和可展开最终牌面预览。
- 添加筛选、排序、统计页、按花色分组的最终牌组、可悬停的最终状态牌面预览和清空记录管理。
- 添加英文、简体中文、繁体中文 UI 文本。
