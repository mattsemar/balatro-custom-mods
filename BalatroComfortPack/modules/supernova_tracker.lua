local MoreJokerInfo = rawget(_G, "BalatroMoreJokerInfo") or rawget(_G, "BalatroSupernovaTracker") or {}
_G.BalatroMoreJokerInfo = MoreJokerInfo
_G.BalatroSupernovaTracker = MoreJokerInfo

local MOD_VERSION = "1.0.3"

MoreJokerInfo.version = MOD_VERSION

local function language_key()
    local lang = G and G.SETTINGS and (G.SETTINGS.real_language or G.SETTINGS.language) or nil
    return type(lang) == "string" and lang:lower() or ""
end

local function is_chinese_language()
    return language_key():sub(1, 2) == "zh"
end

local function is_traditional_chinese()
    local lang = language_key()
    if lang:sub(1, 2) ~= "zh" then return false end
    return lang:find("tw", 1, true)
        or lang:find("hk", 1, true)
        or lang:find("mo", 1, true)
        or lang:find("hant", 1, true)
        or lang:find("traditional", 1, true)
end

local function language_group()
    if not is_chinese_language() then return "en" end
    return is_traditional_chinese() and "zh_tw" or "zh_cn"
end

local text = {
    en = {
        supernova_title = "Supernova hand bonuses",
        supernova_none = "No poker hands played yet",
        baseball_title = "Current Baseball Card bonus",
        baseball_jokers = "Uncommon Jokers",
        baseball_total = "Total Mult",
        plus = "+",
        times = "X"
    },
    zh_cn = {
        supernova_title = "超新星牌型加成",
        supernova_none = "还没有打出过牌型",
        baseball_title = "当前棒球卡倍率",
        baseball_jokers = "罕见小丑牌",
        baseball_total = "总倍率",
        plus = "+",
        times = "×"
    },
    zh_tw = {
        supernova_title = "超新星牌型加成",
        supernova_none = "還沒有打出過牌型",
        baseball_title = "目前棒球卡倍率",
        baseball_jokers = "罕見小丑牌",
        baseball_total = "總倍率",
        plus = "+",
        times = "×"
    }
}

local poker_hand_fallbacks = {
    en = {
        ["Five of a Kind"] = "Five of a Kind",
        Flush = "Flush",
        ["Flush Five"] = "Flush Five",
        ["Flush House"] = "Flush House",
        ["Four of a Kind"] = "Four of a Kind",
        ["Full House"] = "Full House",
        ["High Card"] = "High Card",
        Pair = "Pair",
        ["Royal Flush"] = "Royal Flush",
        Straight = "Straight",
        ["Straight Flush"] = "Straight Flush",
        ["Three of a Kind"] = "Three of a Kind",
        ["Two Pair"] = "Two Pair"
    },
    zh_cn = {
        ["Five of a Kind"] = "五条",
        Flush = "同花",
        ["Flush Five"] = "同花五条",
        ["Flush House"] = "同花葫芦",
        ["Four of a Kind"] = "四条",
        ["Full House"] = "葫芦",
        ["High Card"] = "高牌",
        Pair = "对子",
        ["Royal Flush"] = "皇家同花顺",
        Straight = "顺子",
        ["Straight Flush"] = "同花顺",
        ["Three of a Kind"] = "三条",
        ["Two Pair"] = "两对"
    },
    zh_tw = {
        ["Five of a Kind"] = "五條",
        Flush = "同花",
        ["Flush Five"] = "同花五條",
        ["Flush House"] = "同花葫蘆",
        ["Four of a Kind"] = "四條",
        ["Full House"] = "葫蘆",
        ["High Card"] = "高牌",
        Pair = "對子",
        ["Royal Flush"] = "皇家同花順",
        Straight = "順子",
        ["Straight Flush"] = "同花順",
        ["Three of a Kind"] = "三條",
        ["Two Pair"] = "兩對"
    }
}

local poker_hand_order = {
    "Flush Five",
    "Flush House",
    "Five of a Kind",
    "Straight Flush",
    "Four of a Kind",
    "Full House",
    "Flush",
    "Straight",
    "Three of a Kind",
    "Two Pair",
    "Pair",
    "High Card"
}

local poker_hand_order_lookup = {}
for index, key in ipairs(poker_hand_order) do
    poker_hand_order_lookup[key] = index
end

local function loc(key)
    local lang = text[language_group()] or text.en
    return lang[key] or text.en[key] or key
end

local function localized_poker_hand(key)
    if type(localize) == "function" then
        local ok, result = pcall(localize, key, "poker_hands")
        if ok and type(result) == "string" and result ~= "" and result ~= "ERROR" then
            return result
        end
    end

    local group = language_group()
    local fallbacks = poker_hand_fallbacks[group] or poker_hand_fallbacks.en
    return fallbacks[key] or poker_hand_fallbacks.en[key] or tostring(key)
end

local function center(card)
    return card and card.config and card.config.center or nil
end

local function center_key(card)
    local card_center = center(card)
    return card_center and card_center.key or nil
end

local function is_supernova(card)
    return center_key(card) == "j_supernova"
end

local function is_baseball(card)
    return center_key(card) == "j_baseball"
end

local function first_colour(...)
    for i = 1, select("#", ...) do
        local colour = select(i, ...)
        if colour then return colour end
    end
    return { 1, 1, 1, 1 }
end

local function ui_colour(key)
    return G and G.C and G.C.UI and G.C.UI[key] or nil
end

local function tracker_black()
    local colours = G and G.C or {}
    return colours.BLACK or ui_colour("TRANSPARENT_DARK") or ui_colour("BACKGROUND_INACTIVE") or { 0, 0, 0, 0.95 }
end

local function tracker_white()
    local colours = G and G.C or {}
    return first_colour(colours.WHITE, ui_colour("TEXT_LIGHT"))
end

local function tracker_gold()
    local colours = G and G.C or {}
    return first_colour(colours.GOLD, colours.MONEY, colours.ORANGE, colours.MULT, ui_colour("TEXT_LIGHT"))
end

local function hand_name_scale(name)
    if is_chinese_language() then return 0.24 end
    local length = type(name) == "string" and #name or 0
    if length >= 15 then return 0.185 end
    if length >= 12 then return 0.2 end
    return 0.22
end

local function collect_hand_rows()
    local hands = G and G.GAME and G.GAME.hands
    if type(hands) ~= "table" then return {} end

    local rows = {}
    local added = {}

    for _, key in ipairs(poker_hand_order) do
        local data = hands[key]
        rows[#rows + 1] = {
            key = key,
            name = localized_poker_hand(key),
            played = type(data) == "table" and tonumber(data.played) or 0,
            order = poker_hand_order_lookup[key] or 999
        }
        added[key] = true
    end

    local extra_rows = {}
    for key, data in pairs(hands) do
        if not added[key] and type(data) == "table" and data.visible ~= false then
            extra_rows[#extra_rows + 1] = {
                key = key,
                name = localized_poker_hand(key),
                played = tonumber(data.played) or 0,
                order = tonumber(data.order) or 999
            }
        end
    end

    table.sort(extra_rows, function(a, b)
        if a.order == b.order then return a.key < b.key end
        return a.order < b.order
    end)

    for _, row in ipairs(extra_rows) do
        rows[#rows + 1] = row
    end

    return rows
end

local function make_text(text_value, colour, scale)
    return {
        n = G.UIT.T,
        config = {
            text = text_value,
            colour = colour,
            scale = scale,
            shadow = true
        }
    }
end

local function make_info_chip(label, value, value_colour, label_scale, value_scale, minw)
    return {
        n = G.UIT.C,
        config = {
            align = "cm",
            padding = 0.045,
            r = 0.08,
            colour = tracker_black(),
            minw = minw or 2.18,
            minh = 0.42
        },
        nodes = {
            make_text(label, tracker_white(), label_scale or 0.23),
            make_text(" " .. value, value_colour or tracker_gold(), value_scale or 0.26)
        }
    }
end

local function make_banner(label, scale)
    return {
        n = G.UIT.C,
        config = {
            align = "cm",
            padding = 0.045,
            r = 0.08,
            colour = tracker_black(),
            minw = 4.48,
            minh = 0.38
        },
        nodes = { make_text(label, tracker_white(), scale or (is_chinese_language() and 0.27 or 0.25)) }
    }
end

local function make_hand_chip(row)
    return make_info_chip(
        row.name,
        loc("plus") .. tostring(row.played),
        tracker_gold(),
        hand_name_scale(row.name),
        is_chinese_language() and 0.28 or 0.26,
        2.18
    )
end

local function can_show_supernova()
    return G and G.GAME and type(G.GAME.hands) == "table"
end

local function can_show_baseball()
    return G and G.jokers and type(G.jokers.cards) == "table"
end

local function build_supernova_desc_rows()
    local rows = collect_hand_rows()
    local desc_rows = {
        { make_banner(loc("supernova_title")) }
    }

    if #rows == 0 then
        desc_rows[#desc_rows + 1] = { make_banner(loc("supernova_none"), is_chinese_language() and 0.24 or 0.22) }
        return desc_rows
    end

    local index = 1
    while index <= #rows do
        local row_nodes = {}
        for _ = 1, 2 do
            if rows[index] then
                row_nodes[#row_nodes + 1] = make_hand_chip(rows[index])
            end
            index = index + 1
        end
        desc_rows[#desc_rows + 1] = row_nodes
    end

    return desc_rows
end

local function is_joker_card(card)
    local card_center = center(card)
    return card
        and (card.ability and card.ability.set == "Joker" or card_center and card_center.set == "Joker")
end

local function is_uncommon_rarity(rarity)
    if rarity == 2 then return true end
    if type(rarity) ~= "string" then return false end

    local normalized = rarity:lower()
    return normalized == "2" or normalized == "uncommon"
end

local function is_uncommon_joker(card)
    local card_center = center(card)
    return is_joker_card(card) and card_center and is_uncommon_rarity(card_center.rarity)
end

local function baseball_xmult(card)
    local ability_extra = card and card.ability and card.ability.extra or nil
    if type(ability_extra) == "number" then return ability_extra end
    if type(ability_extra) == "table" then
        if type(ability_extra.x_mult) == "number" then return ability_extra.x_mult end
        if type(ability_extra.Xmult) == "number" then return ability_extra.Xmult end
        if type(ability_extra.xmult) == "number" then return ability_extra.xmult end
    end

    local card_center = center(card)
    local center_extra = card_center and card_center.config and card_center.config.extra or nil
    if type(center_extra) == "number" then return center_extra end
    return 1.5
end

local function uncommon_joker_count(baseball_card)
    if not can_show_baseball() then return 0 end

    local count = 0
    for _, joker in ipairs(G.jokers.cards) do
        if joker ~= baseball_card and is_uncommon_joker(joker) then
            count = count + 1
        end
    end
    return count
end

local function trim_number(value)
    local formatted = string.format("%.2f", value or 0)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    return formatted
end

local function format_xmult(value)
    return loc("times") .. trim_number(value)
end

local function build_baseball_desc_rows(card)
    local count = uncommon_joker_count(card)
    local per_joker = baseball_xmult(card)
    local total = 1
    for _ = 1, count do
        total = total * per_joker
    end

    return {
        { make_banner(loc("baseball_title")) },
        {
            make_info_chip(loc("baseball_jokers"), tostring(count), tracker_gold(), is_chinese_language() and 0.24 or 0.21, 0.28, 2.18),
            make_info_chip(loc("baseball_total"), format_xmult(total), tracker_gold(), is_chinese_language() and 0.24 or 0.21, 0.28, 2.18)
        }
    }
end

local function append_desc_rows(ui, rows)
    if type(ui) ~= "table" or type(ui.main) ~= "table" then return ui end

    for _, row in ipairs(rows) do
        if type(row) == "table" and row.n == nil then
            ui.main[#ui.main + 1] = row
        end
    end
    return ui
end

local function append_supernova_info(ui)
    if not can_show_supernova() then return ui end
    return append_desc_rows(ui, build_supernova_desc_rows())
end

local function append_baseball_info(ui, card)
    if not can_show_baseball() then return ui end
    return append_desc_rows(ui, build_baseball_desc_rows(card))
end

if Card and Card.generate_UIBox_ability_table and not MoreJokerInfo.hooked then
    MoreJokerInfo.original_generate_UIBox_ability_table = Card.generate_UIBox_ability_table

    function Card:generate_UIBox_ability_table()
        local ui = MoreJokerInfo.original_generate_UIBox_ability_table(self)
        if is_supernova(self) then
            return append_supernova_info(ui)
        end
        if is_baseball(self) then
            return append_baseball_info(ui, self)
        end
        return ui
    end

    MoreJokerInfo.hooked = true
end
