# Square / pixel-depth aura borders — research notes

Status: **not started**. This is a pre-implementation research doc for a feature
the user wants to pick up later ("this weekend") — a "playground" for a new
border style, starting with Player buffs/debuffs. Read this before touching
border code so you don't re-derive what's already confirmed below.

## The ask

An option to replace the current aura border with a **square border of
customizable pixel depth** (default suggested: 2px), starting scoped to
**Player buffs/debuffs only** (`core/buffsandauras.lua`). Two hard
requirements from the user:

1. It must be a literal fixed pixel thickness, not a graphic that scales
   proportionally with icon size (that's what the *existing* atlas-based
   border already does — see below).
2. It must be able to carry **real dispel-type coloring** (magic/curse/
   poison/disease colors on debuffs, same as Blizzard's own). The user was
   explicit: *"if you cannot use it for the debuff border coloring than this
   is not something I want to pursue."* This has been confirmed possible —
   see "Dispel coloring" below.

## Current state (as of this doc)

`buffsandauras.lua:StyleAuraButton` (drives Player's Dark Border/Both aura
style) creates one overlay `Frame` per aura button holding a single
`Texture`, atlas `ui-debuff-border-default-noicon`, desaturated, then
`:SetVertexColor()`'d with the global darken color (`uuidb.general.darkencolor`)
— **the same tint for every buff/debuff/temp-enchant**, with only a
stealable-buff-is-white special case.

Two things worth knowing before you touch this:

- **It is not actually dispel-type colored today.** The code already detects
  the debuff's dispel type (`dtype`/`isTypeless` locals inside `GetAuraInfo`)
  but never uses the result for anything — dead code left over from an
  earlier pass. Party frames (`partyframes.lua`) *do* have real dispel
  coloring via `AuraUtil.SetAuraBorderColor(button.DebuffBorder, dispelName)`.
  Player/Target's shared border here doesn't, currently.
- **The atlas isn't a true fixed-pixel border.** `ui-debuff-border-default-noicon`
  is a pre-baked graphic stretched to fit; its visual thickness scales with
  icon size via the `SetPoint` offsets (proportional padding, currently a
  `width * (N/30)` ratio — see `core/cooldownmanager.lua`'s `GetBorderPad` for
  the most recently-tuned version of this ratio, `3/30`, floor 1px, as of
  this doc), not a constant N px regardless of size.

`core/cooldownmanager.lua` was very recently (this same checkpoint) migrated
from a borrowed action-bar-button atlas to this same `ui-debuff-border-default-noicon`
approach, for consistency with the rest of the addon. It is **not** the
new square-pixel system described below — it's the same old proportional
atlas approach, just using the shared atlas instead of a borrowed one. Once
a real pixel-depth border module exists, Cooldown Manager is a good second
candidate to migrate onto it (its icons are small and tightly packed, so a
literal fixed-px border may look better than the current proportional one —
worth eyeballing once the module exists).

## How to build the square border (confirmed feasible)

A custom border of N literal pixels, independent of icon size, is a
completely standard pattern (this is how ElvUI/WeakAuras pixel borders
work): 4 thin solid-color `Texture` regions (top/bottom/left/right strips),
or one texture inset by exactly N px on each side via `SetPoint` offsets
using a fixed pixel constant instead of a proportional formula. No protected
or secure APIs are involved — this is a plain overlay frame/texture we fully
own, same as the existing border frame. Nothing here conflicts with
[[feedback-no-direct-blizzard-calls]] since we're not calling any Blizzard
update function, just drawing our own overlay.

## Dispel coloring (confirmed possible)

`AuraUtil.SetAuraBorderColor(borderRegion, dispelType)` —
`Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua:614` in the
`wow-ui-source` mirror — is a **generic** function:

```lua
function AuraUtil.SetAuraBorderColor(borderRegion, dispelType)
    borderRegion:SetVertexColor(AuraUtil.GetAuraBorderColor(dispelType):GetRGBA());
end
```

It just calls `:SetVertexColor()` on whatever texture region you pass it —
it is **not** restricted to Blizzard's own `DebuffBorder` object. This means
we can call this exact Blizzard function directly on our own custom
pixel-border texture(s), using the same colors Blizzard/Party already use,
finally giving Player (and Target, if extended) real per-dispel-type
coloring — something that doesn't exist there today (see above). Confirmed
by reading the function body directly; not an assumption.

## Proposed v1 scope

1. Build a shared helper (e.g. `BuildPixelBorder(icon, thicknessPx)`) that
   returns a border object with a `:SetColor(r,g,b,a)` method, backed by
   either the 4-strip or inset-texture approach above.
2. Add it as a new aura style option scoped to Player buffs/debuffs only
   (new dropdown value or a separate toggle + pixel-depth slider, default
   2px, per the user's suggestion).
3. Wire dispel coloring through `AuraUtil.SetAuraBorderColor` on debuffs,
   same call Party already makes, just pointed at the new border texture(s)
   instead of Blizzard's `DebuffBorder`.
4. Once proven out on Player, candidates for later reuse: Target/Focus/Party/
   Boss (their own border styling) and Cooldown Manager (see note above).

No code has been written for this yet. Nothing in `buffsandauras.lua` should
be assumed to already support this — the border/tint logic there is the
*old* atlas-based system, described above for contrast.

## Open question to investigate (reported, not yet understood)

User observation (2026-09-25), on `core/cooldownmanager.lua`'s current
(non-pixel, atlas-based) borders: *"the cooldown bars icon border is changing
based on the color, was that there before?"* — i.e. the border's apparent
color seems to vary per icon rather than being one uniform tint. Our own code
sets the exact same `uuidb.general.darkencolor` vertex color on every border
(`cdManager:Color()` in `core/cooldownmanager.lua`), so if this is real, it's
either: (a) something that predates this checkpoint's atlas swap and was
already true with the old borrowed action-bar atlas, or (b) an interaction
between our `SetDesaturated(true)` + `SetVertexColor()` overlay and some
other Blizzard-drawn layer on the same icon (e.g. Cooldown Viewer's own
built-in importance/quality highlight border, if it draws one) showing
through or blending with ours. Not reproduced or root-caused yet — needs
in-game observation (screenshot with a couple of differently-colored icons
side by side, and check whether toggling `uuidb.cooldown.borders` off removes
the effect entirely) before deciding whether it's our bug or a pre-existing
Blizzard layer we're not accounting for.
