local ScorePreview = rawget(_G, "BalatroScorePreview") or {}
_G.BalatroScorePreview = ScorePreview

local current_mod = SMODS and SMODS.current_mod or nil

local function mod_config()
    return current_mod and type(current_mod.config) == "table" and current_mod.config or nil
end

-- Expected-value preview is opt-in (mod config key `score_preview_ev`). When off, the
-- preview stays a pure deterministic floor. `score_preview_ev_samples` tunes accuracy.
local function show_ev()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_ev == true
end

local function ev_samples()
    local cfg = mod_config()
    local n = cfg and tonumber(cfg.score_preview_ev_samples) or nil
    if n and n >= 1 then return math.min(math.floor(n), 500) end
    return 20
end

-- Shop joker-swap impact (raw Δ% of the last hand played). Opt-in.
local function show_swap()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_swap == true
end

-- Post-hand per-joker breakdown (leave-one-out Δ% of the hand just played). Opt-in.
local function show_breakdown()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_breakdown == true
end

-- Use Shapley values (fair partition that sums to the joker-driven score) instead of
-- leave-one-out. Only meaningful when the breakdown is on.
local function show_shapley()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_shapley == true
end

-- Include the played hand's most recent level as an extra breakdown "player" (Δ of
-- level L vs L-1). Opt-in; only meaningful with the breakdown on.
local function show_planet()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_breakdown_planet == true
end

-- Post-hand card-modifier breakdown (leave-one-out Δ% of the played cards' editions and
-- seals, grouped by type). Opt-in and independent of the joker breakdown.
local function show_card_breakdown()
    local cfg = mod_config()
    return cfg ~= nil and cfg.score_preview_card_breakdown == true
end

-- Restore-discards button: return every card in the discard pile to the draw pile.
-- Balance-affecting convenience, off by default.
local function show_restore()
    local cfg = mod_config()
    return cfg ~= nil and cfg.restore_discards == true
end

local function language_key()
    local lang = G and G.SETTINGS and (G.SETTINGS.real_language or G.SETTINGS.language) or nil
    return type(lang) == "string" and lang:lower() or ""
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
    local lang = language_key()
    if lang:sub(1, 2) ~= "zh" then return "en" end
    return is_traditional_chinese() and "zh_tw" or "zh_cn"
end

local function preview_prefix()
    local lang = language_group()
    if lang == "zh_cn" then return "参考值：" end
    if lang == "zh_tw" then return "參考值：" end
    return "Reference: "
end

local function preview_idle_text()
    return preview_prefix() .. "-"
end

local function preview_unknown_text()
    local lang = language_group()
    if lang == "zh_cn" or lang == "zh_tw" then return preview_prefix() .. "？？？" end
    return preview_prefix() .. "???"
end

local function preview_enough_text()
    local lang = language_group()
    if lang == "zh_cn" then return "  达标" end
    if lang == "zh_tw" then return "  達標" end
    return "  Enough"
end

ScorePreview.ui = ScorePreview.ui or {
    line = preview_idle_text(),
    exchange = "",
    target_reached = false
}
ScorePreview.ui.line = ScorePreview.ui.line or preview_idle_text()
ScorePreview.ui.exchange = ScorePreview.ui.exchange or ""
ScorePreview.ui.breakdown = ScorePreview.ui.breakdown or ""
ScorePreview.ui.nextlevel = ScorePreview.ui.nextlevel or ""
ScorePreview.ui.cardbreakdown = ScorePreview.ui.cardbreakdown or ""
ScorePreview.ui.target_reached = ScorePreview.ui.target_reached or false
ScorePreview.cache = ScorePreview.cache or { signature = nil, result = nil }

local function fmt_number(value)
    value = tonumber(value) or 0
    if type(number_format) == "function" then
        local ok, formatted = pcall(number_format, value)
        if ok and formatted then return formatted end
    end
    return tostring(math.floor(value + 0.0000001))
end

-- "1 Mult ≈ N Chips": how many chips one point of Mult is worth at the current score.
-- Since Score = Chips × Mult, a mult point is worth Chips / Mult chip points.
local function fmt_ratio(per)
    if per >= 10 then return fmt_number(math.floor(per + 0.5)) end
    return tostring(math.floor(per * 10 + 0.5) / 10)
end

local function exchange_rate_text(chips, mult)
    chips = tonumber(chips)
    mult = tonumber(mult)
    if not chips or not mult or chips <= 0 or mult <= 0 then return "" end
    local lang = language_group()
    -- Quote the rate in whichever direction reads >= 1, so an extreme build (a big
    -- xMult stack) shows "1 Chip ~ 44 Mult" instead of collapsing to "1 Mult ~ 0 Chips".
    if chips >= mult then
        local n = fmt_ratio(chips / mult)
        if lang == "zh_cn" then return "1 倍率 ~ " .. n .. " 筹码" end
        if lang == "zh_tw" then return "1 倍率 ~ " .. n .. " 籌碼" end
        return "1 Mult ~ " .. n .. " Chips"
    else
        local n = fmt_ratio(mult / chips)
        if lang == "zh_cn" then return "1 筹码 ~ " .. n .. " 倍率" end
        if lang == "zh_tw" then return "1 籌碼 ~ " .. n .. " 倍率" end
        return "1 Chip ~ " .. n .. " Mult"
    end
end

local function safe_number(value, fallback)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        return fallback or 0
    end
    return value
end

local function deep_copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copied = {}
    seen[value] = copied
    for k, v in pairs(value) do
        copied[deep_copy(k, seen)] = deep_copy(v, seen)
    end
    return copied
end

local function restore_table(target, snapshot)
    if type(target) ~= "table" or type(snapshot) ~= "table" then return end
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(snapshot) do target[k] = deep_copy(v) end
end

local function shallow_copy_array(source)
    local copy = {}
    for i, v in ipairs(source or {}) do copy[i] = v end
    return copy
end

local SNAPSHOT_AREAS = {
    "hand",
    "play",
    "deck",
    "discard",
    "jokers",
    "consumeables",
    "vouchers",
    "pack_cards"
}

local function capture_area_states()
    local states = {}
    for _, name in ipairs(SNAPSHOT_AREAS) do
        local area = G and G[name]
        if area and area.cards then
            states[name] = {
                cards = shallow_copy_array(area.cards),
                highlighted = shallow_copy_array(area.highlighted or {}),
                card_limit = area.config and area.config.card_limit or nil
            }
        end
    end
    return states
end

local function restore_area_states(states)
    for name, state in pairs(states or {}) do
        local area = G and G[name]
        if area and state then
            if area.cards then
                area.cards = shallow_copy_array(state.cards)
                for _, card in ipairs(area.cards) do
                    card.area = area
                    card.parent = area
                end
            end
            if area.highlighted then area.highlighted = shallow_copy_array(state.highlighted) end
            if area.config and state.card_limit ~= nil then area.config.card_limit = state.card_limit end
            if type(area.set_ranks) == "function" then pcall(function() area:set_ranks() end) end
            if type(area.align_cards) == "function" then pcall(function() area:align_cards() end) end
        end
    end
end

local function has_card(cards, card)
    for _, scoring_card in ipairs(cards or {}) do
        if scoring_card == card then return true end
    end
    return false
end

local function sorted_selected_cards()
    local cards = shallow_copy_array(G.hand and G.hand.highlighted or {})
    table.sort(cards, function(a, b)
        local ax = a and a.T and a.T.x or 0
        local bx = b and b.T and b.T.x or 0
        return ax < bx
    end)
    return cards
end

local function card_is_hidden(card)
    if not card then return false end
    if card.facing == "back" then return true end
    if card.ability and card.ability.wheel_flipped == true then return true end
    return false
end

local function selected_has_hidden_cards(selected)
    for _, card in ipairs(selected or {}) do
        if card_is_hidden(card) then return true end
    end

    return false
end

local function selection_signature()
    if not G or not G.GAME or not G.hand or not G.hand.highlighted then return "none" end

    local parts = {
        tostring(G.STATE),
        tostring(G.GAME.round or ""),
        tostring(G.GAME.chips or ""),
        tostring(G.GAME.current_round and G.GAME.current_round.hands_left or ""),
        tostring(G.GAME.current_round and G.GAME.current_round.discards_left or ""),
        tostring(G.GAME.blind and G.GAME.blind.name or ""),
        tostring(G.GAME.blind and G.GAME.blind.chips or "")
    }

    for _, card in ipairs(sorted_selected_cards()) do
        parts[#parts + 1] = tostring(card.unique_val or card.sort_id or card.ID or card.base and card.base.id or "")
        parts[#parts + 1] = tostring(card.config and card.config.center_key or "")
        parts[#parts + 1] = tostring(card.seal or "")
        parts[#parts + 1] = tostring(card.edition and (card.edition.key or card.edition.type) or "")
        parts[#parts + 1] = tostring(card.facing or "")
        parts[#parts + 1] = tostring(card.ability and card.ability.wheel_flipped or "")
    end

    local function append_area(area, label)
        if not area or not area.cards then return end
        parts[#parts + 1] = label
        for i, card in ipairs(area.cards) do
            parts[#parts + 1] = tostring(i)
            parts[#parts + 1] = tostring(card.unique_val or "")
            parts[#parts + 1] = tostring(card.config and card.config.center_key or "")
            parts[#parts + 1] = tostring(card.ability and card.ability.mult or "")
            parts[#parts + 1] = tostring(card.ability and card.ability.x_mult or "")
            parts[#parts + 1] = tostring(card.ability and card.ability.extra or "")
        end
    end

    append_area(G.jokers, "jokers")
    append_area(G.consumeables, "consumeables")
    append_area(G.vouchers, "vouchers")

    if G.GAME.pseudorandom then
        local keys = {}
        for key in pairs(G.GAME.pseudorandom) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = tostring(key)
            parts[#parts + 1] = tostring(G.GAME.pseudorandom[key])
        end
    end

    return table.concat(parts, "|")
end

local function collect_cards()
    local cards, seen = {}, {}
    local function add(card)
        if card and not seen[card] then
            seen[card] = true
            cards[#cards + 1] = card
        end
    end
    local function add_area(area)
        if area and area.cards then
            for _, card in ipairs(area.cards) do add(card) end
        end
    end

    for _, card in ipairs(G.playing_cards or {}) do add(card) end
    add_area(G.hand)
    add_area(G.play)
    add_area(G.deck)
    add_area(G.discard)
    add_area(G.jokers)
    add_area(G.consumeables)
    add_area(G.vouchers)
    add_area(G.pack_cards)

    return cards
end

local enhancement_center_by_effect = {
    ["Bonus Card"] = "m_bonus",
    ["Mult Card"] = "m_mult",
    ["Wild Card"] = "m_wild",
    ["Glass Card"] = "m_glass",
    ["Steel Card"] = "m_steel",
    ["Stone Card"] = "m_stone",
    ["Gold Card"] = "m_gold",
    ["Lucky Card"] = "m_lucky"
}

local function get_center_key(card)
    if not card or not card.config then return nil end
    if card.config.center_key then return card.config.center_key end
    local center = card.config.center
    if type(center) == "string" then return center end
    if type(center) == "table" then return center.key end
    return nil
end

local function repair_card_center(card)
    if not card or not card.ability or card.ability.set ~= "Enhanced" then return false end
    if get_center_key(card) ~= "c_base" then return false end

    local center_key = enhancement_center_by_effect[card.ability.effect]
        or enhancement_center_by_effect[card.ability.name]
    local center = center_key and G.P_CENTERS and G.P_CENTERS[center_key]
    if not center then return false end

    card.config = card.config or {}
    card.config.center_key = center_key
    card.config.center = center
    card.label = center.label or card.label
    return true
end

local function repair_known_enhancement_centers()
    local repaired = false
    if not G or not G.P_CENTERS then return repaired end
    for _, card in ipairs(collect_cards()) do
        repaired = repair_card_center(card) or repaired
    end
    return repaired
end

local function capture_state()
    local snapshot = {
        state = G.STATE,
        state_complete = G.STATE_COMPLETE,
        area_states = capture_area_states(),
        play_cards = shallow_copy_array(G.play and G.play.cards or {}),
        hand_cards = shallow_copy_array(G.hand and G.hand.cards or {}),
        play_highlighted = shallow_copy_array(G.play and G.play.highlighted or {}),
        hand_highlighted = shallow_copy_array(G.hand and G.hand.highlighted or {}),
        game = {
            chips = G.GAME.chips,
            dollars = G.GAME.dollars,
            dollar_buffer = G.GAME.dollar_buffer,
            consumeable_buffer = G.GAME.consumeable_buffer,
            last_hand_played = G.GAME.last_hand_played,
            saved_text = G.GAME.saved_text,
            hands_played = G.GAME.hands_played,
            playing_card = G.playing_card,
            playing_cards = shallow_copy_array(G.playing_cards or {}),
            probabilities = deep_copy(G.GAME.probabilities),
            pseudorandom = deep_copy(G.GAME.pseudorandom),
            current_round = G.GAME.current_round and {
                hands_left = G.GAME.current_round.hands_left,
                hands_played = G.GAME.current_round.hands_played,
                discards_left = G.GAME.current_round.discards_left,
                discards_used = G.GAME.current_round.discards_used,
                current_hand = deep_copy(G.GAME.current_round.current_hand or {})
            } or nil,
            hands = deep_copy(G.GAME.hands or {}),
            hand_usage = deep_copy(G.GAME.hand_usage or {}),
            cards_played = deep_copy(G.GAME.cards_played or {}),
            round_scores = deep_copy(G.GAME.round_scores or {})
        },
        blind = G.GAME.blind and {
            triggered = G.GAME.blind.triggered,
            disabled = G.GAME.blind.disabled,
            chips = G.GAME.blind.chips,
            chip_text = G.GAME.blind.chip_text,
            debuff = deep_copy(G.GAME.blind.debuff),
            hands = deep_copy(G.GAME.blind.hands),
            only_hand = G.GAME.blind.only_hand,
            prepped = G.GAME.blind.prepped,
            discards_sub = G.GAME.blind.discards_sub,
            hands_sub = G.GAME.blind.hands_sub,
            block_play = G.GAME.blind.block_play,
            effect = G.GAME.blind.effect
        } or nil,
        smods = SMODS and {
            no_resolve = SMODS.no_resolve,
            displayed_hand = SMODS.displayed_hand,
            displaying_scoring = SMODS.displaying_scoring,
            last_hand = SMODS.last_hand,
            last_hand_oneshot = SMODS.last_hand_oneshot,
            saved = SMODS.saved,
            post_prob = deep_copy(SMODS.post_prob),
            scoring_parameters = {},
            calculation_controls = deep_copy(SMODS.Calculation_Controls or {})
        } or nil,
        globals = {
            mult = rawget(_G, "mult"),
            hand_chips = rawget(_G, "hand_chips"),
            percent = rawget(_G, "percent"),
            percent_delta = rawget(_G, "percent_delta")
        },
        card_states = {}
    }

    if SMODS and SMODS.Scoring_Parameters then
        for name, parameter in pairs(SMODS.Scoring_Parameters) do
            snapshot.smods.scoring_parameters[name] = {
                current = parameter.current
            }
        end
    end

    for _, card in ipairs(collect_cards()) do
        snapshot.card_states[#snapshot.card_states + 1] = {
            card = card,
            area = card.area,
            parent = card.parent,
            config_center_key = card.config and card.config.center_key or nil,
            config_center = card.config and card.config.center or nil,
            config_card_key = card.config and card.config.card_key or nil,
            config_card = card.config and card.config.card or nil,
            ability = deep_copy(card.ability),
            base = deep_copy(card.base),
            label = card.label,
            base_cost = card.base_cost,
            extra_cost = card.extra_cost,
            cost = card.cost,
            sell_cost = card.sell_cost,
            added_to_deck = card.added_to_deck,
            debuff = card.debuff,
            debuffed_by_blind = card.debuffed_by_blind,
            destroyed = card.destroyed,
            shattered = card.shattered,
            getting_sliced = card.getting_sliced,
            vampired = card.vampired,
            sixth_sense = card.sixth_sense,
            removed = card.removed,
            dissolve = card.dissolve,
            dissolve_colours = deep_copy(card.dissolve_colours),
            skip_destroy_animation = card.skip_destroy_animation,
            front_hidden = card.front_hidden,
            lucky_trigger = card.lucky_trigger,
            repetition_trigger = card.repetition_trigger,
            highlighted = card.highlighted,
            facing = card.facing,
            sprite_facing = card.sprite_facing,
            flipping = card.flipping,
            pinch = deep_copy(card.pinch)
        }
    end

    return snapshot
end

local function restore_state(snapshot)
    if not snapshot then return end

    G.STATE = snapshot.state
    G.STATE_COMPLETE = snapshot.state_complete

    if G.play then
        G.play.cards = shallow_copy_array(snapshot.play_cards)
        G.play.highlighted = shallow_copy_array(snapshot.play_highlighted)
    end
    if G.hand then
        G.hand.cards = shallow_copy_array(snapshot.hand_cards)
        G.hand.highlighted = shallow_copy_array(snapshot.hand_highlighted)
    end

    for _, state in ipairs(snapshot.card_states or {}) do
        local card = state.card
        if card then
            card.config = card.config or {}
            card.config.center_key = state.config_center_key
            card.config.center = (state.config_center_key and G.P_CENTERS and G.P_CENTERS[state.config_center_key])
                or state.config_center
            card.config.card_key = state.config_card_key
            card.config.card = (state.config_card_key and G.P_CARDS and G.P_CARDS[state.config_card_key])
                or state.config_card
            card.area = state.area
            card.parent = state.parent
            card.ability = deep_copy(state.ability)
            card.base = deep_copy(state.base)
            card.label = state.label
            card.base_cost = state.base_cost
            card.extra_cost = state.extra_cost
            card.cost = state.cost
            card.sell_cost = state.sell_cost
            card.added_to_deck = state.added_to_deck
            card.debuff = state.debuff
            card.debuffed_by_blind = state.debuffed_by_blind
            card.destroyed = state.destroyed
            card.shattered = state.shattered
            card.getting_sliced = state.getting_sliced
            card.vampired = state.vampired
            card.sixth_sense = state.sixth_sense
            card.removed = state.removed
            card.dissolve = state.dissolve
            card.dissolve_colours = deep_copy(state.dissolve_colours)
            card.skip_destroy_animation = state.skip_destroy_animation
            card.front_hidden = state.front_hidden
            card.lucky_trigger = state.lucky_trigger
            card.repetition_trigger = state.repetition_trigger
            card.highlighted = state.highlighted
            card.facing = state.facing
            card.sprite_facing = state.sprite_facing
            card.flipping = state.flipping
            card.pinch = deep_copy(state.pinch)
        end
    end
    restore_area_states(snapshot.area_states)

    if G.GAME then
        G.GAME.chips = snapshot.game.chips
        G.GAME.dollars = snapshot.game.dollars
        G.GAME.dollar_buffer = snapshot.game.dollar_buffer
        G.GAME.consumeable_buffer = snapshot.game.consumeable_buffer
        G.GAME.last_hand_played = snapshot.game.last_hand_played
        G.GAME.saved_text = snapshot.game.saved_text
        G.GAME.hands_played = snapshot.game.hands_played
        G.playing_card = snapshot.game.playing_card
        G.playing_cards = shallow_copy_array(snapshot.game.playing_cards)
        G.GAME.probabilities = deep_copy(snapshot.game.probabilities)
        G.GAME.pseudorandom = deep_copy(snapshot.game.pseudorandom)
        if G.GAME.current_round and snapshot.game.current_round then
            G.GAME.current_round.hands_left = snapshot.game.current_round.hands_left
            G.GAME.current_round.hands_played = snapshot.game.current_round.hands_played
            G.GAME.current_round.discards_left = snapshot.game.current_round.discards_left
            G.GAME.current_round.discards_used = snapshot.game.current_round.discards_used
            if G.GAME.current_round.current_hand then
                restore_table(G.GAME.current_round.current_hand, snapshot.game.current_round.current_hand)
            end
        end
        if G.GAME.hands then restore_table(G.GAME.hands, snapshot.game.hands) end
        if G.GAME.hand_usage then restore_table(G.GAME.hand_usage, snapshot.game.hand_usage) end
        if G.GAME.cards_played then restore_table(G.GAME.cards_played, snapshot.game.cards_played) end
        if G.GAME.round_scores then restore_table(G.GAME.round_scores, snapshot.game.round_scores) end
    end

    if G.GAME and G.GAME.blind and snapshot.blind then
        G.GAME.blind.triggered = snapshot.blind.triggered
        G.GAME.blind.disabled = snapshot.blind.disabled
        G.GAME.blind.chips = snapshot.blind.chips
        G.GAME.blind.chip_text = snapshot.blind.chip_text
        G.GAME.blind.debuff = deep_copy(snapshot.blind.debuff)
        G.GAME.blind.hands = deep_copy(snapshot.blind.hands)
        G.GAME.blind.only_hand = snapshot.blind.only_hand
        G.GAME.blind.prepped = snapshot.blind.prepped
        G.GAME.blind.discards_sub = snapshot.blind.discards_sub
        G.GAME.blind.hands_sub = snapshot.blind.hands_sub
        G.GAME.blind.block_play = snapshot.blind.block_play
        G.GAME.blind.effect = snapshot.blind.effect
    end

    if SMODS and snapshot.smods then
        SMODS.no_resolve = snapshot.smods.no_resolve
        SMODS.displayed_hand = snapshot.smods.displayed_hand
        SMODS.displaying_scoring = snapshot.smods.displaying_scoring
        SMODS.last_hand = snapshot.smods.last_hand
        SMODS.last_hand_oneshot = snapshot.smods.last_hand_oneshot
        SMODS.saved = snapshot.smods.saved
        SMODS.post_prob = deep_copy(snapshot.smods.post_prob)
        if SMODS.Calculation_Controls then restore_table(SMODS.Calculation_Controls, snapshot.smods.calculation_controls) end
        if SMODS.Scoring_Parameters then
            for name, state in pairs(snapshot.smods.scoring_parameters or {}) do
                if SMODS.Scoring_Parameters[name] then
                    SMODS.Scoring_Parameters[name].current = state.current
                end
            end
        end
    end

    mult = snapshot.globals.mult
    hand_chips = snapshot.globals.hand_chips
    percent = snapshot.globals.percent
    percent_delta = snapshot.globals.percent_delta
end

-- Set by the floor-pass probability stub when a probabilistic gate is consulted,
-- so EV sampling only runs for hands that actually contain randomness.
local ev_probe = { seen = false }

local function with_sandbox(fn, allow_prob)
    local refs = {
        delay = delay,
        update_hand_text = update_hand_text,
        play_sound = play_sound,
        card_eval_status_text = card_eval_status_text,
        attention_text = attention_text,
        highlight_card = highlight_card,
        juice_card = juice_card,
        ease_dollars = ease_dollars,
        ease_colour = ease_colour,
        inc_career_stat = inc_career_stat,
        check_for_unlock = check_for_unlock,
        check_and_set_high_score = check_and_set_high_score,
        play_area_status_text = play_area_status_text,
        save_settings = G and G.save_settings or nil,
        add_event = G.E_MANAGER and G.E_MANAGER.add_event or nil,
        no_resolve = SMODS and SMODS.no_resolve or nil,
        pseudorandom_probability = SMODS and SMODS.pseudorandom_probability or nil
    }

    delay = function() end
    update_hand_text = function() end
    play_sound = function() end
    card_eval_status_text = function() end
    attention_text = function() end
    highlight_card = function() end
    juice_card = function() end
    ease_dollars = function(mod)
        if G and G.GAME then
            G.GAME.dollars = (G.GAME.dollars or 0) + (tonumber(mod) or 0)
        end
    end
    ease_colour = function() end
    inc_career_stat = function() end
    check_for_unlock = function() end
    check_and_set_high_score = function() end
    play_area_status_text = function() end
    if G then G.save_settings = function() end end
    if G.E_MANAGER then
        G.E_MANAGER.add_event = function() return nil end
    end
    if SMODS then
        SMODS.no_resolve = true
        -- allow_prob:
        --   falsy   -> force all gates false (the floor); also records ev_probe.seen
        --   "max"   -> force all gates true (the ceiling, used to test score impact)
        --   true    -> leave the real probability function in place (EV sampling)
        if allow_prob == "max" then
            SMODS.pseudorandom_probability = function()
                return true
            end
        elseif not allow_prob then
            SMODS.pseudorandom_probability = function()
                ev_probe.seen = true
                return false
            end
        end
    end

    local ok, result = pcall(fn)

    delay = refs.delay
    update_hand_text = refs.update_hand_text
    play_sound = refs.play_sound
    card_eval_status_text = refs.card_eval_status_text
    attention_text = refs.attention_text
    highlight_card = refs.highlight_card
    juice_card = refs.juice_card
    ease_dollars = refs.ease_dollars
    ease_colour = refs.ease_colour
    inc_career_stat = refs.inc_career_stat
    check_for_unlock = refs.check_for_unlock
    check_and_set_high_score = refs.check_and_set_high_score
    play_area_status_text = refs.play_area_status_text
    if G then G.save_settings = refs.save_settings end
    if G.E_MANAGER then G.E_MANAGER.add_event = refs.add_event end
    if SMODS then
        SMODS.no_resolve = refs.no_resolve
        SMODS.pseudorandom_probability = refs.pseudorandom_probability
    end

    return ok, result
end

local function prepare_virtual_play(selected)
    local selected_lookup = {}
    for _, card in ipairs(selected) do selected_lookup[card] = true end

    local remaining = {}
    for _, card in ipairs(G.hand.cards or {}) do
        if not selected_lookup[card] then
            remaining[#remaining + 1] = card
            card.area = G.hand
        end
    end

    G.play.cards = shallow_copy_array(selected)
    G.play.highlighted = {}
    G.hand.cards = remaining
    G.hand.highlighted = shallow_copy_array(selected)

    for _, card in ipairs(selected) do
        card.area = G.play
    end

    G.STATE = G.STATES.HAND_PLAYED
end

local function simulate_play_start_state(selected)
    if G.GAME and G.GAME.current_round then
        G.GAME.current_round.hands_left = (G.GAME.current_round.hands_left or 0) - 1
    end

    if G.GAME and G.GAME.round_scores and G.GAME.round_scores.cards_played then
        G.GAME.round_scores.cards_played.amt = (G.GAME.round_scores.cards_played.amt or 0) + #(selected or {})
    end

    for _, card in ipairs(selected or {}) do
        if card.base then card.base.times_played = (card.base.times_played or 0) + 1 end
    end
end

local function simulate_safe_press_play_effects()
    local blind = G.GAME and G.GAME.blind
    if not blind or blind.disabled then return end

    if blind.name == "The Hook" then
        -- The real effect randomly discards hand cards. Preview keeps random
        -- side effects out of the live hand and only marks the blind triggered
        -- inside the sandbox.
        blind.triggered = true
        return
    end

    if blind.name == "Crimson Heart" then
        if G.jokers and G.jokers.cards and G.jokers.cards[1] then
            blind.triggered = true
            blind.prepped = true
        end
        return
    end

    if blind.name == "The Fish" then
        blind.prepped = true
        return
    end

    if blind.name == "The Tooth" then
        local played = G.play and G.play.cards and #G.play.cards or 0
        G.GAME.dollars = (G.GAME.dollars or 0) - played
        blind.triggered = true
        return
    end
end

local function final_scoring_hand_from(cards, scoring_hand)
    local final_scoring_hand = {}
    for i = 1, #cards do
        local card = cards[i]
        local splashed = SMODS.always_scores(card) or next(find_joker("Splash"))
        local unsplashed = SMODS.never_scores(card)

        if not splashed then
            for _, scoring_card in pairs(scoring_hand) do
                if scoring_card == card then splashed = true end
            end
        end

        local effects = {}
        SMODS.calculate_context({
            modify_scoring_hand = true,
            other_card = card,
            full_hand = cards,
            scoring_hand = scoring_hand,
            in_scoring = true,
            ignore_other_debuff = true
        }, effects)
        local flags = SMODS.trigger_effects(effects, card)
        if flags.add_to_hand then splashed = true end
        if flags.remove_from_hand then unsplashed = true end
        if splashed and not unsplashed then table.insert(final_scoring_hand, card) end
    end
    return final_scoring_hand
end

local function calculate_joker_steps(text, poker_hands, scoring_hand)
    for _, area in ipairs(SMODS.get_card_areas("jokers")) do
        for _, _card in ipairs(area.cards) do
            local effects = {}
            local eval = eval_card(_card, {
                cardarea = G.jokers,
                full_hand = G.play.cards,
                scoring_hand = scoring_hand,
                scoring_name = text,
                poker_hands = poker_hands,
                edition = true,
                pre_joker = true
            })
            if eval.edition then effects[#effects + 1] = eval end

            local joker_eval, post = eval_card(_card, {
                cardarea = G.jokers,
                full_hand = G.play.cards,
                scoring_hand = scoring_hand,
                scoring_name = text,
                poker_hands = poker_hands,
                joker_main = true
            })
            if next(joker_eval) then
                if joker_eval.edition then joker_eval.edition = {} end
                table.insert(effects, joker_eval)
                for _, v in ipairs(post or {}) do effects[#effects + 1] = v end
                if joker_eval.retriggers then
                    for rt = 1, #joker_eval.retriggers do
                        local rt_eval, rt_post = eval_card(_card, {
                            cardarea = G.jokers,
                            full_hand = G.play.cards,
                            scoring_hand = scoring_hand,
                            scoring_name = text,
                            poker_hands = poker_hands,
                            joker_main = true,
                            retrigger_joker = true
                        })
                        if next(rt_eval) then
                            table.insert(effects, { retriggers = joker_eval.retriggers[rt] })
                            table.insert(effects, rt_eval)
                            for _, v in ipairs(rt_post or {}) do effects[#effects + 1] = v end
                        end
                    end
                end
            end

            for _, _area in ipairs(SMODS.get_card_areas("jokers")) do
                for _, _joker in ipairs(_area.cards) do
                    local other_key = "other_unknown"
                    if _card.ability.set == "Joker" then other_key = "other_joker" end
                    if _card.ability.consumeable then other_key = "other_consumeable" end
                    if _card.ability.set == "Voucher" then other_key = "other_voucher" end
                    local other_eval, other_post = eval_card(_joker, {
                        full_hand = G.play.cards,
                        scoring_hand = scoring_hand,
                        scoring_name = text,
                        poker_hands = poker_hands,
                        [other_key] = _card,
                        other_main = _card
                    })
                    if next(other_eval) then
                        if other_eval.edition then other_eval.edition = {} end
                        other_eval.jokers.juice_card = _joker
                        table.insert(effects, other_eval)
                        for _, v in ipairs(other_post or {}) do effects[#effects + 1] = v end
                        if other_eval.retriggers then
                            for rt = 1, #other_eval.retriggers do
                                local rt_eval, rt_post = eval_card(_joker, {
                                    full_hand = G.play.cards,
                                    scoring_hand = scoring_hand,
                                    scoring_name = text,
                                    poker_hands = poker_hands,
                                    [other_key] = _card,
                                    retrigger_joker = true
                                })
                                if next(rt_eval) then
                                    table.insert(effects, { retriggers = other_eval.retriggers[rt] })
                                    table.insert(effects, rt_eval)
                                    for _, v in ipairs(rt_post or {}) do effects[#effects + 1] = v end
                                end
                            end
                        end
                    end
                end
            end

            for _, _area in ipairs(SMODS.get_card_areas("individual")) do
                local other_key = "other_unknown"
                if _card.ability.set == "Joker" then other_key = "other_joker" end
                if _card.ability.consumeable then other_key = "other_consumeable" end
                if _card.ability.set == "Voucher" then other_key = "other_voucher" end
                local _eval, post = SMODS.eval_individual(_area, {
                    full_hand = G.play.cards,
                    scoring_hand = scoring_hand,
                    scoring_name = text,
                    poker_hands = poker_hands,
                    [other_key] = _card,
                    other_main = _card
                })
                if next(_eval) then
                    _eval.individual.juice_card = _area.scored_card
                    table.insert(effects, _eval)
                    for _, v in ipairs(post or {}) do effects[#effects + 1] = v end
                    if _eval.retriggers then
                        for rt = 1, #_eval.retriggers do
                            local rt_eval, rt_post = SMODS.eval_individual(_area, {
                                full_hand = G.play.cards,
                                scoring_hand = scoring_hand,
                                scoring_name = text,
                                poker_hands = poker_hands,
                                [other_key] = _card,
                                retrigger_joker = true
                            })
                            if next(rt_eval) then
                                table.insert(effects, { _eval.retriggers[rt] })
                                table.insert(effects, rt_eval)
                                for _, v in ipairs(rt_post or {}) do effects[#effects + 1] = v end
                            end
                        end
                    end
                end
            end

            local post_eval = eval_card(_card, {
                cardarea = G.jokers,
                full_hand = G.play.cards,
                scoring_hand = scoring_hand,
                scoring_name = text,
                poker_hands = poker_hands,
                edition = true,
                post_joker = true
            })
            if post_eval.edition then effects[#effects + 1] = post_eval end

            SMODS.trigger_effects(effects, _card)
        end
    end
end

local function calculate_individual_main(text, poker_hands, scoring_hand)
    for _, _area in ipairs(SMODS.get_card_areas("individual")) do
        local effects = {}
        local _eval, post = SMODS.eval_individual(_area, {
            full_hand = G.play.cards,
            scoring_hand = scoring_hand,
            scoring_name = text,
            poker_hands = poker_hands,
            main_scoring = true
        })
        if next(_eval) then
            table.insert(effects, _eval)
            _eval.individual.juice_card = _area.scored_card
            for _, v in ipairs(post or {}) do effects[#effects + 1] = v end
            if _eval.retriggers then
                for rt = 1, #_eval.retriggers do
                    local rt_eval, rt_post = SMODS.eval_individual(_area, {
                        full_hand = G.play.cards,
                        scoring_hand = scoring_hand,
                        scoring_name = text,
                        poker_hands = poker_hands,
                        main_scoring = true,
                        retrigger_joker = true
                    })
                    if next(rt_eval) then
                        table.insert(effects, { _eval.retriggers[rt] })
                        table.insert(effects, rt_eval)
                        for _, v in ipairs(rt_post or {}) do effects[#effects + 1] = v end
                    end
                end
            end
        end

        SMODS.trigger_effects(effects, _area.scored_card)
    end
end

local function run_true_scoring(selected)
    prepare_virtual_play(selected)
    simulate_play_start_state(selected)
    simulate_safe_press_play_effects()

    for _, parameter in pairs(SMODS.Scoring_Parameters or {}) do
        parameter.current = parameter.default_value
    end
    hand_chips = 0
    mult = 0

    local start_score = safe_number(G.GAME.chips, 0)
    local text, disp_text, poker_hands, scoring_hand = G.FUNCS.get_poker_hand_info(G.play.cards)
    if not text or text == "NULL" or not G.GAME.hands[text] then
        return nil
    end

    G.GAME.hands[text].played = G.GAME.hands[text].played + 1
    G.GAME.hands[text].played_this_round = G.GAME.hands[text].played_this_round + 1
    G.GAME.hands[text].played_this_ante = G.GAME.hands[text].played_this_ante + 1
    G.GAME.last_hand_played = text
    G.GAME.hands[text].visible = true

    scoring_hand = final_scoring_hand_from(G.play.cards, scoring_hand)

    percent = 0.3
    percent_delta = 0.08
    SMODS.displayed_hand = text
    SMODS.displaying_scoring = true

    if not G.GAME.blind:debuff_hand(G.play.cards, poker_hands, text) then
        mult = mod_mult(G.GAME.hands[text].mult)
        hand_chips = mod_chips(G.GAME.hands[text].chips)

        if SMODS.last_hand then
            for _, v in ipairs({ "scoring_hand", "full_hand" }) do
                for _, _c in ipairs(SMODS.last_hand[v] or {}) do
                    _c.ability["SMODS_" .. v] = nil
                end
            end
        end
        SMODS.last_hand = { scoring_hand = scoring_hand, scoring_name = text, full_hand = G.play.cards }
        SMODS.calculate_context({ full_hand = G.play.cards, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands, before = true })

        SMODS.displayed_hand = nil

        mult = mod_mult(G.GAME.hands[text].mult)
        hand_chips = mod_chips(G.GAME.hands[text].chips)

        local modified
        mult, hand_chips, modified = G.GAME.blind:modify_hand(G.play.cards, poker_hands, text, mult, hand_chips, scoring_hand)
        mult, hand_chips = mod_mult(mult), mod_chips(hand_chips)

        SMODS.calculate_context({ initial_scoring_step = true, full_hand = G.play.cards, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands })
        for _, area in ipairs(SMODS.get_card_areas("playing_cards")) do
            SMODS.calculate_main_scoring({
                cardarea = area,
                full_hand = G.play.cards,
                scoring_hand = scoring_hand,
                scoring_name = text,
                poker_hands = poker_hands
            }, area == G.play and scoring_hand or nil)
        end

        calculate_joker_steps(text, poker_hands, scoring_hand)
        calculate_individual_main(text, poker_hands, scoring_hand)

        SMODS.calculate_context({ full_hand = G.play.cards, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands, final_scoring_step = true })

        local nu_chip, nu_mult = G.GAME.selected_back:trigger_effect({
            context = "final_scoring_step",
            chips = hand_chips,
            mult = mult
        })
        mult = mod_mult(nu_mult or mult)
        hand_chips = mod_chips(nu_chip or hand_chips)

        local cards_destroyed = {}
        for _, area in ipairs(SMODS.get_card_areas("playing_cards", "destroying_cards")) do
            SMODS.calculate_destroying_cards({
                full_hand = G.play.cards,
                scoring_hand = scoring_hand,
                scoring_name = text,
                poker_hands = poker_hands,
                cardarea = area
            }, cards_destroyed, area == G.play and scoring_hand or nil)
        end

        if cards_destroyed[1] then
            SMODS.calculate_context({ scoring_hand = scoring_hand, remove_playing_cards = true, removed = cards_destroyed })
        end
    else
        mult = mod_mult(0)
        hand_chips = mod_chips(0)
        SMODS.displayed_hand = nil
        SMODS.calculate_context({ full_hand = G.play.cards, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands, debuffed_hand = true })
    end

    local round_score = math.floor(SMODS.calculate_round_score())
    local direct_score_delta = safe_number(G.GAME.chips, 0) - start_score
    local total = math.floor(round_score + direct_score_delta)

    return {
        mode = "exact",
        hand_key = text,
        hand_name = disp_text,
        hand_level = G.GAME.hands[text].level or 1,
        chips = SMODS.get_scoring_parameter("chips"),
        mult = SMODS.get_scoring_parameter("mult"),
        total = total,
        direct_score_delta = direct_score_delta
    }
end

local function calculate_basic(selected)
    local ok, hand_key, hand_name, poker_hands, scoring_hand = pcall(function()
        return G.FUNCS.get_poker_hand_info(selected)
    end)
    if not ok or not hand_key or hand_key == "NULL" or not G.GAME.hands[hand_key] then return nil end

    local final_scoring = {}
    for _, card in ipairs(selected) do
        local always_scores = SMODS and type(SMODS.always_scores) == "function" and SMODS.always_scores(card)
        local never_scores = SMODS and type(SMODS.never_scores) == "function" and SMODS.never_scores(card)
        if not never_scores and (has_card(scoring_hand, card) or always_scores) then
            final_scoring[#final_scoring + 1] = card
        end
    end

    local hand = G.GAME.hands[hand_key]
    local chips = safe_number(hand.chips, 0)
    local mult_value = safe_number(hand.mult, 0)
    for _, card in ipairs(final_scoring) do
        if card and not card.debuff then
            local chip_ok, chip_bonus = pcall(function() return card:get_chip_bonus() end)
            if chip_ok then chips = chips + safe_number(chip_bonus, 0) end
        end
    end

    return {
        mode = "basic",
        hand_key = hand_key,
        hand_name = hand_name,
        hand_level = hand.level or 1,
        chips = chips,
        mult = mult_value,
        total = math.floor(chips * mult_value)
    }
end

-- Give each EV sample a fresh RNG whose seed is decoupled from the live next draw, so
-- sampling reveals the distribution (an average) but never the actual upcoming roll.
local function reseed_for_sample(i)
    if not G or not G.GAME then return end
    local base = (G.GAME.pseudorandom and G.GAME.pseudorandom.seed) or ""
    G.GAME.pseudorandom = { seed = tostring(base) .. "|ev" .. tostring(i) }
end

-- Run the real scoring n+1 times from the same board: pass 0 is the deterministic floor
-- (probabilities off), passes 1..n roll for real from independent seeds. State is reset
-- before every pass and restored afterwards, so the live game is untouched.
local function sample_scoring(selected, snapshot, n)
    -- Deterministic floor pass. Its stub also records whether any probability gate
    -- was consulted (ev_probe.seen).
    restore_state(snapshot)
    ev_probe.seen = false
    local ok, floor = with_sandbox(function()
        return run_true_scoring(selected)
    end, false)
    if not (ok and floor and floor.total) then
        restore_state(snapshot)
        return nil, {}
    end

    -- No randomness in this hand -> no sampling. This is the common case and keeps
    -- ordinary selections at a single scoring pass (no UI lag).
    if not ev_probe.seen then
        restore_state(snapshot)
        return floor, {}
    end

    -- A gate fired, but does it change THIS hand's score? Compare the floor (all
    -- gates false) with a ceiling pass (all gates true). If equal, the randomness is
    -- score-irrelevant here -- e.g. a Glass card's break chance, which only destroys
    -- the card after scoring -- so sampling would just reproduce the floor N times.
    restore_state(snapshot)
    local cok, ceil = with_sandbox(function()
        return run_true_scoring(selected)
    end, "max")
    if cok and ceil and ceil.total == floor.total then
        restore_state(snapshot)
        return floor, {}
    end

    local totals = {}
    for i = 1, math.max(0, n) do
        restore_state(snapshot)
        reseed_for_sample(i)
        local sok, result = with_sandbox(function()
            return run_true_scoring(selected)
        end, true)
        if sok and result and result.total then
            totals[#totals + 1] = result.total
        end
    end
    restore_state(snapshot)
    return floor, totals
end

-- Attach expected value and blind-clear rate to the floor result, but only when the
-- samples actually differ from the floor (i.e. luck is in play).
local function summarize_ev(floor, totals)
    if not floor then return nil end
    if type(totals) ~= "table" or #totals == 0 then return floor end

    local sum, clears, varies = 0, 0, false
    local cur = safe_number(G.GAME.chips, 0)
    local target = safe_number(G.GAME.blind and G.GAME.blind.chips, 0)
    for _, t in ipairs(totals) do
        sum = sum + t
        if target > 0 and (cur + t) >= target then clears = clears + 1 end
        if t ~= floor.total then varies = true end
    end
    if varies then
        floor.ev = math.floor(sum / #totals + 0.5)
        floor.clear_rate = target > 0 and math.floor((100 * clears / #totals) + 0.5) or nil
        floor.random = true
    end
    return floor
end

local function calculate_preview()
    if not G or not G.GAME or not G.STATES or G.STATE ~= G.STATES.SELECTING_HAND then return nil end
    if not G.hand or not G.hand.highlighted or #G.hand.highlighted == 0 then return nil end
    if not G.play or not G.FUNCS or type(G.FUNCS.get_poker_hand_info) ~= "function" then return nil end
    if not SMODS or not SMODS.Scoring_Parameters then return nil end

    local selected = sorted_selected_cards()
    if selected_has_hidden_cards(selected) then
        return { mode = "hidden" }
    end

    local snapshot = capture_state()

    if show_ev() then
        local floor, totals = sample_scoring(selected, snapshot, ev_samples())
        if floor then return summarize_ev(floor, totals) end
        return calculate_basic(selected)
    end

    local ok, result = with_sandbox(function()
        return run_true_scoring(selected)
    end)
    restore_state(snapshot)

    if ok and result then return result end

    local basic = calculate_basic(selected)
    if basic then
        basic.error = ok and nil or tostring(result)
    end
    return basic
end

local function set_idle()
    ScorePreview.ui.line = preview_idle_text()
    -- Keep the last computed exchange rate visible (e.g. in the shop) instead of
    -- clearing it; it is refreshed as soon as a new hand is previewed.
    ScorePreview.ui.target_reached = false
end

local function set_unavailable(reason)
    ScorePreview.ui.line = preview_idle_text()
    ScorePreview.ui.target_reached = false
end

local function result_reaches_blind(result)
    if not result or result.mode == "hidden" or result.total == nil then return false end
    if not G or not G.GAME or not G.GAME.blind then return false end

    local current_score = tonumber(G.GAME.chips) or 0
    local preview_score = tonumber(result.total)
    local target_score = tonumber(G.GAME.blind.chips)

    if not preview_score or not target_score or target_score <= 0 then return false end
    return current_score + preview_score >= target_score
end

local function apply_result(result)
    if not result then
        set_unavailable()
        return
    end

    if result.mode == "hidden" then
        ScorePreview.ui.line = preview_unknown_text()
        ScorePreview.ui.target_reached = false
        return
    end

    ScorePreview.ui.target_reached = result_reaches_blind(result)
    local line = preview_prefix() .. fmt_number(result.total)
        .. (ScorePreview.ui.target_reached and preview_enough_text() or "")
    if result.random and result.ev then
        line = line .. "  ~" .. fmt_number(result.ev)
        if result.clear_rate then line = line .. " " .. tostring(result.clear_rate) .. "%" end
    end
    ScorePreview.ui.line = line
    ScorePreview.ui.exchange = exchange_rate_text(result.chips, result.mult)
end

-- ---------------------------------------------------------------------------
-- Shop joker-swap impact. When hovering a shop joker, re-simulate the last hand
-- played with that joker added (or swapped in for the rightmost if slots are
-- full) and report the raw Δ% versus your current jokers. Opt-in; guarded so any
-- wrong assumption degrades to no readout rather than a crash.
-- ---------------------------------------------------------------------------

local swap_cache = { key = nil, text = "" }

local function joker_limit()
    return (G and G.jokers and G.jokers.config and tonumber(G.jokers.config.card_limit)) or 5
end

-- A joker you could take into your loadout: one being sold in the shop, or one
-- being offered inside an opened booster (Buffoon) pack.
local function is_swappable_joker(card)
    if not (card and G and card.ability and card.ability.set == "Joker") then return false end
    local area = card.area
    return area ~= nil and (area == G.shop_jokers or area == G.pack_cards)
end

local function last_play_cards()
    local lp = ScorePreview.last_play
    if not lp or type(lp.cards) ~= "table" then return nil end
    local cards = {}
    for _, c in ipairs(lp.cards) do
        if type(c) == "table" and not c.removed and c.ability then cards[#cards + 1] = c end
    end
    return (#cards > 0) and cards or nil
end

local function score_hand_with_jokers(joker_list, snapshot, selected, adj)
    restore_state(snapshot)
    G.jokers.cards = joker_list
    for _, c in ipairs(joker_list) do c.area = G.jokers; c.parent = G.jokers end
    -- Optionally shift the played hand's level (planet-as-player, or next-level estimate)
    -- by whole level increments, adjusting its base (restored with the rest of the snapshot).
    if adj and G.GAME and G.GAME.hands and G.GAME.hands[adj.type] then
        local h = G.GAME.hands[adj.type]
        h.chips = (tonumber(h.chips) or 0) + adj.d_chips
        h.mult = (tonumber(h.mult) or 0) + adj.d_mult
        h.level = (tonumber(h.level) or 1) + adj.d_level
    end
    local ok, result = with_sandbox(function()
        return run_true_scoring(selected)
    end, false)
    return ok and result and tonumber(result.total) or nil
end

local function level_down(info)
    return { type = info.type, d_chips = -info.l_chips, d_mult = -info.l_mult, d_level = -1 }
end

local function level_up(info)
    return { type = info.type, d_chips = info.l_chips, d_mult = info.l_mult, d_level = 1 }
end

local function joker_name(card)
    if not card or not card.ability then return "Joker" end
    if type(localize) == "function" and card.config and card.config.center_key then
        local ok, r = pcall(localize, { type = "name_text", key = card.config.center_key, set = "Joker" })
        if ok then
            if type(r) == "string" and r ~= "" and r ~= "ERROR" then return r end
            if type(r) == "table" and type(r[1]) == "string" and r[1] ~= "" then return r[1] end
        end
    end
    return tostring(card.ability.name or "Joker")
end

-- Format a breakdown as a compact, sorted, top-5 HUD line with a mode label
-- ("Drop: " = leave-one-out drop-cost, "Fair: " = Shapley fair share).
local function format_breakdown_rows(rows, label, field)
    field = field or "pct"
    if type(rows) ~= "table" or #rows == 0 then return "" end
    -- Disambiguate duplicate joker names by loadout position (e.g. two Holograms).
    local seen = {}
    for _, r in ipairs(rows) do seen[r.name] = (seen[r.name] or 0) + 1 end
    table.sort(rows, function(a, b) return (a[field] or 0) > (b[field] or 0) end)
    local parts = {}
    for _, r in ipairs(rows) do
        local v = r[field]
        if v ~= nil then
            local num = string.format("%.0f", v)
            if num ~= "0" and num ~= "-0" then      -- omit entries that round to 0%
                local name = r.name
                if r.slot and (seen[name] or 0) > 1 then name = name .. " #" .. r.slot end
                parts[#parts + 1] = name .. " " .. (v >= 0 and "+" or "") .. num .. "%"
                if #parts >= 5 then break end
            end
        end
    end
    if #parts == 0 then return "" end
    return (label or "") .. table.concat(parts, " · ")
end

-- Per-level chip/mult increments for the played hand, so a subset can be scored one level
-- lower (planet-as-player) or one higher (next-level estimate). Gated on the breakdown
-- being on; returns nil if the increments aren't available. `level` lets callers apply
-- their own floor (the planet player needs level >= 2; the next-level estimate does not).
local function last_level_info(selected)
    if not show_breakdown() then return nil end
    if not G or not G.GAME or type(G.GAME.hands) ~= "table" then return nil end
    if not G.FUNCS or type(G.FUNCS.get_poker_hand_info) ~= "function" then return nil end
    local ok, hand_key = pcall(G.FUNCS.get_poker_hand_info, selected)
    if not ok or type(hand_key) ~= "string" then return nil end
    local h = G.GAME.hands[hand_key]
    if type(h) ~= "table" then return nil end
    local lc, lm = tonumber(h.l_chips), tonumber(h.l_mult)
    if not lc or not lm then return nil end
    local name = hand_key
    if type(localize) == "function" then
        local lok, r = pcall(localize, hand_key, "poker_hands")
        if lok and type(r) == "string" and r ~= "" and r ~= "ERROR" then name = r end
    end
    return { type = hand_key, l_chips = lc, l_mult = lm, level = tonumber(h.level) or 1, name = name }
end

-- Leave-one-out breakdown of a played hand: each joker's Δ% is how much score is lost
-- if that one joker is removed (the rest kept). Impacts intentionally overlap and do not
-- sum -- synergy (e.g. two ×Mult) credits both. The played hand's last level can be added
-- as an extra player. Runs entirely on the snapshot/restore, untouched real play on error.
local function compute_breakdown(selected)
    if type(selected) ~= "table" or #selected == 0 then return "" end
    if not G or not G.jokers or type(G.jokers.cards) ~= "table" then return "" end

    local jokers = shallow_copy_array(G.jokers.cards)
    local info = last_level_info(selected)
    local planet = (show_planet() and info and info.level >= 2) and info or nil
    if #jokers == 0 and not planet then return "" end

    local snapshot = capture_state()

    local ok, rows = pcall(function()
        local full = score_hand_with_jokers(shallow_copy_array(jokers), snapshot, selected)
        if not full or full <= 0 then return nil end
        local out = {}
        for i = 1, #jokers do
            local without = {}
            for k, c in ipairs(jokers) do if k ~= i then without[#without + 1] = c end end
            local s = score_hand_with_jokers(without, snapshot, selected)
            if s then
                out[#out + 1] = { name = joker_name(jokers[i]), pct = ((full - s) / full) * 100, slot = i }
            end
        end
        if planet then
            local s = score_hand_with_jokers(jokers, snapshot, selected, level_down(planet))
            if s then out[#out + 1] = { name = planet.name .. " Lv", pct = ((full - s) / full) * 100 } end
        end
        return out
    end)

    restore_state(snapshot)
    if not ok or type(rows) ~= "table" or #rows == 0 then return "" end
    return format_breakdown_rows(rows, "Drop: ")
end

-- Beyond this joker count, exact Shapley (2^N scoring passes) gets expensive, so we
-- fall back to leave-one-out. 6 jokers = 64 passes, once per hand.
local SHAPLEY_MAX_JOKERS = 6

-- Shapley value of each joker: its average marginal contribution across every subset of
-- the others. Unlike leave-one-out these DO form a fair partition (they sum to the
-- joker-driven score, v(all) - v(none)), splitting synergy credit. Reported as % of the
-- full hand score, same denominator as LOO so the two modes are comparable.
-- Returns "" for no jokers, nil to signal "fall back to LOO" (too many jokers, or error).
local function compute_shapley(selected)
    if type(selected) ~= "table" or #selected == 0 then return "" end
    if not G or not G.jokers or type(G.jokers.cards) ~= "table" then return "" end

    local jokers = shallow_copy_array(G.jokers.cards)
    local n = #jokers

    -- The played hand's last level can join as an extra player. It's the highest-indexed
    -- player; when it's OUT of a coalition the hand is scored one level lower.
    local info = last_level_info(selected)
    local planet = (show_planet() and info and info.level >= 2) and info or nil
    if planet and (n + 1) > SHAPLEY_MAX_JOKERS then planet = nil end   -- keep 2^p passes bounded
    if n == 0 and not planet then return "" end
    if n > SHAPLEY_MAX_JOKERS then return nil end                      -- too many jokers -> LOO

    local p = n + (planet and 1 or 0)

    -- LuaJIT has no native bitwise ops; use arithmetic on precomputed powers of two.
    local two_pow = { [0] = 1 }
    for k = 1, p do two_pow[k] = two_pow[k - 1] * 2 end
    local fact = { [0] = 1 }
    for k = 1, p do fact[k] = fact[k - 1] * k end
    local planet_bit = planet and two_pow[p - 1] or nil

    local snapshot = capture_state()

    local ok, rows = pcall(function()
        local total = two_pow[p]
        local val = {}
        for mask = 0, total - 1 do
            local sub = {}
            for j = 1, n do
                if math.floor(mask / two_pow[j - 1]) % 2 == 1 then sub[#sub + 1] = jokers[j] end
            end
            -- planet OUT of the coalition => score the hand one level lower
            local lower = (planet and math.floor(mask / planet_bit) % 2 == 0) and level_down(planet) or nil
            val[mask] = score_hand_with_jokers(sub, snapshot, selected, lower) or 0
        end

        local full = val[total - 1]
        if not full or full <= 0 then return nil end

        local out = {}
        for i = 1, p do
            local bit_i = two_pow[i - 1]
            local phi = 0
            for mask = 0, total - 1 do
                if math.floor(mask / bit_i) % 2 == 0 then      -- subset S without player i
                    local s, m = 0, mask
                    while m > 0 do s = s + (m % 2); m = math.floor(m / 2) end
                    local weight = (fact[s] * fact[p - s - 1]) / fact[p]
                    phi = phi + weight * (val[mask + bit_i] - val[mask])
                end
            end
            if i <= n then
                out[#out + 1] = { name = joker_name(jokers[i]), pct = (phi / full) * 100, slot = i }
            else
                out[#out + 1] = { name = planet.name .. " Lv", pct = (phi / full) * 100 }
            end
        end
        return out
    end)

    restore_state(snapshot)
    if not ok or type(rows) ~= "table" or #rows == 0 then return nil end
    return format_breakdown_rows(rows, "Fair: ")
end

-- Estimate of what one more level of the played hand would add to THIS hand: score it
-- one level higher with the current jokers, minus the current score. Works at any level.
local function next_level_line(selected)
    local info = last_level_info(selected)
    if not info then return "" end
    if not G or not G.jokers or type(G.jokers.cards) ~= "table" then return "" end
    local jokers = shallow_copy_array(G.jokers.cards)
    local snapshot = capture_state()
    local ok, est = pcall(function()
        local full = score_hand_with_jokers(jokers, snapshot, selected)
        local up = score_hand_with_jokers(jokers, snapshot, selected, level_up(info))
        if not full or not up then return nil end
        return up - full
    end)
    restore_state(snapshot)
    if not ok or type(est) ~= "number" then return "" end
    local sign = est >= 0 and "+" or ""
    local lang = language_group()
    if lang == "zh_cn" then return "下一 " .. info.name .. " 等级 ~ " .. sign .. fmt_number(est) end
    if lang == "zh_tw" then return "下一 " .. info.name .. " 等級 ~ " .. sign .. fmt_number(est) end
    return "Next " .. info.name .. " Lv ~ " .. sign .. fmt_number(est)
end

local card_breakdown_labels = {
    Cards = { en = "Cards: ", zh_cn = "卡牌: ", zh_tw = "卡牌: " },
    Editions = { en = "Editions", zh_cn = "闪卡", zh_tw = "閃卡" },
    Seals = { en = "Seals", zh_cn = "蜡封", zh_tw = "蠟封" }
}

local function card_label(key)
    local e = card_breakdown_labels[key]
    if not e then return key end
    return e[language_group()] or e.en
end

-- Score the hand with a set of card fields temporarily nil'd (e.g. "edition" or "seal")
-- across all played cards. These fields aren't part of the snapshot, so we save and
-- restore them by hand around the pass.
local function score_without_card_field(selected, snapshot, jokers, field)
    local saved = {}
    for _, c in ipairs(selected) do
        if c[field] ~= nil then saved[#saved + 1] = { c = c, v = c[field] }; c[field] = nil end
    end
    local s = score_hand_with_jokers(jokers, snapshot, selected)
    for _, e in ipairs(saved) do e.c[field] = e.v end
    return s
end

-- Leave-one-out breakdown of the played cards' editions and seals, grouped by type.
-- Enhancements are not covered yet (they live in card.ability, which the snapshot
-- restores, so they need an after-restore reset rather than a simple field strip).
local function compute_card_breakdown(selected)
    if type(selected) ~= "table" or #selected == 0 then return "" end
    if not G or not G.jokers or type(G.jokers.cards) ~= "table" then return "" end

    local has_edition, has_seal = false, false
    for _, c in ipairs(selected) do
        if c.edition then has_edition = true end
        if c.seal then has_seal = true end
    end
    if not has_edition and not has_seal then return "" end

    local jokers = shallow_copy_array(G.jokers.cards)
    local snapshot = capture_state()
    local ok, rows = pcall(function()
        local full = score_hand_with_jokers(jokers, snapshot, selected)
        if not full or full <= 0 then return nil end
        local out = {}
        if has_edition then
            local s = score_without_card_field(selected, snapshot, jokers, "edition")
            if s then out[#out + 1] = { name = card_label("Editions"), pct = ((full - s) / full) * 100 } end
        end
        if has_seal then
            local s = score_without_card_field(selected, snapshot, jokers, "seal")
            if s then out[#out + 1] = { name = card_label("Seals"), pct = ((full - s) / full) * 100 } end
        end
        return out
    end)
    restore_state(snapshot)
    if not ok or type(rows) ~= "table" or #rows == 0 then return "" end
    return format_breakdown_rows(rows, card_label("Cards"))
end

local function compute_swap_delta(candidate)
    local selected = last_play_cards()
    if not selected then return nil end
    if not G or not G.jokers or type(G.jokers.cards) ~= "table" then return nil end

    local current = shallow_copy_array(G.jokers.cards)
    local swapped = shallow_copy_array(current)
    if #swapped >= joker_limit() and #swapped > 0 then
        table.remove(swapped)      -- drop the rightmost joker
    end
    swapped[#swapped + 1] = candidate

    -- The candidate lives in G.shop_jokers, which is not part of the snapshot, so
    -- preserve and restore its home area around the simulation.
    local cand_area, cand_parent = candidate.area, candidate.parent

    local snapshot = capture_state()
    local base = score_hand_with_jokers(current, snapshot, selected)
    local with = score_hand_with_jokers(swapped, snapshot, selected)
    restore_state(snapshot)

    candidate.area, candidate.parent = cand_area, cand_parent

    if not base or not with or base <= 0 then return nil end
    return ((with - base) / base) * 100
end

local function swap_signature(candidate)
    local parts = { tostring(candidate) }
    if G and G.jokers and G.jokers.cards then
        for _, c in ipairs(G.jokers.cards) do parts[#parts + 1] = tostring(c) end
    end
    local lp = ScorePreview.last_play
    parts[#parts + 1] = lp and tostring(lp.stamp) or "-"
    return table.concat(parts, "|")
end

local function swap_delta_text(pct)
    local body = (pct >= 0 and "+" or "") .. string.format("%.0f", pct) .. "%"
    local lang = language_group()
    if lang == "zh_cn" then return "换牌 Δ " .. body end
    if lang == "zh_tw" then return "換牌 Δ " .. body end
    return "Swap Δ " .. body
end

-- Returns true if it produced a swap readout (so update() should stop). Only ever
-- called outside SELECTING_HAND; the hovered-area check limits it to the shop and
-- open-pack contexts, so no explicit state whitelist is needed (covers all pack types).
local function update_swap_readout()
    if not show_swap() then return false end
    if not is_swappable_joker(ScorePreview.hovered) then return false end

    local candidate = ScorePreview.hovered
    local sig = swap_signature(candidate)
    if swap_cache.key ~= sig then
        swap_cache.key = sig
        local ok, pct = pcall(compute_swap_delta, candidate)
        swap_cache.text = (ok and type(pct) == "number") and swap_delta_text(pct) or ""
    end
    if swap_cache.text == "" then return false end
    ScorePreview.ui.line = swap_cache.text
    ScorePreview.ui.target_reached = false
    return true
end

function ScorePreview.update()
    if not G or not G.GAME or not G.STATES or G.STATE ~= G.STATES.SELECTING_HAND then
        ScorePreview.cache.signature = nil
        ScorePreview.cache.result = nil
        if update_swap_readout() then return end
        set_idle()
        return
    end

    repair_known_enhancement_centers()

    if not G.hand or not G.hand.highlighted or #G.hand.highlighted == 0 then
        ScorePreview.cache.signature = nil
        ScorePreview.cache.result = nil
        set_idle()
        return
    end

    local signature = selection_signature()
    if ScorePreview.cache.signature ~= signature then
        ScorePreview.cache.signature = signature
        ScorePreview.cache.result = calculate_preview()
    end

    apply_result(ScorePreview.cache.result)
end

G.FUNCS.scorepreview_update = function(e)
    ScorePreview.update()
    if e and e.config then
        if ScorePreview.ui.target_reached then
            e.config.colour = mix_colours(G.C.GREEN, G.C.BLACK, 0.42)
            e.config.emboss = 0.08
            e.config.outline = 1.1
            e.config.outline_colour = G.C.MONEY
        else
            e.config.colour = darken(G.C.BLACK, 0.08)
            e.config.emboss = 0.04
            e.config.outline = 0
            e.config.outline_colour = G.C.CLEAR
        end
    end
end

function ScorePreview.preview_ui()
    local scale = 0.44
    return {
        n = G.UIT.R,
        config = {
            align = "cm",
            id = "scorepreview_row",
            func = "scorepreview_update",
            colour = darken(G.C.BLACK, 0.08),
            r = 0.1,
            emboss = 0.04,
            outline = 0,
            outline_colour = G.C.CLEAR,
            padding = 0.04,
            minh = 0.45
        },
        nodes = {
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.01, maxw = 4.4 },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = ScorePreview.ui, ref_value = "line", scale = scale, colour = G.C.MONEY, shadow = true } }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.01, maxw = 4.4 },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = ScorePreview.ui, ref_value = "exchange", scale = scale * 0.72, colour = G.C.UI.TEXT_LIGHT, shadow = true } }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.01, maxw = 5.0 },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = ScorePreview.ui, ref_value = "breakdown", scale = scale * 0.72, colour = G.C.BLUE, shadow = true } }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.01, maxw = 5.0 },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = ScorePreview.ui, ref_value = "nextlevel", scale = scale * 0.72, colour = G.C.MONEY, shadow = true } }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.01, maxw = 5.0 },
                nodes = {
                    { n = G.UIT.T, config = { ref_table = ScorePreview.ui, ref_value = "cardbreakdown", scale = scale * 0.72, colour = G.C.PURPLE, shadow = true } }
                }
            }
        }
    }
end

local function restore_button_label()
    local lang = language_group()
    if lang == "zh_cn" then return "弃牌回抽" end
    if lang == "zh_tw" then return "棄牌回抽" end
    return "Restore Discards"
end

-- Move every card in the discard pile back into the draw pile so it can be drawn again.
-- These are existing cards being relocated, so we only remove_card/emplace -- never
-- remove_from_deck/add_to_deck, which would delete or double-register them. Fully guarded.
local function restore_discards_to_deck()
    if not G or not G.deck or not G.discard or type(G.discard.cards) ~= "table" then return 0 end
    local cards = {}
    for _, c in ipairs(G.discard.cards) do cards[#cards + 1] = c end
    local moved = 0
    for _, card in ipairs(cards) do
        if card.area and type(card.area.remove_card) == "function" then
            pcall(function() card.area:remove_card(card) end)
        end
        local ok = pcall(function() G.deck:emplace(card) end)
        if ok then moved = moved + 1 end
    end
    if moved > 0 then
        if type(G.deck.shuffle) == "function" then pcall(function() G.deck:shuffle("cp_restore") end) end
        if type(G.deck.set_ranks) == "function" then pcall(function() G.deck:set_ranks() end) end
        if type(G.deck.align_cards) == "function" then pcall(function() G.deck:align_cards() end) end
        if type(G.hand) == "table" and type(G.hand.align_cards) == "function" then
            pcall(function() G.hand:align_cards() end)
        end
    end
    return moved
end

G.FUNCS.comfortpack_restore_discards = function(e)
    pcall(restore_discards_to_deck)
end

function ScorePreview.restore_button_ui()
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.04 },
        nodes = {
            {
                n = G.UIT.C,
                config = {
                    align = "cm", minw = 3.0, minh = 0.5, padding = 0.06, r = 0.1,
                    colour = G.C.PURPLE, button = "comfortpack_restore_discards",
                    hover = true, shadow = true
                },
                nodes = {
                    { n = G.UIT.T, config = { text = restore_button_label(), scale = 0.32, colour = G.C.UI.TEXT_LIGHT, shadow = true } }
                }
            }
        }
    }
end

local create_UIBox_HUD_ref = create_UIBox_HUD
function create_UIBox_HUD()
    local ui = create_UIBox_HUD_ref()
    local rows = ui
        and ui.nodes and ui.nodes[1]
        and ui.nodes[1].nodes and ui.nodes[1].nodes[1]
        and ui.nodes[1].nodes[1].nodes

    if type(rows) ~= "table" then return ui end

    for i, row in ipairs(rows) do
        if row and row.config and row.config.id == "row_round" then
            table.insert(rows, i, ScorePreview.preview_ui())
            if show_restore() then table.insert(rows, i + 1, ScorePreview.restore_button_ui()) end
            return ui
        end
    end

    rows[#rows + 1] = ScorePreview.preview_ui()
    if show_restore() then rows[#rows + 1] = ScorePreview.restore_button_ui() end
    return ui
end

-- Record the cards of each real hand played so the shop swap readout can re-simulate
-- the last hand. Preview sandboxing never routes through evaluate_play, so this only
-- fires on genuine plays.
if G and G.FUNCS and type(G.FUNCS.evaluate_play) == "function" then
    local evaluate_play_ref = G.FUNCS.evaluate_play
    G.FUNCS.evaluate_play = function(e)
        if G and G.play and type(G.play.cards) == "table" and #G.play.cards > 0 then
            local cards = {}
            for _, c in ipairs(G.play.cards) do cards[#cards + 1] = c end
            ScorePreview.play_counter = (ScorePreview.play_counter or 0) + 1
            ScorePreview.last_play = { cards = cards, stamp = ScorePreview.play_counter }
            -- Per-joker breakdown, computed before the real scoring so jokers are still
            -- in their pre-hand state. Fully guarded: on any failure the real play is
            -- unaffected and the line is just cleared.
            if show_breakdown() then
                local text = nil
                if show_shapley() then
                    local ok, t = pcall(compute_shapley, cards)
                    if ok then text = t end   -- nil => fall back to leave-one-out
                end
                if text == nil then
                    local ok2, t2 = pcall(compute_breakdown, cards)
                    text = (ok2 and type(t2) == "string") and t2 or ""
                end
                ScorePreview.ui.breakdown = text
                local ok3, nl = pcall(next_level_line, cards)
                ScorePreview.ui.nextlevel = (ok3 and type(nl) == "string") and nl or ""
            end
            if show_card_breakdown() then
                local okc, cb = pcall(compute_card_breakdown, cards)
                ScorePreview.ui.cardbreakdown = (okc and type(cb) == "string") and cb or ""
            end
        end
        return evaluate_play_ref(e)
    end
end

-- Track the hovered card so the shop readout knows which joker to evaluate.
if Card and type(Card.hover) == "function" and type(Card.stop_hover) == "function" then
    local card_hover_ref = Card.hover
    function Card:hover()
        ScorePreview.hovered = self
        return card_hover_ref(self)
    end
    local card_stop_hover_ref = Card.stop_hover
    function Card:stop_hover()
        if ScorePreview.hovered == self then ScorePreview.hovered = nil end
        return card_stop_hover_ref(self)
    end
end
