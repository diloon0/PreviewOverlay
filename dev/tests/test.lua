dofile(MOCK)
dofile(MAIN)
local fails = 0
local function eq(name, got, want) if got ~= want then fails = fails + 1; print('FAIL '..name..': got '..tostring(got)..' want '..tostring(want)) else print('ok   '..name) end end
local C = Card
-- deck: K♥, K♦, K♠ wild, K♣ debuffed-wild, K♥ debuffed, stone, stone, Q♥
local deck = { C('King','Hearts'), C('King','Diamonds'), C('King','Spades','m_wild'), C('King','Clubs','m_wild',true),
               C('King','Hearts',nil,true), C('King','Hearts','m_stone'), C('2','Clubs','m_stone'), C('Queen','Hearts') }
local hK = C('King','Hearts'); local hKs = C('King','Spades'); local hKc = C('King','Clubs')
local hW = C('King','Diamonds','m_wild'); local hWd = C('King','Diamonds','m_wild',true); local hS = C('5','Spades','m_stone')
local hand = {hK, hKs, hKc, hW, hWd, hS}
local r, stones = POV.compute(hand, deck)
eq('stones in draw pile', stones, 2)
eq('K hearts rank total (stone K excluded)', r[hK].a, 5)
eq('K hearts exact: K♥, K♥ debuffed, active wild', r[hK].b, 3)
eq('K spades exact: active wild only', r[hKs].b, 1)
eq('K clubs exact: active wild + debuffed wild (base clubs)', r[hKc].b, 2)
eq('active wild in hand: rank pill only', r[hW].kind, 'wild')
eq('debuffed wild in hand uses base suit', r[hWd].kind..'/'..r[hWd].suit, 'normal/Diamonds')
eq('debuffed wild in hand exact: K♦ + active wild', r[hWd].b, 2)
eq('stone in hand shows stone count', r[hS].kind..'/'..r[hS].a, 'stone/2')
jokers = {'Smeared Joker'}
r = POV.compute(hand, deck)
eq('smeared: K hearts exact counts K♦ too', r[hK].b, 4)
eq('smeared: K spades exact counts both wilds + nothing red', r[hKs].b, 2)
jokers = {}
-- full recount path with UI mocks
G.hand = {cards = hand}; G.deck = {cards = deck, T={h=1.4,w=1}}
POV.recount()
eq('pills built for normal card', hK.children.pov_pills ~= nil, true)
local row = hK.children.pov_pills.args.definition.nodes[1].nodes
eq('normal card has two pills + spacer', #row, 3)
local spade_col = hKs.children.pov_pills.args.definition.nodes[1].nodes[3].nodes[1].config.colour
eq('spade exact pill is lightened, no outline', spade_col[1] > G.C.SO_2.Spades[1] and spade_col[3] > G.C.SO_2.Spades[3], true)
local zero = C('Ace','Hearts'); G.hand.cards = {zero}; POV.recount()
eq('zero exact hidden: one pill', #zero.children.pov_pills.args.definition.nodes[1].nodes, 1)
eq('cards that left hand lose pills', hK.children.pov_pills, nil)
POV.config.show_zero_exact = true; POV.recount()
eq('show zero exact: two pills', #zero.children.pov_pills.args.definition.nodes[1].nodes, 3)
POV.config.show_zero_exact = false
-- leaving the hand drops pills at once
G.hand = CardArea(); G.hand.cards = {zero}; G.deck = {cards = deck, T={h=1.4,w=1}}; POV.dirty = false; POV.recount()
G.hand:remove_card(zero)
eq('card removed from hand loses pills immediately', zero.children.pov_pills, nil)
G.hand.cards = {zero}; POV.recount()
-- stale hiding
POV.mark_dirty(); eq('stale counts stay visible by default', POV.stale_hidden(), false)
POV.config.hide_stale = true; eq('hide stale option hides while dirty', POV.stale_hidden(), true)
POV.recount(); eq('visible again after recount', POV.stale_hidden(), false)
POV.config.hide_stale = false
G.STATE = G.STATES.SMODS_BOOSTER_OPENED; G.E_MANAGER.queues.base = {1}; POV.update()
eq('opening a pack hides stale counts', POV.stale_hidden(), true)
G.E_MANAGER.queues.base = {}; POV.update(); G.TIMERS.REAL = G.TIMERS.REAL + 0.31; POV.update()
eq('pack counts shown after recount', POV.stale_hidden(), false)
G.STATE = G.STATES.SELECTING_HAND
-- recount timing: 0.3s of stillness, never during scoring
G.STATES.HAND_PLAYED = 5; G.STATES.DRAW_TO_HAND = 6
POV.mark_dirty(); POV.update(); G.TIMERS.REAL = G.TIMERS.REAL + 0.1; POV.update()
eq('not yet recounted after 0.1s still', POV.dirty, true)
G.TIMERS.REAL = G.TIMERS.REAL + 0.06; POV.update()
eq('recounts after 0.15s still', POV.dirty, false)
G.STATE = G.STATES.HAND_PLAYED; POV.mark_dirty(); POV.config.hide_stale = true
for i = 1, 50 do G.TIMERS.REAL = G.TIMERS.REAL + 0.1; POV.update() end
eq('no recount while scoring, even after 5s', POV.dirty, true)
eq('stale counts hidden while scoring', POV.stale_hidden(), true)
G.STATE = G.STATES.SELECTING_HAND; POV.update(); G.TIMERS.REAL = G.TIMERS.REAL + 0.31; POV.update()
eq('recounts 0.15s after scoring ends', POV.dirty, false)
POV.config.hide_stale = false
zero.VT = {x=5, y=0}; zero.T = {x=0, y=0}; POV.mark_dirty()
G.TIMERS.REAL = G.TIMERS.REAL + 1; POV.update()
eq('waits while a card is still moving', POV.dirty, true)
G.TIMERS.REAL = G.TIMERS.REAL + 2.5; POV.update()
eq('safety recount by 3s', POV.dirty, false)
zero.VT = nil
eq('mod icon atlas registered', SMODS.last_atlas and SMODS.last_atlas.key, 'modicon')
-- cutoff
local big = {} for i=1,18 do big[i] = C('3','Clubs') end
G.hand.cards = big; POV.update(); eq('cutoff hides above 17', POV.active(), false)
G.hand.cards = {zero}; POV.update(); eq('comes back as soon as hand is under the cutoff', POV.active(), true)
-- palettes and positions
G.C.SO_1 = {Spades={0.25,0.22,0.58,1}, Hearts={0.94,0.2,0.4,1}}; G.C.SUITS = G.C.SO_1
local pk = C('King','Hearts'); G.hand.cards = {pk}; G.deck.cards = {C('King','Hearts')}
POV.config.palette = 3; POV.recount()
eq('Standard uses SO_1 colours', pk.children.pov_pills.args.definition.nodes[1].nodes[3].nodes[1].config.colour, G.C.SO_1.Hearts)
POV.config.palette = 1; POV.recount()
eq('High Contrast uses SO_2 colours', pk.children.pov_pills.args.definition.nodes[1].nodes[3].nodes[1].config.colour, G.C.SO_2.Hearts)
POV.config.pill_position = 1; POV.recount(); eq('directly above sits above the card', pk.children.pov_pills.align.offset.y < -0.7, true)
POV.config.pill_position = 2; POV.recount(); local y2 = pk.children.pov_pills.align.offset.y
eq('top of card sits inside the top half', y2 < 0 and y2 > -0.7, true)
POV.config.pill_position = 3; POV.recount(); local y3 = pk.children.pov_pills.align.offset.y
eq('bottom of card sits inside the bottom half', y3 > 0 and y3 < 0.7, true)
POV.config.pill_position = 1
-- suit counter
local sl = POV.count_suits(deck)
local function find(list, suit) for _, e in ipairs(list) do if e.suit == suit then return e.n end end end
eq('suit list order starts with Spades', sl[1].suit, 'Spades')
eq('hearts counted by base suit, stones left out', find(sl, 'Hearts'), 3)
eq('wild counted under its own base suit', find(sl, 'Spades'), 1)
local full = {C('2','Diamonds')}
eq('suit in full deck but none left shows 0', find(POV.count_suits({}, full), 'Diamonds'), 0)
G.hand.cards = {C('King','Hearts')}; G.deck.cards = deck; G.STATE = G.STATES.SELECTING_HAND
POV.recount(); POV.update_deck_box()
local rows = POV.deck_box.args.definition.nodes[1].nodes
eq('deck box: 4 suit rows + stones row', #rows, 5)
eq('stones row is last', rows[5].nodes[1].nodes[1].config.text, 'Stones: 2')
eq('above the deck sits above', POV.deck_box.align.offset.y < 0, true)
POV.config.counter_position = 2; POV.update_deck_box()
eq('left of deck sits left', POV.deck_box.align.offset.x < 0, true)
eq('left of deck sits a little below the deck bottom', math.abs(POV.deck_box.align.offset.y - (1.4/2 - 0.3/2 + POV.LEFT_DROP)) < 1e-9, true)
POV.config.counter_position = 1
POV.config.suit_counter = false; POV.update_deck_box()
eq('suit counter can be turned off', #POV.deck_box.args.definition.nodes[1].nodes, 1)
POV.config.stone_counter = false; POV.update_deck_box()
eq('both off removes the box', POV.deck_box, nil)
POV.config.suit_counter = true; POV.config.stone_counter = true
-- config tab builds
eq('config tab builds', type(POV.mod.config_tab()), 'table')
local tabs = POV.mod.extra_tabs()
eq('two extra tabs', #tabs, 2)
eq('extra tabs build', type(tabs[1].tab_definition_function()) == 'table' and type(tabs[2].tab_definition_function()) == 'table', true)
local seen = {}
local function walk(n) if type(n) ~= 'table' then return end
  if n.toggle then seen[n.toggle.ref_value] = true end
  if n.cycle then seen[n.cycle.opt_callback] = true end
  for _, c in pairs(n.nodes or {}) do walk(c) end end
walk(POV.mod.config_tab()); walk(tabs[1].tab_definition_function()); walk(tabs[2].tab_definition_function())
local keys = {'enabled','show_in_packs','hide_stale','cutoff_on','show_zero_exact','suit_counter','stone_counter'}
local cycles = {'opacity','text_size','pill_position','palette','pill_order','cutoff','counter_position'}
local missing = 0
for _, k in ipairs(keys) do if not seen[k] then missing = missing + 1; print('missing toggle '..k) end end
for _, k in ipairs(cycles) do if not seen['pov_cycle_'..k] then missing = missing + 1; print('missing cycle '..k) end end
eq('every option is on some tab', missing, 0)
print(fails == 0 and 'ALL PASSED' or (fails..' FAILED'))
