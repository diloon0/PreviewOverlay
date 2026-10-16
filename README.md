# Preview Overlay

A display-only Balatro mod by **Omen**. It puts two small counts above every card in your hand, so you don't have to keep opening Deck Preview:

- **White number:** cards of the same rank still in your draw pile.
- **Coloured number:** cards of the same rank *and* suit still in your draw pile, in that suit's colour.

It also adds a per-suit counter and a Stone card counter next to the deck. Nothing about gameplay changes.

## Requirements

- [Lovely](https://github.com/ethangreen-dev/lovely-injector) v0.9.0 or newer
- [Steamodded](https://github.com/Steamodded/smods) 1.0.0-beta-1620a or newer

## Install

1. Download this repository (green **Code** button, then **Download ZIP**), or grab the zip from Releases.
2. Unzip it into `%AppData%\Balatro\Mods\` so the folder contains `main.lua` and `PreviewOverlay.json`.
3. Start Balatro. "Preview Overlay" appears in the Mods menu.

## How it counts

- "Remaining" means cards still in your draw pile; cards in your hand are never counted.
- Stone cards never count toward a rank or suit. A Stone card in hand shows one pill: the number of Stone cards left.
- Wild cards in the draw pile count as every suit for the exact-match number. A debuffed Wild counts only as its printed suit.
- A Wild card in hand shows only the rank count. A debuffed Wild in hand shows both, using its printed suit.
- With Smeared Joker, Hearts and Diamonds count as one suit, and so do Spades and Clubs.
- The suit counter counts each card once, under its printed suit, and leaves Stone cards out.
- Counts update a moment after cards stop moving, never mid-animation or while a hand is scoring.
- The overlay also shows on cards drawn in Arcana and Spectral packs.

## Options

**Config:** Overlay on, Show in packs, Hide stale counts, Hand-size cutoff and Cutoff above (hides the overlay while your hand is larger than the cutoff; 17 by default).

**Pills:** Background opacity, Text size, Pill position (Directly above, Top of card, Bottom of card), Colors for exact match (High Contrast, Game setting, Standard), Pill order, Show zero exact count.

**Deck counters:** Suit counter, Stone counter, Position (Above the deck, Left of deck).

## Multiplayer

The Balatro Multiplayer mod checks client mod lists, so using this in ranked play needs approval from the community moderators.

## Development

`dev/tests/test.lua` checks the counting and display rules against mocked game objects (run with Python's `lupa`). `dev/icon-source.py` draws the raven mod icon.

## License

Public domain under [the Unlicense](LICENSE). Use, copy, change, or share it however you like.
