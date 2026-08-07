# Balatro Comfort Pack / 小丑牌舒适包

版本：1.0.4

Balatro Comfort Pack 是一个整合型 Balatro 辅助模组。它把本仓库里的六个小功能合并到同一个 mod 文件夹里，并提供配置面板，让玩家可以单独开关每个功能。

本模组不包含 Balatro 游戏文件、游戏素材、音频、存档、Lovely 文件、Steamodded 文件、DLL 或其他第三方资产。

## 包含模块

体验优化类：

1. Modifier Warning / 覆盖提醒
   当消耗牌会替换扑克牌已有的增强牌或蜡封时，提前给出提示。

2. Run History / 历史战绩
   记录历史对局、最终小丑牌、最终牌组、优惠券、基础结果、筛选和统计信息。

3. More Joker Info / 更多小丑牌信息
   在小丑牌说明里显示更清晰的超新星牌型加成和棒球卡总倍率。

影响平衡类：

4. Score Preview / 分数预览
   出牌前显示所选手牌的参考分数；如果当前回合分数加预览分数已经足够通过盲注，会高亮参考值。

5. Shop Undo / 商店回退
   在商店里添加回退按钮，用于撤回误买、误卖、购买优惠券等常见失误。

6. Step Back / 对局回退
   在盲注内出牌或弃牌前创建检查点，提供历史菜单和牌面预览。

## 更新日志

### 1.0.4

- 内置分数预览模块更新到单独版 1.3.2。
- 排查同类小丑牌副作用路径后，扩大沙盒恢复范围，补充恢复卡牌移除和溶解动画相关临时标记。

### 1.0.3

- 内置分数预览模块更新到单独版 1.3.1。
- 修复分数预览沙盒检查单张 6 点牌后，会导致真实出牌时第六感不生效的问题。

### 1.0.2

- 内置小丑牌提示模块更新为 More Joker Info 1.0.3。
- 超新星提示信息改成更大的黑底高对比两列卡片。
- 棒球卡说明现在会显示可加成的罕见小丑牌数量，以及当前总 X 倍率。

### 1.0.1

- 内置历史战绩模块更新到单独版 0.1.3。
- 开始新一局时，会把上一局未正常结束的历史记录结算为 `未完成`，不再一直显示为 `进行中`。

## 配置面板

在 Steamodded 的 mod 配置页里，可以单独开关每个模块。

体验优化类模块默认开启。影响平衡类模块默认关闭，可以手动开启。

配置面板有两列状态：

- `当前`：本次游戏会话里实际加载的状态。
- `设置`：已经保存的开关设置。开关会立刻保存，但已加载模块需要重启游戏后才会真正变化。

这样做是为了避免游戏运行中强行卸载 hook，减少不稳定情况。

## 与单独版模组的兼容

Balatro Comfort Pack 会尽量避免和单独版模组冲突。

如果检测到对应单独版 mod 已安装并可加载，Comfort Pack 会跳过内部同名模块，把状态标记为 `单独版`，让单独版负责运行。

配置面板只控制 Comfort Pack 内部模块，不能开关单独版 mod。如果想干净使用整合包，请禁用或移除对应单独版模组，只启用 Comfort Pack。

## 语言支持

UI 文本支持：

- 英文
- 简体中文
- 繁体中文

模组会根据 Balatro 当前语言自动选择文本。

## 依赖

- PC 版 Balatro
- Lovely Injector
- Steamodded / SMODS

## 安装

1. 安装 Lovely。
2. 安装 Steamodded / SMODS。
3. 下载 `BalatroComfortPack-1.0.4.zip`。
4. 解压压缩包。
5. 将 `BalatroComfortPack` 文件夹放入 Balatro 的 Mods 目录：

```text
%AppData%\Balatro\Mods
```

最终结构应类似：

```text
%AppData%\Balatro\Mods\BalatroComfortPack\manifest.json
%AppData%\Balatro\Mods\BalatroComfortPack\main.lua
%AppData%\Balatro\Mods\BalatroComfortPack\modules\
```

不要多套一层文件夹，例如不要变成：

```text
%AppData%\Balatro\Mods\BalatroComfortPack-1.0.4\BalatroComfortPack\manifest.json
```

## 安全说明

- 本模组不会修改 Balatro 的游戏安装文件。
- 本模组通过 Steamodded 的常规模组配置系统保存设置。
- 历史战绩会把对局记录写入 Balatro 当前配置档案，并限制记录数量，避免配置档案无限变大。
- 分数预览是沙盒试算，只作为参考，不保证完全替代真实计分动画。
- 对局回退和商店回退通过 Balatro 的对局保存/读取数据结构恢复检查点。保存额外外部状态的模组可能无法完全回退。

## 排查问题

如果出现问题，建议先只启用 Lovely、Steamodded 和 Balatro Comfort Pack 测试。

如果问题消失，再逐个启用其他模组，找出冲突来源。

## 许可证

GPL-3.0。详见仓库 `LICENSE`。

Balatro 归 LocalThunk / Playstack 所有。Lovely 和 Steamodded/SMODS 归其各自作者所有。本模组与上述作者或项目没有从属、授权或背书关系。
