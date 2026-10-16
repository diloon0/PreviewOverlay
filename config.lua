return {
    enabled = true,
    opacity = 4,          -- index into POV.OPACITY (80%)
    stone_counter = true,
    suit_counter = true,
    counter_position = 1, -- 1 = above the deck, 2 = left of deck
    palette = 1,          -- 1 = High Contrast, 2 = game's own setting, 3 = Standard
    pill_order = 1,       -- 1 = rank total first, 2 = exact match first
    cutoff_on = true,
    cutoff = 10,          -- index into POV.CUTOFFS (17 cards)
    text_size = 2,        -- index into POV.TEXT_SCALE (medium)
    pill_position = 1,    -- 1 = directly above, 2 = top of card, 3 = bottom of card
    show_in_packs = true,
    show_zero_exact = false,
    hide_stale = false,   -- hide counts while waiting for a recount
}
