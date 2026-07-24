local RunArchive = rawget(_G, "BalatroRunArchive") or {}
_G.BalatroRunArchive = RunArchive

RunArchive.list_page = RunArchive.list_page or 1
RunArchive.detail_id = RunArchive.detail_id or nil
RunArchive.detail_tab = RunArchive.detail_tab or "overview"
RunArchive.archive_tab = RunArchive.archive_tab or "runs"
RunArchive.filter_result = RunArchive.filter_result or "all"
RunArchive.filter_deck = RunArchive.filter_deck or "all"
RunArchive.filter_stake = RunArchive.filter_stake or "all"
RunArchive.sort_mode = RunArchive.sort_mode or "newest"
RunArchive.confirm_clear = RunArchive.confirm_clear or false
RunArchive.final_expanded = RunArchive.final_expanded or {}
RunArchive.final_pages = RunArchive.final_pages or {}

local ARCHIVE_KEY = "balatro_run_archive"
local CURRENT_KEY = "balatro_run_archive_current"
local ARCHIVE_FILE = "run_archive.jkr"
local ARCHIVE_VERSION = 1
local DEFAULT_MAX_RUNS = 50
-- Safety ceiling on the serialized (uncompressed) archive. A single Lua chunk cannot
-- exceed LuaJIT's hard limit of 65,536 constants, so we keep the file well under that
-- even if the run-count cap is raised or individual runs are unusually heavy.
local MAX_ARCHIVE_BYTES = 5 * 1024 * 1024
local MAX_EVENTS = 80
local MAX_HANDS = 100
local MAX_FINAL_CARDS = 140
local LIST_PAGE_SIZE = 5
local FINAL_CARD_PAGE_SIZE = 32
local FINAL_CARD_ROW_SIZE = 8
local FINAL_CARD_SCALE = 0.42

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
        archive = "Run History",
        archive_short = "History",
        title = "Run History",
        empty = "No runs recorded yet",
        back = "Back",
        detail = "Details",
        overview = "Overview",
        final = "Final State",
        history = "History",
        prev = "Prev",
        next = "Next",
        page = "Page ",
        win = "Win",
        loss = "Loss",
        endless_loss = "Win / Endless ended",
        in_progress = "In Progress",
        abandoned = "Unfinished",
        stats = "Wins #1# / Losses #2# / Streak #3# / Best #4#",
        run_no = "Run #",
        deck = "Deck",
        stake = "Stake",
        seed = "Seed",
        result = "Result",
        started = "Started",
        finished = "Finished",
        ante = "Ante",
        round = "Round",
        blind = "Blind",
        money = "Money",
        best_hand = "Best hand",
        jokers = "Jokers",
        consumables = "Consumables",
        deck_cards = "Deck cards",
        vouchers = "Vouchers",
        tags = "Tags",
        hands = "Played / discarded",
        events = "Shop / use events",
        none = "None",
        more = " +#1# more",
        show = "Show",
        hide = "Hide",
        section_page = "#1#/#2#",
        play = "Play",
        discard = "Discard",
        buy = "Buy",
        sell = "Sell",
        use = "Use",
        redeem = "Voucher",
        cards = "Cards",
        score = "Score",
        seeded = "Seeded",
        challenge = "Challenge",
        yes = "Yes",
        no = "No",
        record_title = "Record #1#",
        runs_tab = "Runs",
        stats_tab = "Stats",
        filter_result = "Result",
        filter_deck = "Deck",
        filter_stake = "Stake",
        sort = "Sort",
        all = "All",
        sort_newest = "Newest",
        sort_oldest = "Oldest",
        sort_best_score = "Best score",
        sort_farthest_ante = "Farthest ante",
        clear_archive = "Clear history",
        confirm_clear = "Confirm clear",
        cancel_clear = "Cancel",
        total_runs = "Runs",
        win_rate = "Win rate",
        current_streak = "Current streak",
        best_streak = "Best streak",
        highest_stake_streak = "Highest-stake streak",
        farthest_endless = "Farthest endless",
        by_deck = "By deck",
        spades = "Spades",
        hearts = "Hearts",
        clubs = "Clubs",
        diamonds = "Diamonds",
        other_suit = "Other"
    },
    zh_cn = {
        archive = "历史战绩",
        archive_short = "战绩",
        title = "历史战绩",
        empty = "还没有记录到对局",
        back = "返回",
        detail = "详情",
        overview = "概览",
        final = "最终状态",
        history = "历史记录",
        prev = "上一页",
        next = "下一页",
        page = "第 ",
        win = "胜利",
        loss = "失败",
        endless_loss = "胜利 / 无尽止步",
        in_progress = "进行中",
        abandoned = "未完成",
        stats = "胜 #1# / 负 #2# / 连胜 #3# / 最高 #4#",
        run_no = "第 ",
        deck = "卡组",
        stake = "难度",
        seed = "Seed",
        result = "结果",
        started = "开始",
        finished = "结束",
        ante = "底注",
        round = "回合",
        blind = "盲注",
        money = "金钱",
        best_hand = "最高单手",
        jokers = "小丑牌",
        consumables = "消耗牌",
        deck_cards = "牌组",
        vouchers = "优惠券",
        tags = "标签",
        hands = "出牌 / 弃牌",
        events = "商店 / 用牌事件",
        none = "无",
        more = " 另有 #1# 个",
        show = "展开",
        hide = "收起",
        section_page = "#1#/#2#",
        play = "出牌",
        discard = "弃牌",
        buy = "购买",
        sell = "出售",
        use = "使用",
        redeem = "兑换券",
        cards = "牌",
        score = "得分",
        seeded = "指定 Seed",
        challenge = "挑战",
        yes = "是",
        no = "否",
        record_title = "记录 #1#",
        runs_tab = "对局",
        stats_tab = "统计",
        filter_result = "结果",
        filter_deck = "卡组",
        filter_stake = "难度",
        sort = "排序",
        all = "全部",
        sort_newest = "最新",
        sort_oldest = "最早",
        sort_best_score = "最高分",
        sort_farthest_ante = "最远底注",
        clear_archive = "清空记录",
        confirm_clear = "确认清空",
        cancel_clear = "取消",
        total_runs = "对局数",
        win_rate = "胜率",
        current_streak = "当前连胜",
        best_streak = "最高连胜",
        highest_stake_streak = "最高难度连胜",
        farthest_endless = "最远无尽",
        by_deck = "按卡组",
        spades = "黑桃",
        hearts = "红桃",
        clubs = "梅花",
        diamonds = "方片",
        other_suit = "其他"
    },
    zh_tw = {
        archive = "歷史戰績",
        archive_short = "戰績",
        title = "歷史戰績",
        empty = "還沒有記錄到對局",
        back = "返回",
        detail = "詳情",
        overview = "概覽",
        final = "最終狀態",
        history = "歷史記錄",
        prev = "上一頁",
        next = "下一頁",
        page = "第 ",
        win = "勝利",
        loss = "失敗",
        endless_loss = "勝利 / 無盡止步",
        in_progress = "進行中",
        abandoned = "未完成",
        stats = "勝 #1# / 負 #2# / 連勝 #3# / 最高 #4#",
        run_no = "第 ",
        deck = "牌組",
        stake = "難度",
        seed = "Seed",
        result = "結果",
        started = "開始",
        finished = "結束",
        ante = "底注",
        round = "回合",
        blind = "盲注",
        money = "金錢",
        best_hand = "最高單手",
        jokers = "小丑牌",
        consumables = "消耗牌",
        deck_cards = "牌組",
        vouchers = "優惠券",
        tags = "標籤",
        hands = "出牌 / 棄牌",
        events = "商店 / 用牌事件",
        none = "無",
        more = " 另有 #1# 個",
        show = "展開",
        hide = "收起",
        section_page = "#1#/#2#",
        play = "出牌",
        discard = "棄牌",
        buy = "購買",
        sell = "出售",
        use = "使用",
        redeem = "兌換券",
        cards = "牌",
        score = "得分",
        seeded = "指定 Seed",
        challenge = "挑戰",
        yes = "是",
        no = "否",
        record_title = "記錄 #1#",
        runs_tab = "對局",
        stats_tab = "統計",
        filter_result = "結果",
        filter_deck = "牌組",
        filter_stake = "難度",
        sort = "排序",
        all = "全部",
        sort_newest = "最新",
        sort_oldest = "最早",
        sort_best_score = "最高分",
        sort_farthest_ante = "最遠底注",
        clear_archive = "清空記錄",
        confirm_clear = "確認清空",
        cancel_clear = "取消",
        total_runs = "對局數",
        win_rate = "勝率",
        current_streak = "目前連勝",
        best_streak = "最高連勝",
        highest_stake_streak = "最高難度連勝",
        farthest_endless = "最遠無盡",
        by_deck = "按牌組",
        spades = "黑桃",
        hearts = "紅桃",
        clubs = "梅花",
        diamonds = "方片",
        other_suit = "其他"
    }
}

local function loc(key)
    local lang = text[language_group()] or text.en
    return lang[key] or text.en[key] or key
end

local function fill(template, ...)
    local values = { ... }
    return (template or ""):gsub("#(%d+)#", function(i)
        return tostring(values[tonumber(i)] or "")
    end)
end

local poker_hand_names = {
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

local suit_names = {
    en = {
        Spades = "S",
        Hearts = "H",
        Clubs = "C",
        Diamonds = "D"
    },
    zh_cn = {
        Spades = "黑",
        Hearts = "红",
        Clubs = "梅",
        Diamonds = "方"
    },
    zh_tw = {
        Spades = "黑",
        Hearts = "紅",
        Clubs = "梅",
        Diamonds = "方"
    }
}

local rank_short = {
    Ace = "A",
    King = "K",
    Queen = "Q",
    Jack = "J",
    ["10"] = "10",
    ["9"] = "9",
    ["8"] = "8",
    ["7"] = "7",
    ["6"] = "6",
    ["5"] = "5",
    ["4"] = "4",
    ["3"] = "3",
    ["2"] = "2"
}

local suit_order = { Spades = 1, Hearts = 2, Clubs = 3, Diamonds = 4 }
local rank_order = { Ace = 1, King = 2, Queen = 3, Jack = 4, ["10"] = 5, ["9"] = 6, ["8"] = 7, ["7"] = 8, ["6"] = 9, ["5"] = 10, ["4"] = 11, ["3"] = 12, ["2"] = 13 }

local function localized_suit_name(suit)
    if suit == "Spades" then return loc("spades") end
    if suit == "Hearts" then return loc("hearts") end
    if suit == "Clubs" then return loc("clubs") end
    if suit == "Diamonds" then return loc("diamonds") end
    return loc("other_suit")
end

local edition_names = {
    en = { negative = "Negative", foil = "Foil", holo = "Holographic", polychrome = "Polychrome" },
    zh_cn = { negative = "负片", foil = "闪箔", holo = "镭射", polychrome = "多彩" },
    zh_tw = { negative = "負片", foil = "閃箔", holo = "雷射", polychrome = "多彩" }
}

local seal_names = {
    en = { Gold = "Gold Seal", Red = "Red Seal", Blue = "Blue Seal", Purple = "Purple Seal" },
    zh_cn = { Gold = "金蜡封", Red = "红蜡封", Blue = "蓝蜡封", Purple = "紫蜡封" },
    zh_tw = { Gold = "金蠟封", Red = "紅蠟封", Blue = "藍蠟封", Purple = "紫蠟封" }
}

local function now_text()
    if os and os.date then
        local ok, result = pcall(os.date, "%Y-%m-%d %H:%M")
        if ok and result then return result end
    end
    return "Unknown time"
end

local function number_text(value)
    if value == nil then return "-" end
    if type(number_format) == "function" then
        local ok, result = pcall(number_format, value)
        if ok and result then return tostring(result) end
    end
    return tostring(math.floor(tonumber(value) or 0))
end

local function plain_copy(value, depth)
    depth = depth or 0
    if depth > 8 then return nil end
    if type(value) ~= "table" then return value end

    local out = {}
    for k, v in pairs(value) do
        if type(k) ~= "table" and type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
            out[k] = plain_copy(v, depth + 1)
        end
    end
    return out
end

local current_mod = SMODS and SMODS.current_mod or nil

local function profile()
    if not G or not G.PROFILES or not G.SETTINGS or not G.SETTINGS.profile then return nil end
    return G.PROFILES[G.SETTINGS.profile]
end

-- Cap on archived runs. Config-driven (mod config key `run_history_max_runs`), with a
-- sensible default. The ring buffer keeps the newest runs and drops the oldest.
local function max_runs()
    local cfg = current_mod and type(current_mod.config) == "table" and current_mod.config or nil
    local value = cfg and tonumber(cfg.run_history_max_runs) or nil
    if value and value >= 1 then return math.floor(value) end
    return DEFAULT_MAX_RUNS
end

-- The archive lives in its own file (ARCHIVE_FILE) under the profile directory, NOT in
-- profile.jkr. It is loaded lazily on first access and cached for the session, so the
-- profile chunk the game compiles at launch never carries the archive.
local archive_state = nil
local archive_loaded = false

local function archive_file_path()
    if not G or not G.SETTINGS or G.SETTINGS.profile == nil then return nil end
    return tostring(G.SETTINGS.profile) .. "/" .. ARCHIVE_FILE
end

local function empty_archive()
    return { version = ARCHIVE_VERSION, next_id = 1, runs = {} }
end

local function normalize_archive(a)
    if type(a) ~= "table" then return empty_archive() end
    a.version = ARCHIVE_VERSION
    a.next_id = tonumber(a.next_id) or 1
    if type(a.runs) ~= "table" then a.runs = {} end
    return a
end

local function trim_to_cap(a)
    local cap = max_runs()
    while #a.runs > cap do
        table.remove(a.runs)
    end
end

local function load_archive_file()
    local path = archive_file_path()
    if not path or type(get_compressed) ~= "function" or type(STR_UNPACK) ~= "function" then return nil end
    local ok, contents = pcall(get_compressed, path)
    if not ok or type(contents) ~= "string" or contents == "" then return nil end
    local parsed_ok, parsed = pcall(STR_UNPACK, contents)
    if not parsed_ok or type(parsed) ~= "table" then return nil end
    return normalize_archive(parsed)
end

local function save_archive()
    if not archive_loaded or type(archive_state) ~= "table" then return end
    local path = archive_file_path()
    if not path or type(compress_and_save) ~= "function" then return end
    trim_to_cap(archive_state)
    -- Never let the serialized archive approach the LuaJIT constant limit. Drop the
    -- oldest runs until the packed size is safe, independent of the run-count cap.
    if type(STR_PACK) == "function" then
        while #archive_state.runs > 1 do
            local ok, packed = pcall(STR_PACK, archive_state)
            if not ok or type(packed) ~= "string" or #packed <= MAX_ARCHIVE_BYTES then break end
            table.remove(archive_state.runs)
        end
    end
    pcall(compress_and_save, path, archive_state)
end

-- One-time migration. Older versions stored the archive inside profile.jkr under
-- ARCHIVE_KEY, which could push the profile chunk past the LuaJIT constant limit and
-- crash the game on launch. Move any such data into ARCHIVE_FILE (truncated to the cap)
-- and delete the key from the profile so loadable-but-bloated saves get healed. This
-- runs entirely on in-memory tables, so it cannot itself trigger the constant crash.
local function migrate_from_profile()
    local p = profile()
    if not p or type(p[ARCHIVE_KEY]) ~= "table" then return false end

    local legacy = p[ARCHIVE_KEY]
    if #archive_state.runs == 0 then
        archive_state.next_id = tonumber(legacy.next_id) or archive_state.next_id or 1
        archive_state.runs = {}
        if type(legacy.runs) == "table" then
            for _, run in ipairs(legacy.runs) do
                archive_state.runs[#archive_state.runs + 1] = run
            end
        end
        trim_to_cap(archive_state)
    end

    p[ARCHIVE_KEY] = nil
    if G and type(G.save_settings) == "function" then
        pcall(function() G:save_settings() end)
    end
    return true
end

local function archive()
    if archive_loaded then return archive_state end
    archive_state = load_archive_file() or empty_archive()
    archive_loaded = true
    if migrate_from_profile() then
        save_archive()
    end
    return archive_state
end

local function localized_name(key, set, fallback)
    if key and set and type(localize) == "function" then
        local ok, result = pcall(localize, { type = "name_text", key = key, set = set })
        if ok and result and result ~= "ERROR" then
            return tostring(result)
        end
    end
    return fallback or key or "?"
end

local function localized_poker_hand(hand_key)
    if not hand_key or hand_key == "" then return "-" end
    if type(localize) == "function" then
        local ok, result = pcall(localize, hand_key, "poker_hands")
        if ok and result and result ~= "ERROR" then
            return tostring(result)
        end
    end
    local names = poker_hand_names[language_group()] or poker_hand_names.en
    return names[hand_key] or tostring(hand_key)
end

local function edition_key(card)
    if not card or type(card.edition) ~= "table" then return nil end
    if card.edition.negative then return "negative" end
    if card.edition.polychrome then return "polychrome" end
    if card.edition.holo then return "holo" end
    if card.edition.foil then return "foil" end
    return nil
end

local function center_data(card)
    local center = card and card.config and card.config.center or nil
    if not center then return nil, nil, nil end
    return center.key or card.config.center_key, center.set or (card.ability and card.ability.set), center.name or card.ability and card.ability.name
end

local function card_save_data(card)
    if not card or type(card.save) ~= "function" then return nil end
    local ok, saved = pcall(function() return card:save() end)
    if ok and type(saved) == "table" then
        return plain_copy(saved)
    end
    return nil
end

local function card_key_data(card)
    if not card then return nil end
    local card_key = card.config and card.config.card_key or nil
    local front = card.config and card.config.card or nil
    if (not card_key or not (G.P_CARDS and G.P_CARDS[card_key])) and G.P_CARDS and front then
        for key, value in pairs(G.P_CARDS) do
            if value == front then
                card_key = key
                break
            end
        end
    end
    if (not card_key or not (G.P_CARDS and G.P_CARDS[card_key])) and G.P_CARDS and card.base then
        for key, value in pairs(G.P_CARDS) do
            if value and value.suit == card.base.suit and value.value == card.base.value then
                card_key = key
                break
            end
        end
    end
    if (not card_key or not (G.P_CARDS and G.P_CARDS[card_key])) and SMODS and SMODS.Suits and SMODS.Ranks and card.base then
        local suit = SMODS.Suits[card.base.suit]
        local rank = SMODS.Ranks[card.base.value]
        if suit and rank and suit.card_key and rank.card_key then
            card_key = suit.card_key .. "_" .. rank.card_key
        end
    end
    return card_key
end

local function card_data(card)
    if not card then return { fallback = "?" } end

    local key, set, fallback = center_data(card)
    local data = {
        key = key,
        center_key = key,
        set = set,
        fallback = fallback,
        card_key = card_key_data(card),
        card_state = card_save_data(card),
        seal = card.seal,
        edition = edition_key(card)
    }

    if card.base then
        data.base = plain_copy(card.base)
        data.rank = card.base.value or card.base.id
        data.suit = card.base.suit
    end

    if set == "Enhanced" or (key and key ~= "c_base" and key ~= "m_base" and key ~= "Base") then
        data.enhancement_key = key
        data.enhancement_set = set
        data.enhancement_name = fallback
    end

    return data
end

local function area_cards(area, limit)
    local cards = {}
    if not area or type(area.cards) ~= "table" then return cards, 0 end
    local total = #area.cards
    for i = 1, math.min(total, limit or total) do
        cards[#cards + 1] = card_data(area.cards[i])
    end
    return cards, total
end

local function playing_cards(limit)
    local cards = {}
    local source = G and G.playing_cards or nil
    if type(source) ~= "table" then return cards, 0 end
    for i = 1, math.min(#source, limit or #source) do
        cards[#cards + 1] = card_data(source[i])
    end
    return cards, #source
end

local function current_ante()
    return G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil
end

local function current_round()
    return G and G.GAME and G.GAME.round or nil
end

local function blind_data()
    local blind = G and G.GAME and G.GAME.blind or nil
    if not blind then return nil, nil, nil end
    local config = blind.config and blind.config.blind or nil
    return config and config.key or nil, config and config.name or blind.name, blind.name
end

local function localized_blind(item)
    if not item then return "-" end
    return localized_name(item.blind_key, "Blind", item.blind_name or item.blind_fallback)
end

local function selected_back_data()
    if not G or not G.GAME then return nil, nil, nil end
    local center = G.GAME.selected_back_key or (G.GAME.selected_back and G.GAME.selected_back.effect and G.GAME.selected_back.effect.center)
    if center then
        return center.key, center.set or "Back", center.name or G.GAME.selected_back and G.GAME.selected_back.name
    end
    if G.GAME.selected_back then
        return nil, "Back", G.GAME.selected_back.name
    end
    return nil, "Back", nil
end

local function localized_deck(run)
    if not run then return "-" end
    return localized_name(run.deck_key, run.deck_set or "Back", run.deck_name or run.deck_key or "-")
end

local function localized_stake(run)
    if not run or not run.stake then return "-" end
    local stake_center = G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[run.stake] or nil
    if stake_center then
        return localized_name(stake_center.key, stake_center.set or "Stake", stake_center.name)
    end
    return loc("stake") .. " " .. tostring(run.stake)
end

local function current_run_record()
    if not G or not G.GAME then return nil end
    local current = G.GAME[CURRENT_KEY]
    if type(current) ~= "table" then return nil end
    return current
end

local function upsert_run(run, should_save)
    if type(run) ~= "table" or not run.id then return end
    local a = archive()
    if not a then return end

    local copy = plain_copy(run)
    for i, existing in ipairs(a.runs) do
        if existing.id == copy.id then
            a.runs[i] = copy
            if should_save then save_archive() end
            return
        end
    end

    table.insert(a.runs, 1, copy)
    trim_to_cap(a)
    if should_save then save_archive() end
end

local function create_new_run_record()
    local a = archive()
    if not a or not G or not G.GAME then return nil end

    local deck_key, deck_set, deck_name = selected_back_data()
    local blind_key, blind_name, blind_fallback = blind_data()
    local id = a.next_id or 1
    a.next_id = id + 1

    local current = {
        version = ARCHIVE_VERSION,
        id = id,
        status = "in_progress",
        result = "in_progress",
        started_at = now_text(),
        updated_at = now_text(),
        deck_key = deck_key,
        deck_set = deck_set or "Back",
        deck_name = deck_name,
        stake = G.GAME.stake,
        seed = G.GAME.pseudorandom and G.GAME.pseudorandom.seed or nil,
        seeded = G.GAME.seeded and true or false,
        challenge = G.GAME.challenge,
        start_ante = current_ante(),
        final_ante = current_ante(),
        final_round = current_round(),
        blind_key = blind_key,
        blind_name = blind_name,
        blind_fallback = blind_fallback,
        best_hand_score = 0,
        events = {},
        hands = {}
    }

    G.GAME[CURRENT_KEY] = current
    RunArchive.current = current
    upsert_run(current, true)
    return current
end

local function ensure_current_run()
    local current = current_run_record()
    if current then
        RunArchive.current = current
        return current
    end
    return create_new_run_record()
end

local function sync_saved_current_to_profile()
    if G and G.SAVED_GAME and G.SAVED_GAME.GAME and type(G.SAVED_GAME.GAME[CURRENT_KEY]) == "table" then
        upsert_run(G.SAVED_GAME.GAME[CURRENT_KEY], false)
    end
end

local function trim_list(list, max)
    while #list > max do
        table.remove(list, 1)
    end
end

local function append_event(kind, card, extra)
    local current = ensure_current_run()
    if not current then return end
    local blind_key, blind_name, blind_fallback = blind_data()
    current.events = current.events or {}
    current.events[#current.events + 1] = {
        kind = kind,
        card = card and card_data(card) or nil,
        extra = extra,
        ante = current_ante(),
        round = current_round(),
        blind_key = blind_key,
        blind_name = blind_name,
        blind_fallback = blind_fallback,
        at = now_text()
    }
    trim_list(current.events, MAX_EVENTS)
    current.updated_at = now_text()
end

local function highlighted_cards()
    local cards = {}
    if not G or not G.hand or type(G.hand.highlighted) ~= "table" then return cards end
    for _, card in ipairs(G.hand.highlighted) do
        cards[#cards + 1] = card_data(card)
    end
    return cards
end

local function append_hand(kind)
    local current = ensure_current_run()
    if not current then return end

    local hand_key = nil
    if kind == "play" and G and G.FUNCS and type(G.FUNCS.get_poker_hand_info) == "function" then
        local ok, text_key = pcall(function()
            return G.FUNCS.get_poker_hand_info(G.hand.highlighted)
        end)
        if ok and text_key and text_key ~= "NULL" then
            hand_key = text_key
        end
    end

    local blind_key, blind_name, blind_fallback = blind_data()
    current.hands = current.hands or {}
    current.hands[#current.hands + 1] = {
        kind = kind,
        hand_key = hand_key,
        cards = highlighted_cards(),
        ante = current_ante(),
        round = current_round(),
        blind_key = blind_key,
        blind_name = blind_name,
        blind_fallback = blind_fallback,
        at = now_text()
    }
    trim_list(current.hands, MAX_HANDS)
    current.updated_at = now_text()
end

local function snapshot_final_state(current)
    if not current or not G or not G.GAME then return end
    local blind_key, blind_name, blind_fallback = blind_data()

    current.updated_at = now_text()
    current.final_ante = current_ante()
    current.final_round = current_round()
    current.blind_key = blind_key or current.blind_key
    current.blind_name = blind_name or current.blind_name
    current.blind_fallback = blind_fallback or current.blind_fallback
    current.final_money = G.GAME.dollars
    current.hands_left = G.GAME.current_round and G.GAME.current_round.hands_left or nil
    current.discards_left = G.GAME.current_round and G.GAME.current_round.discards_left or nil
    current.win_ante = G.GAME.win_ante
    current.endless_reached = (G.GAME.round_resets and G.GAME.win_ante and G.GAME.round_resets.ante > G.GAME.win_ante) or G.GAME.won or false

    current.final_jokers, current.final_joker_count = area_cards(G.jokers, 40)
    current.final_consumables, current.final_consumable_count = area_cards(G.consumeables, 20)
    current.final_deck, current.final_deck_count = playing_cards(MAX_FINAL_CARDS)

    current.vouchers = {}
    for key, used in pairs(G.GAME.used_vouchers or {}) do
        if used then current.vouchers[#current.vouchers + 1] = { key = key, set = "Voucher" } end
    end

    current.tags = {}
    for _, tag in ipairs(G.GAME.tags or {}) do
        if tag then current.tags[#current.tags + 1] = { key = tag.key, fallback = tag.name } end
    end

    local scores = G.GAME.round_scores or {}
    current.cards_played = scores.cards_played and scores.cards_played.amt or current.cards_played
    current.cards_discarded = scores.cards_discarded and scores.cards_discarded.amt or current.cards_discarded
    current.cards_purchased = scores.cards_purchased and scores.cards_purchased.amt or current.cards_purchased
    current.times_rerolled = scores.times_rerolled and scores.times_rerolled.amt or current.times_rerolled
end

local function finalize_run(result)
    local current = ensure_current_run()
    if not current then return end

    snapshot_final_state(current)

    if result == "win" then
        current.won = true
        if current.result ~= "endless_loss" then
            current.result = "win"
            current.status = "finished"
            current.finished_at = current.finished_at or now_text()
        end
    elseif result == "endless_loss" then
        current.won = true
        current.result = "endless_loss"
        current.status = "finished"
        current.finished_at = now_text()
    elseif result == "loss" then
        current.result = current.won and "endless_loss" or "loss"
        current.status = "finished"
        current.finished_at = now_text()
    end

    G.GAME[CURRENT_KEY] = current
    upsert_run(current, true)
end

local function result_label(run)
    if not run then return "-" end
    return loc(run.result or run.status or "in_progress")
end

local function format_card(item)
    if not item then return "?" end
    local lang = language_group()
    local base = nil
    if item.rank and item.suit then
        local suits = suit_names[lang] or suit_names.en
        base = (rank_short[tostring(item.rank)] or tostring(item.rank)) .. (suits[item.suit] or tostring(item.suit))
    else
        base = localized_name(item.key, item.set, item.fallback)
    end

    local extras = {}
    if item.enhancement_key and item.enhancement_set == "Enhanced" then
        extras[#extras + 1] = localized_name(item.enhancement_key, item.enhancement_set, item.enhancement_name)
    end
    if item.edition then
        local editions = edition_names[lang] or edition_names.en
        extras[#extras + 1] = editions[item.edition] or item.edition
    end
    if item.seal then
        local seals = seal_names[lang] or seal_names.en
        extras[#extras + 1] = seals[item.seal] or tostring(item.seal)
    end

    if #extras > 0 then
        return base .. " [" .. table.concat(extras, ", ") .. "]"
    end
    return base
end

local function format_card_list(cards, limit)
    if type(cards) ~= "table" or #cards == 0 then return loc("none") end
    limit = limit or #cards
    local parts = {}
    for i = 1, math.min(#cards, limit) do
        parts[#parts + 1] = format_card(cards[i])
    end
    if #cards > limit then
        parts[#parts + 1] = fill(loc("more"), #cards - limit)
    end
    return table.concat(parts, ", ")
end

local function format_key_list(items, set, limit)
    if type(items) ~= "table" or #items == 0 then return loc("none") end
    limit = limit or #items
    local parts = {}
    for i = 1, math.min(#items, limit) do
        local item = items[i]
        parts[#parts + 1] = localized_name(item.key, item.set or set, item.fallback)
    end
    if #items > limit then
        parts[#parts + 1] = fill(loc("more"), #items - limit)
    end
    return table.concat(parts, ", ")
end

local function hand_line(entry)
    if not entry then return "" end
    local kind = loc(entry.kind or "play")
    local hand = entry.hand_key and (" / " .. localized_poker_hand(entry.hand_key)) or ""
    local cards = format_card_list(entry.cards, 8)
    return kind .. hand .. ": " .. cards
end

local function event_line(entry)
    if not entry then return "" end
    local kind = loc(entry.kind or "use")
    local card = entry.card and format_card(entry.card) or ""
    return kind .. ": " .. card
end

local text_node
local label_colour
local secondary_colour
local simple_button

local function front_from_archive_card(item)
    if not item or not G or not G.P_CARDS then return nil end
    if item.card_key and G.P_CARDS[item.card_key] then
        return G.P_CARDS[item.card_key]
    end
    if item.card_state and item.card_state.save_fields and item.card_state.save_fields.card then
        local key = item.card_state.save_fields.card
        if G.P_CARDS[key] then return G.P_CARDS[key] end
    end
    local base = item.base
    if not base and item.rank and item.suit then
        base = { value = item.rank, suit = item.suit }
    end
    if base then
        for _, value in pairs(G.P_CARDS) do
            if value and value.suit == base.suit and value.value == base.value then
                return value
            end
        end
    end
    return G.P_CARDS.empty
end

local function center_from_archive_card(item, fallback_set)
    if not item or not G or not G.P_CENTERS then return nil end
    local key = item.center_key or item.enhancement_key or item.key
    if (not key or not G.P_CENTERS[key]) and item.card_state and item.card_state.save_fields then
        key = item.card_state.save_fields.center
    end
    if key and G.P_CENTERS[key] then return G.P_CENTERS[key] end
    if fallback_set == "Voucher" and G.P_CENTERS.v_blank then return G.P_CENTERS.v_blank end
    return G.P_CENTERS.c_base
end

local function edition_table_from_key(key)
    if not key then return nil end
    return { [key] = true, type = key }
end

local function archive_card_state_value(item, key)
    if item and item.card_state and item.card_state[key] ~= nil then
        return item.card_state[key]
    end
    return nil
end

local function create_archive_card(item, scale, fallback_set)
    if type(item) ~= "table" or not Card or not G or not G.P_CENTERS then return nil end
    scale = scale or FINAL_CARD_SCALE

    local center = center_from_archive_card(item, fallback_set)
    if not center then return nil end

    local front = nil
    if center.set ~= "Joker" and center.set ~= "Voucher" and center.set ~= "Tarot" and center.set ~= "Planet" and center.set ~= "Spectral" then
        front = front_from_archive_card(item)
    end

    local params = archive_card_state_value(item, "params")
    params = type(params) == "table" and plain_copy(params) or {}
    params.bypass_discovery_center = true
    params.bypass_discovery_ui = true
    params.bypass_lock = true
    if center.set ~= "Joker" and center.set ~= "Voucher" and params.playing_card == nil then
        params.playing_card = archive_card_state_value(item, "playing_card") or item.playing_card or true
    end

    local card = Card(0, 0, G.CARD_W * scale, G.CARD_H * scale, front, center, params)
    if not card then return nil end

    local ability = archive_card_state_value(item, "ability")
    local base = archive_card_state_value(item, "base") or item.base
    local edition = archive_card_state_value(item, "edition") or edition_table_from_key(item.edition)

    if ability then card.ability = plain_copy(ability) end
    if base then card.base = plain_copy(base) end
    if edition then card.edition = plain_copy(edition) end
    card.seal = archive_card_state_value(item, "seal") or item.seal
    card.debuff = archive_card_state_value(item, "debuff") or item.debuff
    card.pinned = archive_card_state_value(item, "pinned") or item.pinned
    card.facing = archive_card_state_value(item, "facing") or item.facing or card.facing
    card.sprite_facing = archive_card_state_value(item, "sprite_facing") or item.sprite_facing or card.sprite_facing

    card.states.hover.can = true
    card.states.drag.can = false
    card.states.click.can = false
    card.states.collide.can = true
    return card
end

local function final_section_page_count(items)
    return math.max(1, math.ceil(#(items or {}) / FINAL_CARD_PAGE_SIZE))
end

local function clamp_final_section_page(key, items)
    RunArchive.final_pages[key] = RunArchive.final_pages[key] or 1
    local pages = final_section_page_count(items)
    RunArchive.final_pages[key] = math.max(1, math.min(RunArchive.final_pages[key], pages))
    return pages, RunArchive.final_pages[key]
end

local function reopen_detail_overlay()
    if G and G.FUNCS and G.FUNCS.overlay_menu then
        G.FUNCS.overlay_menu({ definition = create_UIBox_run_archive_detail() })
    end
end

local function archive_card_base(item)
    if not item then return nil end
    local base = archive_card_state_value(item, "base") or item.base
    if type(base) == "table" then return base end
    if item.rank or item.suit then return { value = item.rank, suit = item.suit } end
    return nil
end

local function archive_card_suit(item)
    local base = archive_card_base(item)
    return (base and base.suit) or (item and item.suit) or "Other"
end

local function archive_card_rank(item)
    local base = archive_card_base(item)
    return (base and (base.value or base.id)) or (item and item.rank) or ""
end

local function sorted_deck_items(items)
    local sorted = {}
    if type(items) ~= "table" then return sorted end
    for _, item in ipairs(items) do sorted[#sorted + 1] = item end
    table.sort(sorted, function(a, b)
        local suit_a = archive_card_suit(a)
        local suit_b = archive_card_suit(b)
        local suit_rank_a = suit_order[suit_a] or 99
        local suit_rank_b = suit_order[suit_b] or 99
        if suit_rank_a ~= suit_rank_b then return suit_rank_a < suit_rank_b end

        local rank_a = archive_card_rank(a)
        local rank_b = archive_card_rank(b)
        local rank_sort_a = rank_order[tostring(rank_a)] or 99
        local rank_sort_b = rank_order[tostring(rank_b)] or 99
        if rank_sort_a ~= rank_sort_b then return rank_sort_a < rank_sort_b end

        return format_card(a) < format_card(b)
    end)
    return sorted
end

local function create_archive_card_rows(items, section_key, fallback_set)
    if type(items) ~= "table" or #items == 0 or not CardArea or not Card then return nil end

    local display_items = section_key == "deck" and sorted_deck_items(items) or items
    local pages, page = clamp_final_section_page(section_key, display_items)
    local start_i = ((page - 1) * FINAL_CARD_PAGE_SIZE) + 1
    local end_i = math.min(#display_items, start_i + FINAL_CARD_PAGE_SIZE - 1)
    local outer_rows = {}
    local row_cards = {}
    local current_suit = nil

    local function add_suit_header(suit)
        outer_rows[#outer_rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.015 }, nodes = {
            { n = G.UIT.C, config = { align = "cl", minw = 10.2, padding = 0.02 }, nodes = {
                text_node(localized_suit_name(suit), is_chinese_language() and 0.24 or 0.21, label_colour(), true)
            }}
        }}
    end

    local function flush_row()
        if #row_cards == 0 then return true end
        local created_cards = {}
        for _, item in ipairs(row_cards) do
            local card = create_archive_card(item, FINAL_CARD_SCALE, fallback_set)
            if not card then
                for _, created in ipairs(created_cards) do
                    created:remove()
                end
                return false
            end
            created_cards[#created_cards + 1] = card
        end

        local area_width = math.max(1.2, math.min(10.2, 0.45 + #created_cards * G.CARD_W * FINAL_CARD_SCALE * 1.55))
        local area_height = G.CARD_H * FINAL_CARD_SCALE * 1.18
        local area = CardArea(
            0, 0,
            area_width,
            area_height,
            { card_limit = #created_cards, type = "title_2", view_deck = true, highlight_limit = 0, card_w = G.CARD_W * FINAL_CARD_SCALE, draw_layers = { "card" } }
        )

        for _, card in ipairs(created_cards) do
            card.T.x = area.T.x + area.T.w / 2
            card.T.y = area.T.y
            area:emplace(card, nil, card.facing == "back")
        end

        outer_rows[#outer_rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.015 }, nodes = {
            { n = G.UIT.O, config = { object = area, can_collide = true } }
        }}
        row_cards = {}
        return true
    end

    for i = start_i, end_i do
        local item = display_items[i]
        if section_key == "deck" then
            local suit = archive_card_suit(item)
            if suit ~= current_suit then
                if not flush_row() then return nil end
                add_suit_header(suit)
                current_suit = suit
            end
        end

        row_cards[#row_cards + 1] = item
        if #row_cards == FINAL_CARD_ROW_SIZE or i == end_i then
            if not flush_row() then return nil end
        end
    end

    if pages > 1 then
        local prev_func = "runarchive_" .. section_key .. "_prev"
        local next_func = "runarchive_" .. section_key .. "_next"
        G.FUNCS[prev_func] = function()
            RunArchive.final_pages[section_key] = (RunArchive.final_pages[section_key] or 1) - 1
            clamp_final_section_page(section_key, display_items)
            reopen_detail_overlay()
        end
        G.FUNCS[next_func] = function()
            RunArchive.final_pages[section_key] = (RunArchive.final_pages[section_key] or 1) + 1
            clamp_final_section_page(section_key, display_items)
            reopen_detail_overlay()
        end
        outer_rows[#outer_rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = {
            simple_button(loc("prev"), prev_func, page > 1 and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE, 1.2),
            { n = G.UIT.C, config = { align = "cm", minw = 1.2, padding = 0.03 }, nodes = {
                text_node(fill(loc("section_page"), page, pages), 0.22, secondary_colour(), true)
            }},
            simple_button(loc("next"), next_func, page < pages and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE, 1.2)
        }}
    end

    if #outer_rows == 0 then return nil end
    return { n = G.UIT.R, config = {
        align = "cm",
        padding = 0.04,
        r = 0.08,
        colour = G.C.UI.TRANSPARENT_DARK,
        minw = 10.6,
        minh = math.max(0.9, (G.CARD_H * FINAL_CARD_SCALE * 1.16) * math.min(4, #outer_rows))
    }, nodes = {
        { n = G.UIT.C, config = { align = "cm", padding = 0.02 }, nodes = outer_rows }
    }}
end

local function is_win_result(result)
    return result == "win" or result == "endless_loss"
end

local function compute_stats(runs)
    local stats = {
        total = 0,
        finished = 0,
        wins = 0,
        losses = 0,
        current_streak = 0,
        best_streak = 0,
        best_hand = 0,
        furthest_ante = 0,
        farthest_endless_ante = 0,
        highest_stake = nil,
        highest_stake_streak = 0,
        deck_rows = {}
    }
    if type(runs) ~= "table" then return stats end

    stats.total = #runs
    local deck_stats = {}
    local highest_stake_value = nil
    for _, run in ipairs(runs) do
        local stake_value = tonumber(run.stake)
        if stake_value and (not highest_stake_value or stake_value > highest_stake_value) then
            highest_stake_value = stake_value
            stats.highest_stake = run.stake
        end
    end

    local high_streak = 0
    for i = #runs, 1, -1 do
        local run = runs[i]
        local result = run.result
        local won = is_win_result(result)
        local lost = result == "loss"

        if won or lost then
            stats.finished = stats.finished + 1
            local deck_key = run.deck_key or run.deck_name or "-"
            deck_stats[deck_key] = deck_stats[deck_key] or { name = localized_deck(run), wins = 0, total = 0 }
            deck_stats[deck_key].total = deck_stats[deck_key].total + 1
            if won then deck_stats[deck_key].wins = deck_stats[deck_key].wins + 1 end
        end

        if won then
            stats.wins = stats.wins + 1
            stats.current_streak = stats.current_streak + 1
            stats.best_streak = math.max(stats.best_streak, stats.current_streak)
        elseif lost then
            stats.losses = stats.losses + 1
            stats.current_streak = 0
        end

        if stats.highest_stake ~= nil and tostring(run.stake) == tostring(stats.highest_stake) then
            if won then
                high_streak = high_streak + 1
                stats.highest_stake_streak = math.max(stats.highest_stake_streak, high_streak)
            elseif lost then
                high_streak = 0
            end
        end

        local final_ante = tonumber(run.final_ante) or 0
        local win_ante = tonumber(run.win_ante) or 8
        stats.best_hand = math.max(stats.best_hand, tonumber(run.best_hand_score) or 0)
        stats.furthest_ante = math.max(stats.furthest_ante, final_ante)
        if final_ante > win_ante or run.endless_reached then
            stats.farthest_endless_ante = math.max(stats.farthest_endless_ante, final_ante)
        end
    end

    stats.win_rate = stats.finished > 0 and math.floor((stats.wins * 1000 / stats.finished) + 0.5) / 10 or 0
    for _, row in pairs(deck_stats) do
        row.rate = row.total > 0 and math.floor((row.wins * 1000 / row.total) + 0.5) / 10 or 0
        stats.deck_rows[#stats.deck_rows + 1] = row
    end
    table.sort(stats.deck_rows, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        if a.rate ~= b.rate then return a.rate > b.rate end
        return tostring(a.name) < tostring(b.name)
    end)

    return stats
end

local function find_run(id)
    local a = archive()
    if not a then return nil end
    for _, run in ipairs(a.runs or {}) do
        if run.id == id then return run end
    end
    return nil
end

function text_node(value, scale, colour, shadow)
    return { n = G.UIT.T, config = { text = tostring(value or ""), scale = scale or 0.32, colour = colour or G.C.UI.TEXT_LIGHT, shadow = shadow ~= false } }
end

function label_colour()
    return G.C.MONEY or G.C.GOLD or G.C.UI.TEXT_LIGHT
end

function secondary_colour()
    return G.C.UI.TEXT_LIGHT or G.C.WHITE
end

local function row_text(left, right, scale)
    return { n = G.UIT.R, config = { align = "cm", padding = 0.025 }, nodes = {
        { n = G.UIT.C, config = { align = "cr", minw = 2.35, maxw = 2.35, padding = 0.02 }, nodes = {
            text_node(left, scale or 0.28, label_colour(), true)
        }},
        { n = G.UIT.C, config = { align = "cl", minw = 8.4, maxw = 8.4, padding = 0.02 }, nodes = {
            text_node(right, scale or 0.28, G.C.UI.TEXT_LIGHT, true)
        }}
    }}
end

function simple_button(label, button, colour, minw)
    return { n = G.UIT.C, config = {
        align = "cm",
        padding = 0.05,
        r = 0.08,
        hover = true,
        shadow = true,
        colour = colour or G.C.BLUE,
        button = button,
        minw = minw or 1.25,
        minh = 0.45
    }, nodes = {
        text_node(label, is_chinese_language() and 0.27 or 0.24, G.C.UI.TEXT_LIGHT, true)
    }}
end

local function two_line_cell(primary, secondary, minw, scale, primary_colour, secondary_col)
    return { n = G.UIT.C, config = { align = "cl", minw = minw, maxw = minw, padding = 0.04 }, nodes = {
        { n = G.UIT.R, config = { align = "cl", padding = 0 }, nodes = {
            text_node(primary, scale, primary_colour or G.C.UI.TEXT_LIGHT, true)
        }},
        { n = G.UIT.R, config = { align = "cl", padding = 0.005 }, nodes = {
            text_node(secondary, scale * 0.82, secondary_col or secondary_colour(), true)
        }}
    }}
end

local result_filter_order = { "all", "win", "loss", "endless_loss", "in_progress" }
local sort_order = { "newest", "oldest", "best_score", "farthest_ante" }

local function filter_result_label(value)
    if value == "all" then return loc("all") end
    return loc(value or "all")
end

local function sort_label(value)
    return loc("sort_" .. tostring(value or "newest"))
end

local function deck_filter_value(run)
    return tostring(run and (run.deck_key or run.deck_name or "-") or "-")
end

local function stake_filter_value(run)
    return tostring(run and (run.stake or "-") or "-")
end

local function deck_filter_options(runs)
    local options = { { value = "all", label = loc("all") } }
    local seen = { all = true }
    if type(runs) == "table" then
        for _, run in ipairs(runs) do
            local value = deck_filter_value(run)
            if not seen[value] then
                seen[value] = true
                options[#options + 1] = { value = value, label = localized_deck(run) }
            end
        end
    end
    table.sort(options, function(a, b)
        if a.value == "all" then return true end
        if b.value == "all" then return false end
        return tostring(a.label) < tostring(b.label)
    end)
    return options
end

local function stake_filter_options(runs)
    local options = { { value = "all", label = loc("all") } }
    local seen = { all = true }
    if type(runs) == "table" then
        for _, run in ipairs(runs) do
            local value = stake_filter_value(run)
            if not seen[value] then
                seen[value] = true
                options[#options + 1] = { value = value, label = localized_stake(run) }
            end
        end
    end
    table.sort(options, function(a, b)
        if a.value == "all" then return true end
        if b.value == "all" then return false end
        local na = tonumber(a.value)
        local nb = tonumber(b.value)
        if na and nb and na ~= nb then return na < nb end
        return tostring(a.label) < tostring(b.label)
    end)
    return options
end

local function option_label(options, value)
    for _, option in ipairs(options or {}) do
        if tostring(option.value) == tostring(value) then return option.label end
    end
    return loc("all")
end

local function option_exists(options, value)
    for _, option in ipairs(options or {}) do
        if tostring(option.value) == tostring(value) then return true end
    end
    return false
end

local function list_contains(list, value)
    for _, item in ipairs(list or {}) do
        if tostring(item) == tostring(value) then return true end
    end
    return false
end

local function normalize_archive_filters(runs)
    if not list_contains(result_filter_order, RunArchive.filter_result) then RunArchive.filter_result = "all" end
    if not list_contains(sort_order, RunArchive.sort_mode) then RunArchive.sort_mode = "newest" end
    if not option_exists(deck_filter_options(runs), RunArchive.filter_deck) then RunArchive.filter_deck = "all" end
    if not option_exists(stake_filter_options(runs), RunArchive.filter_stake) then RunArchive.filter_stake = "all" end
end

local function cycle_option(current, options)
    if type(options) ~= "table" or #options == 0 then return "all" end
    local index = 1
    for i, option in ipairs(options) do
        if tostring(option.value) == tostring(current) then
            index = i
            break
        end
    end
    return options[(index % #options) + 1].value
end

local function filtered_sorted_runs(runs)
    local out = {}
    if type(runs) ~= "table" then return out end

    for _, run in ipairs(runs) do
        local include = true
        if RunArchive.filter_result ~= "all" then
            include = tostring(run.result or run.status or "in_progress") == tostring(RunArchive.filter_result)
        end
        if include and RunArchive.filter_deck ~= "all" then
            include = deck_filter_value(run) == tostring(RunArchive.filter_deck)
        end
        if include and RunArchive.filter_stake ~= "all" then
            include = stake_filter_value(run) == tostring(RunArchive.filter_stake)
        end
        if include then out[#out + 1] = run end
    end

    table.sort(out, function(a, b)
        local mode = RunArchive.sort_mode or "newest"
        if mode == "oldest" then return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end
        if mode == "best_score" then
            local av = tonumber(a.best_hand_score) or 0
            local bv = tonumber(b.best_hand_score) or 0
            if av ~= bv then return av > bv end
        elseif mode == "farthest_ante" then
            local av = tonumber(a.final_ante) or 0
            local bv = tonumber(b.final_ante) or 0
            if av ~= bv then return av > bv end
        end
        return (tonumber(a.id) or 0) > (tonumber(b.id) or 0)
    end)

    return out
end

local function visible_runs()
    local a = archive()
    local runs = a and a.runs or {}
    normalize_archive_filters(runs)
    return filtered_sorted_runs(runs)
end

local function page_count()
    local total = #visible_runs()
    return math.max(1, math.ceil(total / LIST_PAGE_SIZE))
end

local function clamp_page()
    local pages = page_count()
    RunArchive.list_page = math.max(1, math.min(RunArchive.list_page or 1, pages))
    return pages
end

local function reopen_archive()
    if G and G.FUNCS and G.FUNCS.overlay_menu then
        G.FUNCS.overlay_menu({ definition = create_UIBox_run_archive() })
    end
end

G.FUNCS.runarchive_prev_page = function()
    RunArchive.list_page = (RunArchive.list_page or 1) - 1
    clamp_page()
    reopen_archive()
end

G.FUNCS.runarchive_next_page = function()
    RunArchive.list_page = (RunArchive.list_page or 1) + 1
    clamp_page()
    reopen_archive()
end

G.FUNCS.runarchive_tab_runs = function()
    RunArchive.archive_tab = "runs"
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_tab_stats = function()
    RunArchive.archive_tab = "stats"
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_cycle_result = function()
    local options = {}
    for _, value in ipairs(result_filter_order) do options[#options + 1] = { value = value, label = filter_result_label(value) } end
    RunArchive.filter_result = cycle_option(RunArchive.filter_result or "all", options)
    RunArchive.list_page = 1
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_cycle_deck = function()
    local a = archive()
    RunArchive.filter_deck = cycle_option(RunArchive.filter_deck or "all", deck_filter_options(a and a.runs or {}))
    RunArchive.list_page = 1
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_cycle_stake = function()
    local a = archive()
    RunArchive.filter_stake = cycle_option(RunArchive.filter_stake or "all", stake_filter_options(a and a.runs or {}))
    RunArchive.list_page = 1
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_cycle_sort = function()
    local options = {}
    for _, value in ipairs(sort_order) do options[#options + 1] = { value = value, label = sort_label(value) } end
    RunArchive.sort_mode = cycle_option(RunArchive.sort_mode or "newest", options)
    RunArchive.list_page = 1
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_clear_request = function()
    local a = archive()
    if not a or #(a.runs or {}) == 0 then return end
    RunArchive.confirm_clear = true
    reopen_archive()
end

G.FUNCS.runarchive_clear_cancel = function()
    RunArchive.confirm_clear = false
    reopen_archive()
end

G.FUNCS.runarchive_clear_confirm = function()
    local a = archive()
    if a then
        a.runs = {}
        a.next_id = 1
    end
    if G and G.GAME then G.GAME[CURRENT_KEY] = nil end
    RunArchive.detail_id = nil
    RunArchive.list_page = 1
    RunArchive.confirm_clear = false
    save_archive()
    reopen_archive()
end

local function create_run_row(run)
    local detail_func = "runarchive_detail_" .. tostring(run.id)
    G.FUNCS[detail_func] = function()
        RunArchive.detail_id = run.id
        RunArchive.detail_tab = "overview"
        G.FUNCS.overlay_menu({ definition = create_UIBox_run_archive_detail() })
    end

    local scale = is_chinese_language() and 0.26 or 0.23
    local result_colour = (run.result == "win" or run.result == "endless_loss") and G.C.GREEN
        or (run.result == "loss" and G.C.RED or G.C.ORANGE)
    local summary = localized_deck(run) .. " / " .. localized_stake(run)
    local progress = loc("ante") .. " " .. tostring(run.final_ante or "-") .. " / " .. result_label(run)

    return { n = G.UIT.R, config = { align = "cm", padding = 0.05, r = 0.08, colour = G.C.UI.TRANSPARENT_DARK }, nodes = {
        { n = G.UIT.C, config = { align = "cl", minw = 1.05, maxw = 1.05, padding = 0.04 }, nodes = {
            text_node("#" .. tostring(run.id), scale, G.C.UI.TEXT_LIGHT, true)
        }},
        two_line_cell(summary, run.started_at or "-", 4.6, scale, G.C.UI.TEXT_LIGHT, G.C.UI.TEXT_LIGHT),
        two_line_cell(progress, loc("seed") .. ": " .. tostring(run.seed or "-"), 3.5, scale, result_colour, G.C.UI.TEXT_LIGHT),
        simple_button(loc("detail"), detail_func, G.C.BLUE, 1.1)
    }}
end

local function archive_tab_button(label, tab)
    local func = tab == "stats" and "runarchive_tab_stats" or "runarchive_tab_runs"
    return simple_button(label, func, RunArchive.archive_tab == tab and G.C.GREEN or G.C.BLUE, 1.6)
end

local function filter_button(label, value, func, minw)
    return simple_button(label .. ": " .. tostring(value or loc("all")), func, G.C.BLUE, minw or 2.45)
end

local function stats_line(label, value)
    return row_text(label, value, is_chinese_language() and 0.28 or 0.25)
end

local function create_stats_rows(stats)
    local rows = {}
    rows[#rows + 1] = stats_line(loc("total_runs"), tostring(stats.total or 0))
    rows[#rows + 1] = stats_line(loc("win_rate"), tostring(stats.win_rate or 0) .. "%  (" .. tostring(stats.wins or 0) .. "/" .. tostring(stats.finished or 0) .. ")")
    rows[#rows + 1] = stats_line(loc("current_streak"), tostring(stats.current_streak or 0))
    rows[#rows + 1] = stats_line(loc("best_streak"), tostring(stats.best_streak or 0))
    rows[#rows + 1] = stats_line(loc("highest_stake_streak"), tostring(stats.highest_stake_streak or 0))
    rows[#rows + 1] = stats_line(loc("best_hand"), number_text(stats.best_hand or 0))
    rows[#rows + 1] = stats_line(loc("ante"), tostring(stats.furthest_ante or 0))
    rows[#rows + 1] = stats_line(loc("farthest_endless"), (stats.farthest_endless_ante and stats.farthest_endless_ante > 0) and (loc("ante") .. " " .. tostring(stats.farthest_endless_ante)) or loc("none"))

    rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = {
        text_node(loc("by_deck"), 0.32, label_colour(), true)
    }}
    if #stats.deck_rows == 0 then
        rows[#rows + 1] = row_text("", loc("none"))
    else
        for i = 1, math.min(#stats.deck_rows, 8) do
            local deck = stats.deck_rows[i]
            rows[#rows + 1] = stats_line(deck.name, tostring(deck.rate or 0) .. "%  (" .. tostring(deck.wins or 0) .. "/" .. tostring(deck.total or 0) .. ")")
        end
    end
    return rows
end

function create_UIBox_run_archive()
    sync_saved_current_to_profile()
    local a = archive()
    local all_runs = a and a.runs or {}
    local runs = visible_runs()
    local stats = compute_stats(all_runs)
    local pages = clamp_page()
    local page = RunArchive.list_page or 1
    local start_i = ((page - 1) * LIST_PAGE_SIZE) + 1
    local end_i = math.min(#runs, start_i + LIST_PAGE_SIZE - 1)
    local deck_options = deck_filter_options(all_runs)
    local stake_options = stake_filter_options(all_runs)

    local rows = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            text_node(loc("title"), 0.52, G.C.UI.TEXT_LIGHT, true)
        }},
        { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = {
            text_node(fill(loc("stats"), stats.wins, stats.losses, stats.current_streak, stats.best_streak), is_chinese_language() and 0.28 or 0.25, G.C.MONEY, true)
        }},
        { n = G.UIT.R, config = { align = "cm", padding = 0.035 }, nodes = {
            archive_tab_button(loc("runs_tab"), "runs"),
            archive_tab_button(loc("stats_tab"), "stats")
        }}
    }

    if RunArchive.archive_tab == "stats" then
        for _, row in ipairs(create_stats_rows(stats)) do rows[#rows + 1] = row end
    else
        rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
            filter_button(loc("filter_result"), filter_result_label(RunArchive.filter_result), "runarchive_cycle_result", 2.35),
            filter_button(loc("filter_deck"), option_label(deck_options, RunArchive.filter_deck), "runarchive_cycle_deck", 2.85),
            filter_button(loc("filter_stake"), option_label(stake_options, RunArchive.filter_stake), "runarchive_cycle_stake", 2.35),
            filter_button(loc("sort"), sort_label(RunArchive.sort_mode), "runarchive_cycle_sort", 2.45)
        }}

        if #runs == 0 then
            rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.18 }, nodes = {
                text_node(loc("empty"), 0.35, G.C.UI.TEXT_LIGHT, true)
            }}
        else
            for i = start_i, end_i do
                rows[#rows + 1] = create_run_row(runs[i])
            end
        end

        if pages > 1 then
            rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = {
                simple_button(loc("prev"), "runarchive_prev_page", page > 1 and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE, 1.3),
                { n = G.UIT.C, config = { align = "cm", minw = 1.4, padding = 0.04 }, nodes = {
                    text_node(loc("page") .. tostring(page) .. "/" .. tostring(pages), 0.25, G.C.UI.TEXT_LIGHT, true)
                }},
                simple_button(loc("next"), "runarchive_next_page", page < pages and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE, 1.3)
            }}
        end

        if RunArchive.confirm_clear then
            rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = {
                simple_button(loc("confirm_clear"), "runarchive_clear_confirm", G.C.RED, 2.1),
                simple_button(loc("cancel_clear"), "runarchive_clear_cancel", G.C.BLUE, 1.5)
            }}
        else
            rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = {
                simple_button(loc("clear_archive"), "runarchive_clear_request", #all_runs > 0 and G.C.RED or G.C.UI.BACKGROUND_INACTIVE, 2.2)
            }}
        end
    end

    return create_UIBox_generic_options({
        back_label = loc("back"),
        back_func = "options",
        minw = 13.2,
        contents = rows
    })
end

local function detail_tab_button(label, tab)
    local func = "runarchive_tab_" .. tab
    G.FUNCS[func] = function()
        RunArchive.detail_tab = tab
        G.FUNCS.overlay_menu({ definition = create_UIBox_run_archive_detail() })
    end
    return simple_button(label, func, RunArchive.detail_tab == tab and G.C.GREEN or G.C.BLUE, 1.65)
end

local function detail_overview(run)
    local rows = {}
    rows[#rows + 1] = row_text(loc("result"), result_label(run))
    rows[#rows + 1] = row_text(loc("deck"), localized_deck(run))
    rows[#rows + 1] = row_text(loc("stake"), localized_stake(run))
    rows[#rows + 1] = row_text(loc("seed"), tostring(run.seed or "-"))
    rows[#rows + 1] = row_text(loc("seeded"), run.seeded and loc("yes") or loc("no"))
    if run.challenge then rows[#rows + 1] = row_text(loc("challenge"), tostring(run.challenge)) end
    rows[#rows + 1] = row_text(loc("ante"), tostring(run.final_ante or "-"))
    rows[#rows + 1] = row_text(loc("round"), tostring(run.final_round or "-"))
    rows[#rows + 1] = row_text(loc("blind"), localized_blind(run))
    rows[#rows + 1] = row_text(loc("money"), "$" .. tostring(run.final_money or "-"))
    rows[#rows + 1] = row_text(loc("best_hand"), number_text(run.best_hand_score or 0))
    rows[#rows + 1] = row_text(loc("started"), run.started_at or "-")
    rows[#rows + 1] = row_text(loc("finished"), run.finished_at or run.updated_at or "-")
    return rows
end

local function final_section_header(label, items, key)
    local count = type(items) == "table" and #items or 0
    local expanded = RunArchive.final_expanded[key] and true or false
    local func = "runarchive_toggle_" .. key
    G.FUNCS[func] = function()
        RunArchive.final_expanded[key] = not RunArchive.final_expanded[key]
        RunArchive.final_pages[key] = 1
        reopen_detail_overlay()
    end

    return { n = G.UIT.R, config = { align = "cm", padding = 0.035, r = 0.08, colour = G.C.UI.TRANSPARENT_DARK }, nodes = {
        { n = G.UIT.C, config = { align = "cl", minw = 9.3, maxw = 9.3, padding = 0.04 }, nodes = {
            text_node(label .. "  " .. tostring(count), 0.28, label_colour(), true)
        }},
        simple_button(expanded and loc("hide") or loc("show"), func, count > 0 and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE, 1.1)
    }}
end

local function append_final_section(rows, label, items, key, fallback_set)
    rows[#rows + 1] = final_section_header(label, items, key)
    if not RunArchive.final_expanded[key] or type(items) ~= "table" or #items == 0 then return end

    local card_rows = create_archive_card_rows(items, key, fallback_set)
    if card_rows then
        rows[#rows + 1] = card_rows
    else
        rows[#rows + 1] = row_text("", format_card_list(items, 18), is_chinese_language() and 0.21 or 0.18)
    end
end

local function detail_final(run)
    local rows = {}
    append_final_section(rows, loc("jokers"), run.final_jokers or {}, "jokers", "Joker")
    append_final_section(rows, loc("deck_cards"), run.final_deck or {}, "deck", "Enhanced")
    append_final_section(rows, loc("vouchers"), run.vouchers or {}, "vouchers", "Voucher")
    return rows
end

function create_UIBox_run_archive_detail()
    local run = find_run(RunArchive.detail_id)
    if RunArchive.detail_tab ~= "final" then RunArchive.detail_tab = "overview" end
    local rows = {
        { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            text_node((run and fill(loc("record_title"), run.id) or loc("title")), 0.48, G.C.UI.TEXT_LIGHT, true)
        }},
        { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
            detail_tab_button(loc("overview"), "overview"),
            detail_tab_button(loc("final"), "final")
        }}
    }

    if not run then
        rows[#rows + 1] = row_text("", loc("empty"))
    elseif RunArchive.detail_tab == "final" then
        for _, row in ipairs(detail_final(run)) do rows[#rows + 1] = row end
    else
        for _, row in ipairs(detail_overview(run)) do rows[#rows + 1] = row end
    end

    return create_UIBox_generic_options({
        back_label = loc("back"),
        back_func = "runarchive_open",
        minw = 13.2,
        contents = rows
    })
end

G.FUNCS.runarchive_open = function()
    sync_saved_current_to_profile()
    RunArchive.list_page = 1
    G.FUNCS.overlay_menu({ definition = create_UIBox_run_archive() })
end

local function create_options_archive_button()
    return UIBox_button({
        id = "runarchive_options_button",
        button = "runarchive_open",
        colour = G.C.PURPLE or G.C.BLUE,
        minw = 5,
        label = { loc("archive") },
        scale = is_chinese_language() and 0.45 or 0.42
    })
end

local function options_contents_nodes(t)
    return t
        and t.nodes and t.nodes[1]
        and t.nodes[1].nodes and t.nodes[1].nodes[1]
        and t.nodes[1].nodes[1].nodes and t.nodes[1].nodes[1].nodes[1]
        and t.nodes[1].nodes[1].nodes[1].nodes
        or nil
end

local function is_button_node(node, button)
    return type(node) == "table" and node.config and node.config.button == button
end

local function insert_options_menu_button(t)
    local contents = options_contents_nodes(t)
    if type(contents) ~= "table" then return false end

    for _, node in ipairs(contents) do
        if is_button_node(node, "runarchive_open") then return true end
    end

    for i, node in ipairs(contents) do
        if is_button_node(node, "high_scores") then
            table.insert(contents, i + 1, create_options_archive_button())
            return true
        end
    end

    contents[#contents + 1] = create_options_archive_button()
    return true
end

local original_create_UIBox_options = create_UIBox_options
function create_UIBox_options()
    local t = original_create_UIBox_options()
    insert_options_menu_button(t)
    return t
end

local original_game_start_run = Game and Game.start_run
if original_game_start_run then
    function Game:start_run(args)
        local result = original_game_start_run(self, args)
        if G and G.GAME then
            if args and args.savetext and type(G.GAME[CURRENT_KEY]) == "table" then
                RunArchive.current = G.GAME[CURRENT_KEY]
                upsert_run(RunArchive.current, true)
            elseif not args or not args.savetext then
                create_new_run_record()
            elseif not G.GAME[CURRENT_KEY] then
                create_new_run_record()
            end
        end
        return result
    end
end

local original_buy_from_shop = G.FUNCS.buy_from_shop
G.FUNCS.buy_from_shop = function(e)
    local card = e and e.config and e.config.ref_table or nil
    local id = e and e.config and e.config.id or nil
    local result = original_buy_from_shop(e)
    if result ~= false and card then
        append_event(id == "buy_and_use" and "buy" or "buy", card, id)
    end
    return result
end

local original_sell_card = G.FUNCS.sell_card
G.FUNCS.sell_card = function(e)
    local card = e and e.config and e.config.ref_table or nil
    if card then append_event("sell", card) end
    return original_sell_card(e)
end

local original_use_card = G.FUNCS.use_card
G.FUNCS.use_card = function(e, mute, nosave)
    local card = e and e.config and e.config.ref_table or nil
    if card and card.ability then
        if card.ability.set == "Voucher" then
            append_event("redeem", card)
        elseif card.ability.consumeable or card.ability.set == "Booster" then
            append_event("use", card)
        end
    end
    return original_use_card(e, mute, nosave)
end

local original_check_and_set_high_score = check_and_set_high_score
function check_and_set_high_score(score, amt)
    if score == "hand" then
        local current = current_run_record()
        if current then
            current.best_hand_score = math.max(tonumber(current.best_hand_score) or 0, tonumber(amt) or 0)
            current.updated_at = now_text()
        end
    end
    return original_check_and_set_high_score(score, amt)
end

local original_create_UIBox_win = create_UIBox_win
function create_UIBox_win(...)
    finalize_run("win")
    return original_create_UIBox_win(...)
end

local original_update_game_over = Game and Game.update_game_over
if original_update_game_over then
    function Game:update_game_over(dt)
        if G and G.GAME and not G.STATE_COMPLETE then
            local result = (G.GAME.round_resets and G.GAME.win_ante and G.GAME.round_resets.ante > G.GAME.win_ante) and "endless_loss" or "loss"
            finalize_run(result)
        end
        return original_update_game_over(self, dt)
    end
end
