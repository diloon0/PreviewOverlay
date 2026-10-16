-- Minimal mocks of the game so main.lua loads and POV.compute can be tested.
local function class()
  local c = {}; c.__index = c
  setmetatable(c, {__call = function(cls, ...) local o = setmetatable({}, cls); if o.init then o:init(...) end; return o end})
  return c
end
G = { C = { BLACK={0,0,0,1}, WHITE={1,1,1,1}, CLEAR={0,0,0,0}, RED={1,0,0,1}, UI={TEXT_LIGHT={1,1,1,1}},
      SO_2={Spades={0.3,0.2,0.7,1}, Hearts={1,0,0,1}, Clubs={0,0.5,1,1}, Diamonds={1,0.6,0,1}}, SUITS={} },
      UIT = {ROOT=0,R=1,C=2,T=3,B=4}, STATES = {SELECTING_HAND=1, SMODS_BOOSTER_OPENED=99}, FUNCS = {},
      TIMERS = {REAL=0}, E_MANAGER = {queues={base={}}}, I = {UIBOX={}}, GAME = {round=1}, STATE = 1 }
P_CENTERS = {}
G.P_CENTERS = P_CENTERS
jokers = {}
function find_joker(name) local r = {} for _, j in ipairs(jokers) do if j == name and true then r[#r+1]=j end end return r end
SMODS = { current_mod = { config = dofile(arg_config) } }
function SMODS.Atlas(t) SMODS.last_atlas = t end
function SMODS.get_enhancements(card) local t = {}; if card.config.center.key ~= 'c_base' then t[card.config.center.key]=true end; return t end
P_CENTERS.m_stone = {}; P_CENTERS.m_wild = {}; P_CENTERS.m_bonus = {}
function SMODS.has_enhancement(card, key) return card.config.center.key == key end
function SMODS.has_no_suit(card) local s,w=false,false for k in pairs(SMODS.get_enhancements(card)) do if k=='m_stone' or P_CENTERS[k].no_suit then s=true end if k=='m_wild' or P_CENTERS[k].any_suit then w=true end end return s and not w end
function SMODS.has_any_suit(card) for k in pairs(SMODS.get_enhancements(card)) do if k=='m_wild' or P_CENTERS[k].any_suit then return true end end end
function SMODS.has_no_rank(card) for k in pairs(SMODS.get_enhancements(card)) do if k=='m_stone' or P_CENTERS[k].no_rank then return true end end end
function adjust_alpha(c, a) return {c[1],c[2],c[3],a} end
function darken(c) return c end
UIElement = class(); function UIElement:draw_self() end
CardArea = class(); function CardArea:draw() end; function CardArea:emplace() end; function CardArea:remove_card() end
Card = class()
function Card:init(rank, suit, enh, debuff) self.base={value=rank, suit=suit}; self.config={center={key=enh or 'c_base'}}; self.debuff=debuff; self.children={}; self.T={h=1.4}; self.facing='front' end
-- Vanilla flush_calc branch of Card:is_suit, as patched by Steamodded's enhancement.toml.
function Card:is_suit(suit, bypass_debuff, flush_calc)
  if flush_calc then
    if SMODS.has_no_suit(self) then return false end
    if SMODS.has_any_suit(self) and not self.debuff then return true end
    if next(find_joker('Smeared Joker')) and (self.base.suit == 'Hearts' or self.base.suit == 'Diamonds') == (suit == 'Hearts' or suit == 'Diamonds') then return true end
    return self.base.suit == suit
  end
end
for _, n in ipairs{'set_base','set_ability','add_to_deck','remove_from_deck','remove','set_debuff'} do Card[n] = function() end end
Game = class(); function Game:update() end
function end_round() end
local boxes = 0
UIBox = class()
function UIBox:init(args) boxes = boxes + 1; self.T={h=0.3,w=1}; self.states={visible=true}; self.args=args end
function UIBox:set_alignment(a) self.align=a end
function UIBox:remove() self.removed=true end
function UIBox:draw() end
function create_toggle(a) return {toggle=a} end
function create_option_cycle(a) return {cycle=a} end
