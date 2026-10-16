--- Preview Overlay
--- Shows, above each card in hand, how many cards of the same rank and of the
--- same rank and suit are left in the draw pile. Display only: no gameplay changes.

POV = POV or {}
POV.mod = SMODS.current_mod
POV.config = POV.mod.config

-- Icon next to the mod's name in the mods list.
SMODS.Atlas { key = 'modicon', path = 'modicon.png', px = 34, py = 34 }

POV.OPACITY = { 0.2, 0.4, 0.6, 0.8, 1.0 }
POV.OPACITY_LABELS = { '20%', '40%', '60%', '80%', '100%' }
POV.TEXT_SCALE = { 0.28, 0.34, 0.42 }
POV.TEXT_LABELS = { 'Small', 'Medium', 'Large' }
POV.POSITION_LABELS = { 'Directly above', 'Top of card', 'Bottom of card' }
-- Space between the pills and the card's edge, in game units.
POV.ABOVE_GAP = 0.02
POV.INSET = 0.06
POV.PALETTE_LABELS = { 'High Contrast', 'Game setting', 'Standard' }
POV.COUNTER_POSITION_LABELS = { 'Above the deck', 'Left of deck' }
-- Base suits in the order Balatro's deck view uses; modded suits follow.
POV.SUIT_ORDER = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }
POV.CUTOFFS = {}
for i = 8, 40 do POV.CUTOFFS[#POV.CUTOFFS + 1] = i end

-- Recount timing, in seconds. Recount once the hand has stayed still for
-- SETTLE seconds, outside scoring and drawing. MAX_WAIT is a safety net for
-- cards that never quite come to rest; it never fires during scoring or drawing.
POV.SETTLE = 0.15
POV.MAX_WAIT = 3.0
-- How close (in game units) a card must be to its resting spot to count as still.
POV.REST_EPSILON = 0.02
-- How far to lighten the Spades colour so it reads on the dark pill (0 to 1).
POV.SPADES_LIGHTEN = 0.45
-- Sideways nudge of the Stone counter toward the screen edge, in game units
-- (about a dozen pixels at 1080p).
POV.STONE_NUDGE_X = 0.10
-- Space between the counters and the deck's left edge, in game units.
POV.LEFT_GAP = 0.1
-- How far below the deck's bottom edge the "Left of deck" counters sit, in
-- game units (about 20 pixels at 1080p).
POV.LEFT_DROP = 0.22

POV.dirty = true
POV.dirty_since = nil
POV.settled_since = nil
POV.stone_count = 0
POV.suit_counts = {}
POV.cutoff_hidden = false
POV.pack_hidden = false
POV.last_state = nil
POV.tracked = setmetatable({}, { __mode = 'k' })

local function now()
    return (G.TIMERS and G.TIMERS.REAL) or 0
end

function POV.mark_dirty()
    -- Any new change restarts the settle timer.
    POV.settled_since = nil
    if not POV.dirty then
        POV.dirty = true
        POV.dirty_since = now()
    end
end

local function log_error(msg)
    if sendErrorMessage then
        sendErrorMessage(tostring(msg), 'PreviewOverlay')
    else
        print('[PreviewOverlay] ' .. tostring(msg))
    end
end

---------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------

local function is_stone(card)
    return SMODS.has_enhancement(card, 'm_stone')
end

local function has_rank(card)
    return card.base and card.base.value and not SMODS.has_no_rank(card)
end

-- Wild that is actually acting as every suit right now (a debuffed Wild only
-- counts as its base suit).
local function is_active_wild(card)
    return SMODS.has_any_suit(card) and not card.debuff
end

--- Works out what each hand card should show. Pure: reads cards, writes nothing.
--- Returns a table keyed by hand card, plus the Stone count in the draw pile.
function POV.compute(hand_cards, deck_cards)
    local rank_counts, stones = {}, 0
    for _, d in ipairs(deck_cards) do
        if is_stone(d) then stones = stones + 1 end
        if has_rank(d) then
            rank_counts[d.base.value] = (rank_counts[d.base.value] or 0) + 1
        end
    end

    local result = {}
    for _, c in ipairs(hand_cards) do
        if not has_rank(c) then
            result[c] = { kind = 'stone', a = stones }
        else
            local rank = c.base.value
            local a = rank_counts[rank] or 0
            if is_active_wild(c) then
                result[c] = { kind = 'wild', a = a }
            else
                local suit, b = c.base.suit, 0
                for _, d in ipairs(deck_cards) do
                    -- is_suit with flush_calc ignores debuffs on normal cards,
                    -- treats active Wilds as every suit, debuffed Wilds as their
                    -- base suit, Stones as no suit, and applies Smeared Joker.
                    if has_rank(d) and d.base.value == rank and d:is_suit(suit, nil, true) then
                        b = b + 1
                    end
                end
                result[c] = { kind = 'normal', a = a, b = b, suit = suit }
            end
        end
    end
    return result, stones
end

--- Cards left in the draw pile per suit, by each card's own (base) suit.
--- Stone cards have no suit and are left out. Lists every suit that appears
--- anywhere in the player's full deck, so a suit that runs out shows 0.
function POV.count_suits(deck_cards, all_cards)
    local counts, present = {}, {}
    for _, c in ipairs(all_cards or deck_cards) do
        if c.base and c.base.suit and not SMODS.has_no_suit(c) then present[c.base.suit] = true end
    end
    for _, d in ipairs(deck_cards) do
        if d.base and d.base.suit and not SMODS.has_no_suit(d) then
            counts[d.base.suit] = (counts[d.base.suit] or 0) + 1
            present[d.base.suit] = true
        end
    end
    local list, seen = {}, {}
    for _, suit in ipairs(POV.SUIT_ORDER) do
        if present[suit] then list[#list + 1] = { suit = suit, n = counts[suit] or 0 }; seen[suit] = true end
    end
    local extra = {}
    for suit in pairs(present) do
        if not seen[suit] then extra[#extra + 1] = suit end
    end
    table.sort(extra)
    for _, suit in ipairs(extra) do list[#list + 1] = { suit = suit, n = counts[suit] or 0 } end
    return list
end

---------------------------------------------------------------------------
-- When to show
---------------------------------------------------------------------------

function POV.in_pack()
    return G.STATE == G.STATES.SMODS_BOOSTER_OPENED
        or G.STATE == G.STATES.TAROT_PACK
        or G.STATE == G.STATES.SPECTRAL_PACK
end

function POV.active()
    local cfg = POV.config
    if not cfg.enabled or not G.hand or not G.deck or not G.GAME then return false end
    if POV.cutoff_hidden then return false end
    if POV.in_pack() and not cfg.show_in_packs then return false end
    return true
end

-- Counts waiting on a recount are hidden when a pack opens, or always when the
-- "Hide stale counts" option is on.
function POV.stale_hidden()
    return POV.dirty and (POV.pack_hidden or POV.config.hide_stale)
end

local function card_shows_pills(card)
    return POV.active() and not POV.stale_hidden() and card.area == G.hand and card.facing ~= 'back'
end

G.FUNCS.pov_pill_visibility = function(e)
    local visible = card_shows_pills(e.config.ref_table)
    e.states.visible = visible
    if e.UIBox then e.UIBox.states.visible = visible end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function lightened(c, amount)
    return { c[1] + (1 - c[1]) * amount, c[2] + (1 - c[2]) * amount, c[3] + (1 - c[3]) * amount, c[4] or 1 }
end

local function suit_colour(suit)
    -- 1 High Contrast, 2 whatever the game is set to, 3 the game's standard colours.
    local choice = POV.config.palette
    local palette = choice == 1 and G.C.SO_2 or choice == 3 and G.C.SO_1 or G.C.SUITS
    local c = (palette and palette[suit]) or (G.C.SUITS and G.C.SUITS[suit]) or G.C.WHITE
    -- Spades is nearly black, which disappears on the dark pill.
    if suit == 'Spades' then c = lightened(c, POV.SPADES_LIGHTEN) end
    return c
end

local function background()
    return adjust_alpha(darken(G.C.BLACK, 0.2), POV.OPACITY[POV.config.opacity] or 0.8)
end

local function pill(text, colour, scale, bg)
    return {
        n = G.UIT.C,
        config = { align = 'cm', padding = 0.05, r = 0.08, colour = bg, minw = scale * 1.1 },
        nodes = {
            { n = G.UIT.T, config = { text = tostring(text), scale = scale, colour = colour } },
        },
    }
end

local function signature(info)
    local cfg = POV.config
    return table.concat({
        info.kind, info.a, info.b or '-', info.suit or '-',
        cfg.opacity, cfg.palette, cfg.pill_order, cfg.text_size, cfg.pill_position,
        tostring(cfg.show_zero_exact),
    }, '|')
end

local function remove_pills(card)
    if card.children and card.children.pov_pills then
        -- The box may already be gone if the card itself was removed.
        pcall(function() card.children.pov_pills:remove() end)
        card.children.pov_pills = nil
    end
    card.pov_sig = nil
    POV.tracked[card] = nil
end

function POV.apply(card, info)
    local sig = signature(info)
    if card.pov_sig == sig and card.children.pov_pills then return end
    remove_pills(card)

    local cfg = POV.config
    local scale = POV.TEXT_SCALE[cfg.text_size] or 0.34
    local bg = background()
    local light = G.C.UI.TEXT_LIGHT

    local rank_pill = pill(info.a, light, scale, bg)
    local pills
    if info.kind == 'stone' or info.kind == 'wild' then
        pills = { rank_pill }
    else
        local exact_pill
        if info.b > 0 or cfg.show_zero_exact then
            exact_pill = pill(info.b, suit_colour(info.suit), scale, bg)
        end
        if not exact_pill then
            pills = { rank_pill }
        elseif cfg.pill_order == 2 then
            pills = { exact_pill, rank_pill }
        else
            pills = { rank_pill, exact_pill }
        end
    end

    local row = {}
    for i, p in ipairs(pills) do
        if i > 1 then row[#row + 1] = { n = G.UIT.B, config = { w = 0.08, h = 0.01 } } end
        row[#row + 1] = p
    end

    local box = UIBox {
        definition = {
            n = G.UIT.ROOT,
            config = { align = 'cm', colour = G.C.CLEAR, padding = 0, func = 'pov_pill_visibility', ref_table = card },
            nodes = { { n = G.UIT.R, config = { align = 'cm', padding = 0 }, nodes = row } },
        },
        config = { align = 'cm', offset = { x = 0, y = 0 }, major = card, parent = card, bond = 'Strong' },
        states = { collide = { can = false }, drag = { can = true } },
    }
    -- 1: just above the card's top edge. 2: on the card, inside its top edge.
    -- 3: on the card, inside its bottom edge.
    local half = card.T.h / 2 - box.T.h / 2
    local y
    if cfg.pill_position == 2 then
        y = -(half - POV.INSET)
    elseif cfg.pill_position == 3 then
        y = half - POV.INSET
    else
        y = -(card.T.h / 2 + box.T.h / 2 + POV.ABOVE_GAP)
    end
    box:set_alignment { major = card, type = 'cm', bond = 'Strong', offset = { x = 0, y = y } }
    box.states.visible = card_shows_pills(card)

    card.children.pov_pills = box
    card.pov_sig = sig
    POV.tracked[card] = true
end

---------------------------------------------------------------------------
-- Suit and Stone counters next to the deck
---------------------------------------------------------------------------

local function remove_deck_box()
    if POV.deck_box then
        POV.deck_box:remove()
        POV.deck_box = nil
        POV.deck_sig = nil
    end
end

function POV.update_deck_box()
    local cfg = POV.config
    local shown = POV.active() and not POV.stale_hidden() and #G.hand.cards > 0
    local show_suits = shown and cfg.suit_counter and #POV.suit_counts > 0
    local show_stones = shown and cfg.stone_counter and POV.stone_count > 0
    if not (show_suits or show_stones) then
        remove_deck_box()
        return
    end

    local left = cfg.counter_position == 2
    local parts = { tostring(show_suits), tostring(show_stones), POV.stone_count, cfg.opacity,
        cfg.text_size, cfg.palette, tostring(left) }
    if show_suits then
        for _, e in ipairs(POV.suit_counts) do parts[#parts + 1] = e.suit .. e.n end
    end
    local sig = table.concat(parts, '|')
    if POV.deck_box and POV.deck_sig == sig then return end
    remove_deck_box()

    -- One pill per row: suits first, Stones last, so the suit list sits
    -- directly above the Stone counter.
    local scale = POV.TEXT_SCALE[cfg.text_size] or 0.34
    local bg = background()
    local row_align = left and 'cr' or 'cm'
    local rows = {}
    if show_suits then
        for _, e in ipairs(POV.suit_counts) do
            rows[#rows + 1] = { n = G.UIT.R, config = { align = row_align, padding = 0.02 }, nodes = {
                pill(e.suit .. ': ' .. e.n, suit_colour(e.suit), scale, bg),
            } }
        end
    end
    if show_stones then
        rows[#rows + 1] = { n = G.UIT.R, config = { align = row_align, padding = 0.02 }, nodes = {
            pill('Stones: ' .. POV.stone_count, G.C.UI.TEXT_LIGHT, scale, bg),
        } }
    end

    local box = UIBox {
        definition = {
            n = G.UIT.ROOT,
            config = { align = row_align, colour = G.C.CLEAR, padding = 0 },
            nodes = { { n = G.UIT.C, config = { align = row_align, padding = 0 }, nodes = rows } },
        },
        config = { align = 'cm', offset = { x = 0, y = 0 }, major = G.deck, bond = 'Weak' },
    }
    local offset
    if left then
        -- Bottom-right corner of the counters against the deck's bottom-left corner.
        offset = {
            x = -(G.deck.T.w / 2 + box.T.w / 2 + POV.LEFT_GAP),
            y = G.deck.T.h / 2 - box.T.h / 2 + POV.LEFT_DROP,
        }
    else
        offset = { x = POV.STONE_NUDGE_X, y = -(G.deck.T.h / 2 + box.T.h / 2 + 0.15) }
    end
    box:set_alignment { major = G.deck, type = 'cm', bond = 'Weak', offset = offset }
    -- Drawn by hand after the deck (below), so make sure the game's own UIBox
    -- loop does not draw it a second time.
    if G.I and G.I.UIBOX then
        for i = #G.I.UIBOX, 1, -1 do
            if G.I.UIBOX[i] == box then table.remove(G.I.UIBOX, i) end
        end
    end
    POV.deck_box = box
    POV.deck_sig = sig
end

local cardarea_draw = CardArea.draw
function CardArea:draw(...)
    local ret = cardarea_draw(self, ...)
    if self == G.deck and POV.deck_box then POV.deck_box:draw() end
    return ret
end

---------------------------------------------------------------------------
-- Recount
---------------------------------------------------------------------------

function POV.recount()
    POV.dirty, POV.dirty_since, POV.settled_since = false, nil, nil
    POV.pack_hidden = false
    local infos, stones = POV.compute(G.hand.cards, G.deck.cards)
    POV.stone_count = stones
    POV.suit_counts = POV.count_suits(G.deck.cards, G.playing_cards)
    for card in pairs(POV.tracked) do
        if not infos[card] then remove_pills(card) end
    end
    for card, info in pairs(infos) do
        POV.apply(card, info)
    end
end

-- Scoring and drawing: counts on screen are about to change, so wait.
local function busy_state()
    return G.STATE ~= nil and (G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND)
end

-- True once every card in hand has reached its resting spot.
local function hand_at_rest()
    local eps = POV.REST_EPSILON
    for _, c in ipairs(G.hand.cards) do
        if c.VT and c.T and (math.abs(c.VT.x - c.T.x) > eps or math.abs(c.VT.y - c.T.y) > eps) then
            return false
        end
    end
    return true
end

function POV.update()
    if not (G.hand and G.deck and G.GAME) then return end
    local cfg = POV.config

    -- Opening a pack: hide whatever is on screen until the pack's cards are counted.
    if G.STATE ~= POV.last_state then
        POV.last_state = G.STATE
        if POV.in_pack() then
            POV.pack_hidden = true
            POV.mark_dirty()
        end
    end

    -- Hand-size cutoff: hidden only while the hand is over the limit.
    local hidden = (cfg.cutoff_on and #G.hand.cards > (POV.CUTOFFS[cfg.cutoff] or 17)) and true or false
    if hidden ~= POV.cutoff_hidden then
        POV.cutoff_hidden = hidden
        if not hidden then POV.mark_dirty() end
    end

    if POV.dirty and POV.active() then
        POV.dirty_since = POV.dirty_since or now()
        local busy = busy_state()
        if not busy and hand_at_rest() then
            POV.settled_since = POV.settled_since or now()
        else
            POV.settled_since = nil
        end
        local settled = POV.settled_since and now() - POV.settled_since >= POV.SETTLE
        local overdue = not busy and now() - POV.dirty_since >= POV.MAX_WAIT
        if settled or overdue then
            POV.recount()
        end
    end
    POV.update_deck_box()
end

local game_update = Game.update
function Game:update(dt, ...)
    local ret = game_update(self, dt, ...)
    local ok, err = pcall(POV.update)
    if not ok and not POV.reported_error then
        POV.reported_error = true
        log_error(err)
    end
    return ret
end

---------------------------------------------------------------------------
-- Dirty-flag hooks: anything that adds, removes, or changes a card.
---------------------------------------------------------------------------

local function hook(class, name, check_change)
    local orig = class[name]
    if type(orig) ~= 'function' then return end
    class[name] = function(self, ...)
        local before = check_change and check_change(self)
        local ret = orig(self, ...)
        if not check_change or check_change(self) ~= before then POV.mark_dirty() end
        return ret
    end
end

hook(CardArea, 'emplace')
hook(CardArea, 'remove_card')
hook(Card, 'set_base')
hook(Card, 'set_ability')
hook(Card, 'add_to_deck')
hook(Card, 'remove_from_deck')
hook(Card, 'remove')
-- A card leaving the hand drops its pills right away, so it never brings old
-- numbers back with it the next time it is drawn.
local remove_card = CardArea.remove_card
function CardArea:remove_card(card, ...)
    local ret = remove_card(self, card, ...)
    local gone = ret or card
    if self == G.hand and type(gone) == 'table' and gone.children then remove_pills(gone) end
    return ret
end
-- set_debuff is called often; only a real change matters.
hook(Card, 'set_debuff', function(self) return self.debuff end)

if type(end_round) == 'function' then
    local orig_end_round = end_round
    function end_round(...)
        POV.mark_dirty()
        return orig_end_round(...)
    end
end

---------------------------------------------------------------------------
-- Config menu
---------------------------------------------------------------------------

function POV.on_config_change()
    POV.mark_dirty()
end

local function toggle(label, key)
    return create_toggle {
        label = label, ref_table = POV.config, ref_value = key, w = 0,
        callback = function() POV.on_config_change() end,
    }
end

local function cycle(label, key, options)
    G.FUNCS['pov_cycle_' .. key] = function(args)
        POV.config[key] = args.to_key
        POV.on_config_change()
    end
    return create_option_cycle {
        label = label, options = options, current_option = POV.config[key] or 1,
        opt_callback = 'pov_cycle_' .. key, w = 3.5, scale = 0.8, colour = G.C.RED,
    }
end

local function page(columns)
    local nodes = {}
    for i, col in ipairs(columns) do
        nodes[i] = { n = G.UIT.C, config = { align = 'tl', padding = 0.05 }, nodes = col }
    end
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.1, colour = G.C.BLACK, r = 0.1, minw = 10 },
        nodes = nodes,
    }
end

-- Main "Config" tab: when the overlay shows.
POV.mod.config_tab = function()
    local cutoff_labels = {}
    for i, v in ipairs(POV.CUTOFFS) do cutoff_labels[i] = tostring(v) .. ' cards' end
    return page {
        {
            toggle('Overlay on', 'enabled'),
            toggle('Show in packs', 'show_in_packs'),
            toggle('Hide stale counts', 'hide_stale'),
            toggle('Hand-size cutoff', 'cutoff_on'),
        },
        {
            cycle('Cutoff above', 'cutoff', cutoff_labels),
        },
    }
end

-- Extra tabs: how the pills look, and the counters by the deck.
POV.mod.extra_tabs = function()
    return {
        {
            label = 'Pills',
            tab_definition_function = function()
                return page {
                    {
                        cycle('Background opacity', 'opacity', POV.OPACITY_LABELS),
                        cycle('Text size', 'text_size', POV.TEXT_LABELS),
                        cycle('Pill position', 'pill_position', POV.POSITION_LABELS),
                    },
                    {
                        cycle('Colors for exact match', 'palette', POV.PALETTE_LABELS),
                        cycle('Pill order', 'pill_order', { 'Rank first', 'Exact first' }),
                        toggle('Show zero exact count', 'show_zero_exact'),
                    },
                }
            end,
        },
        {
            label = 'Deck counters',
            tab_definition_function = function()
                return page {
                    {
                        toggle('Suit counter', 'suit_counter'),
                        toggle('Stone counter', 'stone_counter'),
                    },
                    {
                        cycle('Position', 'counter_position', POV.COUNTER_POSITION_LABELS),
                    },
                }
            end,
        },
    }
end
