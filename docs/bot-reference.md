# MiniTrinketGlow - bot reference

Version 1.1.7. Interface versions: 120100, 50504, 40402, 38002, 38000,
30405, 20506, 11509 (retail plus the classic client lines). Saved
variables: MiniTrinketGlowDB (account-wide).
Bundles LibStub and LibCustomGlow-1.0.

## What it does

Puts a proc-style glow on action bar buttons that hold your equipped
trinkets whenever the trinket is off cooldown, so you can see at a glance
that a PvP or on-use trinket is ready.

## How it detects trinket buttons

Scans buttons 1-12 on the default Blizzard bars: ActionButton,
MultiBarBottomLeftButton, MultiBarBottomRightButton, MultiBarRightButton,
MultiBarLeftButton, MultiBar5Button, MultiBar6Button, MultiBar7Button.
A button counts as a trinket button when either:

- It holds the item currently equipped in trinket slot 13 or 14, or
- It holds a macro whose body contains a "/use" line referencing slot 13 or
  14, e.g. "/use 13", "/use [combat] 14", "/use [mod:shift,@player]13".
  Word boundaries are respected, so "/use 130" does not match slot 13.

Custom action bar addons (Bartender, Dominos, ElvUI bars, etc.) are not
scanned; only the default Blizzard buttons are supported. Pet bar buttons
are not scanned.

## When it glows

The glow shows when the trinket's inventory cooldown reports it usable with
no cooldown running, and (if "Combat only" is on) you are in combat. When you
use a trinket the addon schedules a re-check for just after the cooldown
ends, so the glow returns as soon as the trinket is ready. Passive trinkets
that the game does not report as usable do not glow.

A glow is cleared when the button stops holding a trinket, whether because the
trinket was unequipped, the action was dragged away, or the bar paged to
something else.

The glow itself is LibCustomGlow's proc glow. If LibCustomGlow is somehow
unavailable it falls back to the Blizzard action button overlay glow.

## Settings

Open with a slash command or Options -> AddOns -> MiniTrinketGlow.

| Setting | Type | Default | Effect |
|---|---|---|---|
| Combat only | checkbox | on | Only glow while in combat. |

## Slash commands

/minitrinketglow, /minitg, /mtg - all open the settings panel.

## Troubleshooting

- "My trinket never glows": most common cause is the default "Combat only"
  setting; out of combat there is no glow until you turn that off. Also check
  the trinket sits on a default Blizzard action bar, either directly or via a
  "/use 13" / "/use 14" macro.
- "It glows out of combat and I don't want that": turn "Combat only" back on.
- "My passive stat trinket doesn't glow": intended; only trinkets the game
  reports as usable glow.
- "I use Bartender/Dominos": unsupported; the addon only scans the default
  Blizzard button names.
