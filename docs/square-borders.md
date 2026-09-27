# Square / pixel-depth aura borders — research notes

Status: **implemented for every aura location, untested in game.**

**Player debuffs in combat -- fixed by moving them into our own container**
(`core/playerdebuffs.lua`, untested in game). Player auras are Blizzard's own
BuffFrame/DebuffFrame buttons styled from outside, and in combat every route
to a player debuff's dispel color is closed to addon code (instance ID and
dispel type are secret; `GetUnitAuraInstanceIDs` is refused while tainted;
confirmed with `/uuidebugplayerdebuffs`), so square Player debuff borders
used to fall back to the "None" red in combat. Now, while Player auras use
**square** borders (and Player debuffs aren't set to "None"), Player
debuffs are shown in an aurakit `CustomAuraContainer` (unit
`PlayerFrame.unit`, `squareLoc = "player"`), where the engine colors the
square strips like Target/Focus. Buffs and weapon enchants stay on
Blizzard's BuffFrame. Rounded + Dispel Color keeps Blizzard's own debuff
buttons and shows Blizzard's own `DebuffBorder` (set by Blizzard's code), so
it is also correct in combat (see "Rounded + Dispel Color" below).

How the container mirrors Blizzard's DebuffFrame (same code on retail 12.1
and Forever 1.60.1 -- checked in `wow-ui-source` `origin/live` /
`origin/forever`, `Blizzard_BuffFrame/BuffFrame.lua`):

- **Which auras:** every `HARMFUL` aura, unfiltered, like
  `DebuffFrameMixin:UpdateAuras` (`AuraUtil.ForEachAura(PlayerFrame.unit,
  "HARMFUL", maxAuras)`). Sorted `AuraInstanceIDOnly` (application order,
  approximating Blizzard's slot order). Max `DEBUFF_MAX_DISPLAY` (16) + 6
  private slots. Private (boss) auras come through the container itself, so
  Blizzard's six `DebuffFrame.PrivateAuraAnchors` (direct children of
  DebuffFrame, not of its AuraContainer) are hidden along with
  `DebuffFrame.AuraContainer`.
- **Edit Mode settings:** all land as fields on `DebuffFrame.AuraContainer`
  (`EditModeAuraFrameSystemMixin`): `isHorizontal`, `addIconsToRight`,
  `addIconsToTop`, `iconStride` (icon limit = icons per row), `iconScale`
  (icon size %), `iconPadding`. Re-read after every `UpdateGridLayout`
  (instance hook) and mapped to flow axis / anchor corner / growth
  direction / max line size / container `SetScale`. Visibility (Always / In
  Combat / Hidden) and opacity apply to `DebuffFrame` itself -- our
  container's parent -- so they carry over, as does position.
- **Look:** 30x30 icon filling the button; Blizzard's 30x40 / 60x30 cells
  become the line gap past the icon (padding + 10 horizontal, + 30
  vertical) where the duration text sits on Blizzard's side of the icon.
  Duration via the engine's `SetDurationText` with a step color curve
  (white under `BUFF_DURATION_WARNING_TIME`, yellow above), hidden with the
  `buffDurations` CVar, pushed out by an outset border's thickness. Count in
  `NumberFontNormal` at (-2, 2). No cooldown swipe (`ClearDurationCooldown`).
- **Edit Mode open:** Blizzard's container is shown instead (its preview
  icons need it); ours comes back on exit (`SetIsEditing` hook).
- **Not mirrored:** the low-time flash (`BUFF_WARNING_TIME`), Edit Mode's
  "Show Dispel Type" symbol (only swaps `-noicon` for `-icon` border art;
  colors are identical, and square borders have no symbol slot), Forever's
  gamepad navigation of DebuffFrame buttons. The deadly-debuff center
  alert (`DeadlyDebuffFrame`) is separate and keeps working.
- Hooks on Blizzard frames install only once the feature is on, and their
  work is deferred a frame (`C_Timer.After(0)`, coalesced). The container is
  built out of combat only; if square borders get turned on mid-combat,
  Blizzard's debuffs keep showing until combat ends.

**Sizing rules (2026-09-26):**
- Dispel-colored borders -- debuff dispel type and purgeable/stealable buffs
  -- are drawn **1px thicker** than the plain dark border
  (`squareborders.DispelThickness` / `LayoutDispelFor`), matching
  EllesmereUI (1px border, 2px dispel ring). Applied in aurakit (Target,
  Focus, Boss, Compact, Player debuff container), Party, and Player's
  Blizzard-button path; outset duration-text pushes use the same thickness.
- With square borders on for a location, aurakit icons **fill their button**
  instead of the 1px inset kept for the round border (which cost 2px of
  every icon). Target "other" auras went 16 -> 17 and Focus 17/13 -> 21/17
  to match Blizzard's `TargetFrameAuraContainerDefaults` (21 mine / 17
  other; Focus containers inherit FocusFrame's 0.75x small-focus scale).

Settings model (options/helpers.lua `AddAuraOptions`): per location, Zoom
Icons (checkbox), Buff Border (Dark / None), Debuff Border (Dark / Dispel
Color), Border Shape (Rounded / Square), Border Thickness, Border Position
(Inside / Outside Icon). These are presentation only: zoom + dark border
are still stored as the original `aurastyle_<loc>buffs|debuffs` strings
(both = zoom+dark, border = dark, zoom = zoom only, none = neither, i.e.
handed back to Blizzard), and shape/position as the boolean
`squareauraborders_*` keys -- no migration. The Debuff Border choice is
honored in square mode too (Dark = dark square); earlier versions forced
dispel color on square debuffs.

All Auras (main page, `opt.AddAllAurasOptions` / `opt.ApplyAuraParts`):
six one-shot action dropdowns (same choices as a location's controls).
Picking a value immediately COPIES that one part into every location's own
keys and refreshes them, then the dropdown snaps back to "Set All...".
Nothing is stored and no code path ever reads these again -- deliberately
not a live override; each location stays editable afterwards.

Rounded + Dispel Color shows **Blizzard's own per-type border art** (changed
2026-09-27). It used to draw our ring (desaturated
`ui-debuff-border-default-noicon`) tinted with the dispel color, but that
ring art is painted red -- sampled `UI-Debuff-Border.blp`: avg RGB
(124, 34, 31) -- so desaturated it's only ~24% bright and every tint came out
dark. Vertex color can only darken, so no tint fixes that; the per-type art is
already full-brightness in each color. Target/Focus/Boss/Compact: the
engine-picked `dispelBorderTex` (style `Border`) is preferred;
`roundDispelTex` (`PreserveAsset`) stays registered only as a fallback if the
per-type art never registers. Player (Blizzard's buttons): Zoom Only falls
through to re-showing Blizzard's own `DebuffBorder`, which Blizzard's code
sets per type -- correct in combat too. Dark borders still use the
desaturated ring tinted with the darkness color (dark is the intent there).
Party and the Arena CC tracker already use Blizzard's own ring natively, so
they're unchanged.

v2 (all locations): shared module `core/squareborders.lua` (border object,
whole-pixel layout, per-location settings `squareauraborders_<loc>` /
`_thickness` / `_inset`, dispel coloring). Each location has its own
toggle/thickness/inset rows in its own settings section.

- Player (`buffsandauras.lua`): see v1 notes below; keeps the original keys.
- Target/Focus/Boss/Compact (`aurakit.ApplySquareBorder`, `opts.squareLoc`):
  the edge strips are registered with the button's `AddDispelTypeTexture`
  (a list, so extra textures are fine) -- debuffs with `PreserveAsset` (the
  engine applies the real dispel color to our solid strip, secret-safe),
  buffs' Show Dispels border with `CustomAsset` + a WHITE8X8 asset map +
  `stealableFilter`. Registered at button init alongside the round dispel
  border (hidden until on), so toggling needs no aura update. Round border
  stays as the fallback until registration succeeds.
- Party (`partyframes.lua`): own strips, colored via
  `GetAuraDispelTypeColor` curve from the button's auraInstanceID.
- Arena (`arenaframes.lua`): trackers have no dispel type -- dark square in
  border styles, else native red on the CC tracker / none on DR icons; the
  CC tracker's native Border is alpha'd out, not hidden.

v1 notes (Player only) follow.
Opt-in via Options → Uber UI (main page) → Aura Borders → "Square Aura
Borders" (`uuidb.general.squareauraborders_player`, default off; lives on
the main page because it's meant to grow to every frame) + "Square Border
Thickness" slider (`squareauraborders_thickness`, 1–8 px, default 2) and
"Inset Square Border" toggle, both greyed out while it's off. Code
lives at the top of `core/buffsandauras.lua` (`GetSquareBorder`,
`LayoutSquareBorder`, `ApplyDebuffDispelColor`) and is used from
`StyleAuraButton` when the aura style includes a border.

Implementation notes (what v1 actually does, vs. the research below):

- 4 solid `SetColorTexture` edge strips, *inset* over the icon's outer edge
  by default (user preference: keeps the button's footprint) or outside it
  via the "Inset Square Border" toggle (`squareauraborders_inset`), sized in
  physical pixels via `PixelUtil.GetPixelToUIUnitFactor() / effectiveScale`.
- Dispel coloring: non-secret `dispelName` → `AuraUtil.GetAuraBorderColor`
  (Blizzard's colors). **Secret** dispel type (12.x combat restrictions) →
  `C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, curve)` with a
  Step `C_CurveUtil` color curve keyed by engine dispel IDs (0 none, 1 Magic,
  2 Curse, 3 Disease, 4 Poison, 9 Enrage, 11 Bleed) and valued with the same
  AuraUtil colors; result goes straight into `SetVertexColor` (secret-safe,
  same pattern as `Blizzard_CustomAuraButton.lua`). Player debuff buttons
  only carry `buttonInfo.index`, so the instance ID is resolved via
  `C_UnitAuras.GetAuraDataByIndex(PlayerFrame.unit, index, "HARMFUL")`.
  `AuraUtil.SetAuraBorderColor` below can't be used directly with a secret
  dispel type (it indexes a table with it).
- Defaults mirror EllesmereUI's `PP.CreateBorder` (the reference design):
  inset (default now 2px by user preference; EllesmereUI uses 1px), thickness rounded to whole pixels (min 1),
  `SetSnapToPixelGrid(false)` + `SetTexelSnappingBias(0)` on the strips so a
  1px edge can't vanish, and a re-measure on `UI_SCALE_CHANGED` /
  `DISPLAY_SIZE_CHANGED`. EllesmereUI uses 2px only for its dispel ring.
- Outset mode pushes Blizzard's `Duration` text out by the border
  thickness (`OffsetDurationText`), along whichever icon edge Blizzard
  anchored it to (orientation-aware); absolute offset, restored to 0 when
  inset/off. Blizzard's layout pass re-anchors Duration right *after*
  `UpdateAuraButtons` (our styling hook), and BuffFrame/DebuffFrame call
  their own copied `AuraContainer:UpdateGridLayout` (created before we load,
  so the `AuraContainerMixin` hook never sees it) -- so the push is
  re-applied from instance hooks on those two containers
  (`EnsureSquareBorderLayoutHooks`, installed only once outset is in use).
- Player debuffs and temp enchants get the square border in Zoom Only style
  too (replacing Blizzard's rounded border, undarkened: dispel color for
  debuffs, `TEMP_ENCHANT_BORDER_COLOR` = (0.50, 0.22, 0.72) for enchants,
  sampled from the bright rim of Blizzard's `UI-TempEnchant-Border.blp` in
  the game dir's exported `_retail_\BlizzardInterfaceArt`, since that purple
  is baked into the texture rather than set as a color); buffs stay
  borderless in Zoom Only. "None" style is never overridden.
- Buffs/temp enchants keep the darkness color (stealable → white), same as
  the atlas border.

Original pre-implementation research follows.

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

Steps 1–3 are now done (see Status at top); step 4 (reuse on Target/Focus/
Party/Boss/Cooldown Manager) is still open.

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
