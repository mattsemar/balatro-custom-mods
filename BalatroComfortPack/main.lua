local Suite = rawget(_G, "BalatroComfortPack") or rawget(_G, "BalatroBetterExperience") or rawget(_G, "BalatroUtilitySuite") or {}
_G.BalatroComfortPack = Suite
_G.BalatroBetterExperience = Suite
_G.BalatroUtilitySuite = Suite

Suite.version = "1.0.4"
Suite.status = Suite.status or {}
Suite.ui = Suite.ui or {}

local current_mod = SMODS and SMODS.current_mod or nil
local config = current_mod and current_mod.config or {}

local features = {
    {
        key = "modifier_warning",
        group = "qol",
        file = "modules/modifier_warning.lua",
        standalone_id = "BalatroModifierWarning",
        global = "BalatroModifierWarning",
        label = {
            en = "Modifier Warning",
            zh_cn = "覆盖提醒",
            zh_tw = "覆蓋提醒"
        },
        desc = {
            en = "Warns before enhancement or seal replacement.",
            zh_cn = "增强或蜡封被覆盖时提示。",
            zh_tw = "增強或蠟封被覆蓋時提示。"
        }
    },
    {
        key = "run_history",
        group = "qol",
        file = "modules/run_history.lua",
        standalone_id = "BalatroRunArchive",
        global = "BalatroRunArchive",
        label = {
            en = "Run History",
            zh_cn = "历史战绩",
            zh_tw = "歷史戰績"
        },
        desc = {
            en = "Records runs, final decks, vouchers, and stats.",
            zh_cn = "记录对局、牌组、优惠券和统计。",
            zh_tw = "記錄對局、牌組、優惠券和統計。"
        }
    },
    {
        key = "supernova_tracker",
        group = "qol",
        file = "modules/supernova_tracker.lua",
        standalone_id = "BalatroSupernovaTracker",
        global = "BalatroSupernovaTracker",
        label = {
            en = "More Joker Info",
            zh_cn = "更多小丑牌信息",
            zh_tw = "更多小丑牌資訊"
        },
        desc = {
            en = "Shows clearer Supernova and Baseball Card info.",
            zh_cn = "显示更清晰的超新星和棒球卡信息。",
            zh_tw = "顯示更清晰的超新星和棒球卡資訊。"
        }
    },
    {
        key = "score_preview",
        group = "balance",
        file = "modules/score_preview.lua",
        standalone_id = "BalatroScorePreview",
        global = "BalatroScorePreview",
        label = {
            en = "Score Preview",
            zh_cn = "分数预览",
            zh_tw = "分數預覽"
        },
        desc = {
            en = "Shows a reference score before playing.",
            zh_cn = "出牌前显示参考分数。",
            zh_tw = "出牌前顯示參考分數。"
        }
    },
    {
        key = "shop_undo",
        group = "balance",
        file = "modules/shop_undo.lua",
        standalone_id = "BalatroShopUndo",
        global = "BalatroShopUndo",
        label = {
            en = "Shop Undo",
            zh_cn = "商店回退",
            zh_tw = "商店回退"
        },
        desc = {
            en = "Undo shop buys, sells, and vouchers.",
            zh_cn = "回退误买、误卖、优惠券等操作。",
            zh_tw = "回退誤買、誤賣、優惠券等操作。"
        }
    },
    {
        key = "step_back",
        group = "balance",
        file = "modules/step_back.lua",
        standalone_id = "BalatroStepBack",
        global = "BalatroStepBack",
        label = {
            en = "Step Back",
            zh_cn = "对局回退",
            zh_tw = "對局回退"
        },
        desc = {
            en = "Adds checkpoints before plays and discards.",
            zh_cn = "出牌或弃牌前创建回退点。",
            zh_tw = "出牌或棄牌前建立回退點。"
        }
    }
}

local groups = {
    qol = {
        title = {
            en = "Quality of Life",
            zh_cn = "体验优化",
            zh_tw = "體驗優化"
        },
        subtitle = {
            en = "Low-impact helpers that mainly improve clarity.",
            zh_cn = "改善信息展示，基本不改变平衡。",
            zh_tw = "改善資訊展示，基本不改變平衡。"
        }
    },
    balance = {
        title = {
            en = "Balance-Affecting",
            zh_cn = "影响平衡",
            zh_tw = "影響平衡"
        },
        subtitle = {
            en = "Convenience features that can change decisions or reduce risk.",
            zh_cn = "会影响决策或降低失误成本。",
            zh_tw = "會影響決策或降低失誤成本。"
        }
    }
}

local text = {
    en = {
        title = "Balatro Comfort Pack",
        restart = "Changes are saved immediately. Restart the game for loaded modules to change.",
        on = "ON",
        off = "OFF",
        loaded = "Loaded",
        disabled = "Off",
        external = "Standalone",
        error = "Error",
        feature = "Feature",
        description = "Description",
        status = "Current",
        next_run = "Setting",
        standalone_note = "Standalone = handled by the separate mod."
    },
    zh_cn = {
        title = "小丑牌舒适包",
        restart = "开关会立刻保存；要改变已加载模块，请重启游戏。",
        on = "开",
        off = "关",
        loaded = "已加载",
        disabled = "未加载",
        external = "单独版",
        error = "错误",
        feature = "功能",
        description = "说明",
        status = "当前",
        next_run = "设置",
        standalone_note = "单独版 = 由单独版 mod 接管。"
    },
    zh_tw = {
        title = "小丑牌舒適包",
        restart = "開關會立刻儲存；要改變已載入模組，請重啟遊戲。",
        on = "開",
        off = "關",
        loaded = "已載入",
        disabled = "未載入",
        external = "單獨版",
        error = "錯誤",
        feature = "功能",
        description = "說明",
        status = "目前",
        next_run = "設定",
        standalone_note = "單獨版 = 由單獨版 mod 接管。"
    }
}

local function language_key()
    local lang = G and G.SETTINGS and (G.SETTINGS.real_language or G.SETTINGS.language) or nil
    return type(lang) == "string" and lang:lower() or ""
end

local function language_group()
    local lang = language_key()
    if lang:sub(1, 2) ~= "zh" then return "en" end
    if lang:find("tw", 1, true) or lang:find("hk", 1, true) or lang:find("mo", 1, true)
        or lang:find("hant", 1, true) or lang:find("traditional", 1, true) then
        return "zh_tw"
    end
    return "zh_cn"
end

local function loc(key)
    local group = language_group()
    return (text[group] and text[group][key]) or (text.en and text.en[key]) or key
end

local function loc_pack(pack)
    local group = language_group()
    return (pack and pack[group]) or (pack and pack.en) or ""
end

local function is_enabled(key)
    return config[key] == true
end

local function save_config()
    if current_mod and SMODS and SMODS.save_mod_config then
        current_mod.config = config
        SMODS.save_mod_config(current_mod)
    end
end

local function standalone_mod_available(feature)
    local id = feature.standalone_id or feature.global
    if id and SMODS and SMODS.Mods and type(SMODS.Mods[id]) == "table" then
        local mod = SMODS.Mods[id]
        if (not current_mod or mod.id ~= current_mod.id) and mod.disabled ~= true and mod.can_load ~= false then
            return true
        end
    end

    return feature.global and rawget(_G, feature.global) ~= nil
end

local function load_feature(feature)
    if standalone_mod_available(feature) then
        Suite.status[feature.key] = "external"
        return
    end

    if not is_enabled(feature.key) then
        Suite.status[feature.key] = "disabled"
        return
    end

    local loader, err = SMODS.load_file(feature.file, current_mod and current_mod.id)
    if type(loader) ~= "function" then
        Suite.status[feature.key] = "error"
        Suite.status[feature.key .. "_error"] = tostring(err or "unknown error")
        return
    end

    local ok, load_err = pcall(loader)
    if ok then
        Suite.status[feature.key] = "loaded"
    else
        Suite.status[feature.key] = "error"
        Suite.status[feature.key .. "_error"] = tostring(load_err or "unknown error")
    end
end

for _, feature in ipairs(features) do
    load_feature(feature)
end

local function update_labels()
    for _, feature in ipairs(features) do
        local enabled = is_enabled(feature.key)
        local status = Suite.status[feature.key] or (enabled and "loaded" or "disabled")
        Suite.ui[feature.key .. "_toggle"] = enabled and loc("on") or loc("off")
        Suite.ui[feature.key .. "_status"] = loc(status)
    end
end

local function register_toggle(feature)
    local func_name = "comfortpack_toggle_" .. feature.key
    G.FUNCS[func_name] = function(e)
        config[feature.key] = not is_enabled(feature.key)
        save_config()
        update_labels()
        if e and e.config then
            e.config.colour = is_enabled(feature.key) and G.C.GREEN or G.C.RED
        end
    end
    return func_name
end

local toggle_funcs = {}
for _, feature in ipairs(features) do
    toggle_funcs[feature.key] = register_toggle(feature)
end

local function text_node(value, scale, colour)
    return {
        n = G.UIT.T,
        config = {
            text = value or "",
            scale = scale or 0.32,
            colour = colour or G.C.UI.TEXT_LIGHT,
            shadow = true
        }
    }
end

local function ref_text_node(ref_table, ref_value, scale, colour)
    return {
        n = G.UIT.T,
        config = {
            ref_table = ref_table,
            ref_value = ref_value,
            scale = scale or 0.28,
            colour = colour or G.C.UI.TEXT_LIGHT,
            shadow = true
        }
    }
end

local column_widths = {
    feature = 2.45,
    description = 4.85,
    status = 1.55,
    next_run = 1.0
}

local function status_colour(status)
    if status == "loaded" then return G.C.GREEN end
    if status == "external" then return G.C.ORANGE end
    if status == "error" then return G.C.RED end
    return G.C.UI.TEXT_LIGHT
end

local function header_cell(label_key, width)
    return {
        n = G.UIT.C,
        config = { align = "cm", minw = width, maxw = width, padding = 0.035 },
        nodes = { text_node(loc(label_key), 0.25, G.C.MONEY) }
    }
end

local function feature_header_row()
    return {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.015,
            r = 0.06,
            colour = G.C.UI.TRANSPARENT_DARK
        },
        nodes = {
            header_cell("feature", column_widths.feature),
            header_cell("description", column_widths.description),
            header_cell("status", column_widths.status),
            header_cell("next_run", column_widths.next_run)
        }
    }
end

local function feature_row(feature)
    local enabled = is_enabled(feature.key)
    local status = Suite.status[feature.key] or (enabled and "loaded" or "disabled")
    local button_colour = enabled and G.C.GREEN or G.C.RED
    return {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.035,
            r = 0.08,
            colour = G.C.UI.TRANSPARENT_DARK
        },
        nodes = {
            {
                n = G.UIT.C,
                config = { align = "cl", minw = column_widths.feature, maxw = column_widths.feature, padding = 0.04 },
                nodes = { text_node(loc_pack(feature.label), 0.34, G.C.WHITE) }
            },
            {
                n = G.UIT.C,
                config = { align = "cl", minw = column_widths.description, maxw = column_widths.description, padding = 0.04 },
                nodes = { text_node(loc_pack(feature.desc), 0.29, G.C.MONEY) }
            },
            {
                n = G.UIT.C,
                config = { align = "cm", minw = column_widths.status, maxw = column_widths.status, padding = 0.04 },
                nodes = { ref_text_node(Suite.ui, feature.key .. "_status", 0.27, status_colour(status)) }
            },
            {
                n = G.UIT.C,
                config = {
                    align = "cm",
                    minw = column_widths.next_run,
                    minh = 0.42,
                    padding = 0.04,
                    r = 0.08,
                    colour = button_colour,
                    button = toggle_funcs[feature.key],
                    hover = true,
                    shadow = true
                },
                nodes = { ref_text_node(Suite.ui, feature.key .. "_toggle", 0.32, G.C.WHITE) }
            }
        }
    }
end

local function group_section(group_key)
    local info = groups[group_key]
    local rows = {
        {
            n = G.UIT.R,
            config = { align = "cl", padding = 0.02 },
            nodes = { text_node(loc_pack(info.title), 0.42, G.C.ORANGE) }
        },
        {
            n = G.UIT.R,
            config = { align = "cl", padding = 0.01 },
            nodes = { text_node(loc_pack(info.subtitle), 0.29, G.C.WHITE) }
        },
        feature_header_row()
    }

    for _, feature in ipairs(features) do
        if feature.group == group_key then
            rows[#rows + 1] = feature_row(feature)
        end
    end

    return {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.06,
            r = 0.1,
            colour = G.C.UI.BACKGROUND_INACTIVE
        },
        nodes = {
            {
                n = G.UIT.C,
                config = { align = "cm", minw = 10.6, padding = 0.04 },
                nodes = rows
            }
        }
    }
end

if current_mod then
    current_mod.config_tab = function()
        update_labels()
        return {
            n = G.UIT.ROOT,
            config = {
                align = "cm",
                padding = 0.06,
                colour = G.C.CLEAR
            },
            nodes = {
                {
                    n = G.UIT.C,
                    config = { align = "cm", minw = 11.0, padding = 0.06 },
                    nodes = {
                        {
                            n = G.UIT.R,
                            config = { align = "cm", padding = 0.02 },
                            nodes = { text_node(loc("title"), 0.46, G.C.UI.TEXT_LIGHT) }
                        },
                        group_section("qol"),
                        group_section("balance"),
                        {
                            n = G.UIT.R,
                            config = { align = "cm", padding = 0.04 },
                            nodes = { text_node(loc("restart"), 0.29, G.C.MONEY) }
                        },
                        {
                            n = G.UIT.R,
                            config = { align = "cm", padding = 0.01 },
                            nodes = { text_node(loc("standalone_note"), 0.25, G.C.WHITE) }
                        }
                    }
                }
            }
        }
    end
end
