# HUD Design Research — Fire & Ice

Now I have enough research data to compile a comprehensive, actionable HUD design document. Let me synthesize everything into the detailed analysis and Fire & Ice specification.

---

# Aviation Game HUD Research: Detailed Analysis and Fire & Ice Design Specification

---

## Part 1: Tiny Combat Arena — HUD Research

### A. HUD Element Inventory

Tiny Combat Arena (developer Why485/Brian Hernandez, published MicroProse) uses a strictly cockpit-bound HUD philosophy: **no HUD elements appear in any external camera view**. All information is tied to the cockpit view, with the AV-8B Harrier as the primary (and initially only) flyable aircraft.

**Full element list (cockpit/HUD-glass layer):**

| Element | Position | Form | Notes |
|---|---|---|---|
| Airspeed tape (SPD KT) | Left side of HUD glass | Vertical ladder — tick mark + scrolling number | Units switchable: Authentic (knots for Harrier), Metric (kph), Imperial |
| Altitude / Altimeter | Right side of HUD glass | Vertical tape with numeric readout | Radar altimeter activates below 500 ft as a separate secondary readout |
| Nozzle angle indicator | Center-lower HUD | Chevron symbol + numeric text | Shows desired nozzle angle on chevron, true angle on bar — critical for VTOL |
| G-meter | Inner HUD cluster | Numeric text readout | |
| Throttle indicator | HUD cluster | Bar or numeric value | |
| Gun ammo counter | HUD lower area | Numeric | |
| DLZ Bar (Dynamic Launch Zone) | Right side of HUD | Vertical bar + sliding caret | Auto-ranges immediately on new range increment; shows time-to-impact for previously launched munitions |
| Flight Path Marker / Waterline | Center HUD | Circle with stub wings (aircraft-body symbol) | Optional — toggleable in settings |
| CCIP pipper (ground attack) | World-projected center | Crosshair dot with bomb fall line | Shows Total Velocity Vector, Bomb Fall Line, Impact Point dot, and "X" invalid solution warning |
| Gun pipper (air-to-air) | World-projected predictive | Lead pipper offset from target | Predictive: computes future intersection of target trajectory |
| Missile seeker aimpoint | Center/world space | Circle (seeker field-of-view) + inner dot (seeker aimpoint) | IR missiles show seeker looking direction; Sparrow shows Allowable Steering Error circle |
| Target name/type readout | Cockpit MFD area | Text — aircraft type + pilot skill | On lock acquisition |
| Radar / B-Scope display | Left MFD or dedicated HUD quadrant | B-Scope style (range vs. azimuth 2D display) | Limited field of view; range-auto-ranges at 80% of current increment; enemies shown as bars, friendlies as dots |
| TWD (Threat Warning Display) | Separate from radar | Circular or scope display | Chaff/flare counter overlaid; auto-ranges; icon size 75% default; can hide allies |
| Missile warning | TWD area + audio | Visual cue on TWD + audio tone | IR SAM warning triggers audio missile growl; incoming missile shown on TWD; separate audio levels for growl/tone |
| Fuel weight / fuel low warning | HUD cluster | Numeric (FuelWeight display) | Fuel low warning appears at below 20% fuel |
| Rearm notification | HUD — context | Text notification | Appears after rearming |
| Brake indicator | Lower HUD | Input-based indicator | Based on input, not brake state |
| Landing gear status lights | Cockpit dashboard | Physical 3D lights | Not HUD glass — part of modeled cockpit |

**Left MFD:** Electronic artificial horizon  
**Right MFD:** Electronic heading indicator  
**Both MFDs** also show nozzle angle (STOVL page), and were updated to respond to the Authentic/Metric/Imperial unit system.

**HUD instrument styles (v0.17+):** Three options — Borders, Transparent, Clear  
**Instrument placement:** 4:3, 16:9, or Screen Edge configurations

### B. Targeting and Weapon State UI

- **Ready-to-fire:** No explicit "ready" indicator for guns; DLZ caret reaching the thick section of the bar indicates missile in-range
- **Target lock:** Target name/type text appears in cockpit readout; radar flashes locked target; missile seeker circles track the locked target
- **Gun lead computing:** Dedicated predictive pipper separate from the nose crosshair — computes intersection point based on both aircraft velocities
- **CCIP:** Four-element display (velocity vector, bomb fall line, impact dot, invalid-X)
- **DLZ bar:** Vertical bar on right side; caret slides down as target approaches range; thick section = lock-on range; length varies by weapon; time-to-impact shown for in-flight munitions
- **Radar-guided missile (AIM7E):** Target Lead Indicator (where missile wants to go) + Allowable Steering Error circle
- **IR missile (AIM-9):** Seeker aimpoint dot + seeker field-of-view circle; audio feedback: "patient" tones = searching, "happy" tones = locked
- **Weapon switching:** Not described in detail, but targets detected by radar show monochromatic dot (friendly) or bar (enemy) overlaid in world space

### C. Threat Awareness UI

- **Radar:** B-Scope style (range vs. azimuth, not traditional circular plan-position indicator). Limited range and field of view — only detects what's within sensor cone. Targets at distance shown as monochromatic dots/bars overlaid on world.
- **TWD (Threat Warning Display):** Separate circular display from the radar. Shows incoming missile threats. Chaff/flare counter included. Auto-ranges. Icon size configurable. Allies hidden by default.
- **Missile warning:** Visual pulse on TWD + dedicated audio missile growl with separate volume control. Timing aid for countermeasure deployment.
- **Direction-of-threat:** Not explicitly described as having arrow indicators; TWD shows threat positions spatially.
- **Cockpit vs. external:** External views show zero HUD information — complete blackout.

### D. Flight State Indicators

- **Speed:** Vertical tape (airspeed ladder) on left side, tick mark + number format, scrolling as speed changes
- **Altitude:** Right side tape; radar altimeter supplements below 500 ft
- **Nozzle angle:** Separate dedicated element — chevron for desired angle, bar for true angle
- **G-meter:** Numeric display, part of cockpit HUD cluster
- **Stall:** Aircraft stalls dramatically below ~200 KT; stall audio/visual present (specific form not detailed in available sources)
- **Heading:** Right MFD shows heading indicator (electronic compass)

### E. Cockpit-Specific UI

- Two MFDs: Left = artificial horizon / Right = heading indicator (also switchable to STOVL nozzle page)
- Physical cockpit is fully modeled with animated stick, throttle, nozzle lever, pedals, gear lever, gear lights
- HUD glass overlay carries: speed tape, altitude tape, nozzle chevron, G-meter, DLZ bar, CCIP, lead pipper, seeker circles
- VR: Not present (flat-screen game)
- Cockpit locked to imperial units regardless of global HUD unit setting

### F. Third-Person Specific UI

- Zero HUD elements in third-person (external) views — developer's explicit design decision
- No targeting brackets, no radar, no weapon state in external view
- This is described as a conscious "simcade" philosophy: information is earned through cockpit use

### G. Score / Status / RPG Elements

- No score system visible mid-mission in the traditional sense
- Arena mode has strategic overlay (production values, unit positions) but this was placeholder
- Fuel weight shown as a combat-relevant resource
- No health bar — component damage model implied by aircraft behavior

### H. Minimal HUD / Immersive Options

- HUD can be resized (scale slider in gameplay settings)
- HUD mode: HDM (head-down mode, traditional) or Fixed Forward
- External views fully strip HUD
- Developer stated: "Fun Before Fidelity" — HUD elements are there to communicate what's happening, not to overwhelm
- Chaff/flare counter, ally display on TWD — all optional/toggleable

### I. Visual Design Language

- Color: Monochromatic/green-tinted HUD symbology (targets: dot/bar in monochrome)
- Style: Sparse, simulation-inspired sans-serif — not arcade styled
- Transparency: Three configurable opacity modes (Borders, Transparent, Clear)
- Animation: DLZ caret slides smoothly; missile seeker circles rotate/track; audio tones change state; radar auto-ranges with smooth scaling
- Clutter: Major community complaint — developer acknowledged and committed to context-sensitive display (NAV mode vs. combat mode)

---

## Part 2: Ace Combat 7: Skies Unknown — HUD Research

### A. HUD Element Inventory

Ace Combat 7 uses a green-dominant military HUD aesthetic with specific elements that remain consistent from earlier series entries.

**Full element list:**

| Element | Position | Form | Notes |
|---|---|---|---|
| Speed | Left side, upper HUD | Numeric (MPH or KPH) | No tape — plain number with label |
| Altitude | Right side, upper HUD | Numeric (feet or meters) | Convertible via options |
| Score | Upper center or upper right | Numeric text | Mission score, updates on kills |
| Time remaining | Upper area | Numeric countdown | MM:SS format |
| Target box | World-space, centered on target | Square bracket enclosure | White/yellow normally; red when in range; yellow for UNKNOWN targets |
| UNKNOWN target indicator | World-space overlay | Yellow square bracket outline | Must hold lock to resolve to green (ally) or blue (neutral/friendly) |
| Target arrow | Edge of screen | Arrow indicator | Points off-screen toward current target |
| Radar | Bottom-left | Circular plan-position display | Enemies appear as arrowhead shapes (show orientation/heading); flashing = current target; expandable to full mission map via touchpad |
| DLZ bar | Right side of targeting bracket or dedicated panel | Vertical bar + sliding caret | Caret moves down as target approaches; thick section = lock-on range; length varies by selected weapon |
| Missile/ammo count | HUD panel (side) | Numeric counter per weapon slot | Standard missiles (STDM) + special weapon (SP WPN) slots |
| Weapon name | HUD panel | Text label | Current selected weapon name displayed |
| Damage indicator | HUD area | General scale indicator | Vague "condition" display, not component-level |
| Gun reticle | Center, world-space | Crosshair circle | Appears when in gun range; accounts for lead |
| Red bar (missile warning) | Screen edge(s) | Bar/band, red color | Direction-of-threat from incoming missile |
| HUD flash | Full-screen overlay | Screen-wide red tint | On missile detection — "HUD turns red" |
| Stall warning | HUD center area | Text "STALL WARNING" | With aircraft shake haptics |
| Mission objective text | Top or top-center | Text label | Mission updates, target acquisition prompts |
| Ally status box | World-space | Large blue container around box | For allies needing escort/in danger |

**AC7-specific unique features:**
- Lightning strikes in storm clouds temporarily scramble the entire HUD (all elements corrupted/disabled temporarily)
- Cloud layer forces tactical navigation without full radar capability
- UNKNOWN targets cannot be identified immediately — must hold lock through yellow→green/blue resolution

### B. Targeting and Weapon State UI

- **Ready-to-fire (missiles):** Target bracket turns red; confirms you can fire; DLZ caret is in thick section
- **Target lock box:** Square bracket enclosure; white = acquired target; red = in range; yellow = UNKNOWN classification needed
- **Weapon selector:** Side panel showing weapon name + numeric count per slot (e.g., "STDM x64", "XASM-3 x12")
- **DLZ:** Vertical bar with sliding caret — the visual language is: caret at top = long range, caret in thick section = optimal, caret past = too close. Caret moves as target approaches.
- **Gun reticle:** Circle that appears when in gun range; compensates for lead
- **Switching weapons:** Weapon panel updates text and count immediately; DLZ bar length changes to reflect new weapon's characteristics
- **Special weapons:** Separate slot displayed alongside standard missiles; both tracked with separate counters

### C. Threat Awareness UI

- **Radar:** Bottom-left corner; circular PPI (Plan Position Indicator); enemies = arrowhead icons showing orientation; current locked target flashes; three zoom levels via touchpad
- **Missile warning visual:** Full-screen red HUD flash + directional red bar on screen edge showing incoming bearing
- **Missile warning audio:** Repeating alarm that increases in frequency as missile approaches
- **No dedicated RWR panel** with individual threat labels (unlike real aircraft or DCS); it's simplified to directional bar
- **Cockpit vs. external:** All HUD elements available in both cockpit and third-person view (unlike Tiny Combat Arena); cockpit instruments are decorative — no functional MFDs

### D. Flight State Indicators

- **Speed:** Number only (MPH/KPH), upper-left area
- **Altitude:** Number only (feet/meters), upper-right area
- **Heading:** Not explicitly described as a visible compass strip — may be absent or minimal
- **Stall:** Text "STALL WARNING" appears on HUD with aircraft shaking; required to be below 450 km/h + specific inputs to enter PSM (Post-Stall Maneuver)
- **PSM state:** Aircraft enters post-stall when conditions are met; no dedicated PSM energy bar visible — pilot infers from speed and aircraft behavior
- **G-force:** Not shown explicitly on HUD
- **Overspeed:** Not described

### E. Cockpit-Specific UI

- Three cockpit camera positions selectable via R3 (PS) / click-stick
- Cockpit instruments are purely visual decoration — the developer explicitly confirmed "the instruments in the cockpit are not actually useful but are there for looks"
- All information comes from the glass-overlay HUD, not the physical cockpit panel
- VR mode (PSVR): Cockpit view only; ammo, radar, flares, damage visible on HUD; indicators and gauges "move in real-time"; gun reticle limited in some VR implementations
- HUD cannot be selectively customized — it is all-on or all-off only

### F. Third-Person Specific UI

- Same HUD elements as cockpit view — no differentiation
- Targeting brackets in world-space, visible from external camera
- Camera does not roll with aircraft — stays level (standard Ace Combat convention)
- Waypoint markers appear as 3D world-space labels/arrows visible in both views

### G. Score / Status / RPG Elements

- Score displayed continuously mid-mission, upper area
- Mission timer countdown visible
- No energy bar, no PSM meter, no special ability gauge
- Damage is a single "condition" indicator — not component-level
- No resource management mid-mission

### H. Minimal HUD / Immersive Options

- HUD is binary: on or off (no granular control)
- With HUD off: radar disappears, making interception nearly impossible
- Community widely requested selective HUD element toggling — not implemented
- Mods exist that: recolor elements (20 presets including colorblind options), reorganize 3rd-person layout, change font and target containers/radar signatures, scale/move HUD frames

### I. Visual Design Language

- **Color:** Green-dominant (traditional military HUD phosphor green); enemies in red; allies in blue; UNKNOWN in yellow; in-range confirmation in red
- **Font:** Military monospace style, clean and angular
- **Transparency:** HUD elements are semi-transparent green overlays on world view
- **Background plates:** Minimal — elements float without strong background frames in standard HUD
- **Animation:** Target bracket flashes when locked; screen flashes red on missile warning; DLZ caret slides; STALL WARNING text appears/disappears
- **Combat vs. cruise:** No explicit element hiding during cruise — always-on

---

## Part 3: Crimson Skies (PC 2000) — HUD Research

### A. HUD Element Inventory

Crimson Skies PC (2000, Zipper Interactive) was an arcade-leaning flight combat game with detailed cockpit instrument descriptions in its manual, set in a pulp 1930s alternate history.

**Full element list:**

| Element | Position | Form | Notes |
|---|---|---|---|
| Compass | Cockpit instrument panel | Circular gauge — "Explorer 2000" gyromagnetically stabilized | Always shows true heading regardless of weather; fog/rain proof |
| Altimeter | Cockpit instrument panel | Dual-needle circular gauge — long needle = hundreds of feet, short = thousands | Low-altitude warning light flashes red below 100 ft |
| Speedometer | Cockpit instrument panel | Circular dial — "Whistler Delux" barometric indicator | Shows true airspeed in MPH; automatic stall-speed warning |
| Artificial Horizon | Cockpit instrument panel | Dual-gyroscope attitude indicator — "Dexter-Handly" unit | Shows pitch and bank |
| Targeting crosshair | World-space center | Fixed crosshair | Points where aircraft nose points |
| Lead crosshair | World-space, offset | Predictive crosshair | Accounts for aircraft velocity + roll — shows where bullets will fire |
| Target bracket | World-space | Bracket around target — red (enemy), green (friendly), blue (neutral) | Name displayed; directional arrows + text when target is off-screen |
| Gunnery display | HUD panel | Color-coded ammo counter — green (ample), yellow (running low), red (empty) | Per weapon, labeled "Browning HPX" style |
| Rocket display | HUD panel | Hardpoint status tracker | Auto-selects next available type when current depleted |
| Damage indicator | HUD area | Aircraft schematic divided into 4 zones: right wing, left wing, nose, tail | Color coded: green (0%), yellow (up to 50%), orange (50-100% armor), red (airframe damage 25-100%) — "Crispen Mark V" |
| Spyglass | Screen edge, target-relative | Magnified view of selected target, rolls around windshield edge | Arrow always points toward target; gyroscopically stabilized zoom view |

### B. Targeting and Weapon State UI

- **Two simultaneous crosshairs:** Targeting crosshair (nose direction) and Lead crosshair (actual bullet trajectory). This dual-sight system is explicitly described in the manual as the key targeting aid.
- **Target brackets:** Color-coded by allegiance. Off-screen targets: directional arrows + text label showing required orientation.
- **Spyglass:** Unique mechanic — magnified target view travels around the perimeter of the screen following target position
- **Ammo:** Color-coded counter (green→yellow→red progression)
- **Rocket hardpoints:** Tracked with individual readout; auto-switches to next available type

### C. Threat Awareness UI

- **No radar** in the traditional sense (the manual describes instruments only, no radar/minimap for the PC version)
- Threat identification through visual target brackets (red = enemy)
- Off-screen threat arrows
- No RWR system (pre-missile era setting, prop aircraft)

### D. Flight State Indicators

- **Speed:** Circular dial (barometric speedometer) with stall warning built in
- **Altitude:** Dual-needle circular gauge with red low-altitude warning light below 100 ft
- **Heading:** Circular compass gauge
- **Artificial horizon:** Full gyroscopic attitude display
- All on physical cockpit instrument panel — part of the 3D cockpit

### E. Cockpit-Specific UI

- Three view modes: (1) Cockpit with full 3D instrument panel visible, (2) External view showing terrain + most instruments, (3) First-person (no cockpit visible)
- Additional cameras: Chase view (fixed to aircraft), target-tracking view, four fixed overhead cameras
- The instruments are modeled as in-world physical gauges with named manufacturers — very detailed physical cockpit presentation
- Damage indicator (4-zone schematic) appears to be HUD-space overlay, not a physical gauge

### F. Third-Person Specific UI

- External view shows "most instruments" still — unusual hybrid approach (some instruments persist in external view)
- Chase view available as separate option

### G. Score / Status / RPG Elements

- No score display during mission
- Damage model is component-based (4 zones with color coding)
- No resource economy mid-mission in PC version

### H. Minimal HUD / Immersive Options

- Not documented; cockpit-centric design

### I. Visual Design Language

- **Color:** Red = enemy, Green = friendly, Blue = neutral; ammo counter color progression green→yellow→red; damage zones in same color scale
- **Style:** Vintage/pulp aesthetic with named instrument brands suggesting physical realism
- **Period design:** Art Deco-influenced cockpit instrumentation language

---

## Part 4: Crimson Skies — High Road to Revenge (Xbox 2003)

### A. HUD Element Inventory

FASA Studio redesigned the interface significantly for the Xbox version. The cockpit simulation fidelity was dropped in favor of an arcade third-person style HUD.

**Full element list (left-to-right across bottom of screen):**

| Element | Position | Form | Notes |
|---|---|---|---|
| Health meter | Bottom-left area | Bar | Aircraft armor/hit points; "when armor runs out, plane explodes" |
| Ammo indicator | Bottom-left/center | Bar or numeric | Primary gun ammo (machine guns have unlimited but overheat) |
| Special meter | Bottom-center | Bar | Governs special maneuvers (barrel roll, Immelmann); recharges over time |
| Cash on hand | Bottom-center area | Numeric text | Currency for upgrades/repairs shown live during mission |
| Radar display | Bottom-right | Circular minimap | Enemies, objectives, terrain; positional awareness |
| Targeting crosshairs | Center screen | Cross/reticle | "Helps aim your guns; glows blue if you're not supposed to shoot someone" |
| Enemy highlighting | World-space | Visual outline/highlight | Highlights targetable enemies |
| Secondary weapon display | HUD panel | Weapon type icon + count | "Indicates which kind you have, and how many uses are left" |
| Objective tracker | HUD area | Text | Current mission objective displayed |

### B. Targeting and Weapon State UI

- **Crosshair:** Central reticle that glows blue when targeting non-hostiles (prevents friendly fire confusion)
- **Lock-on:** Certain weapons have dedicated lock-on mechanics (missiles, magnetic rockets, Tesla coils)
- **Enemy highlighting:** Enemies highlighted distinctly from neutrals and environment
- **Secondary weapon counter:** Type + remaining uses shown

### C. Threat Awareness UI

- **Radar (minimap):** Circular display in bottom-right; shows enemies, objectives, terrain
- No RWR equivalent — pre-missile era setting (rockets, not modern missiles)
- Enemy highlighting provides threat identification

### D. Flight State Indicators

- **Speed:** Not clearly described in available sources (arcade game may omit explicit speed)
- **Health:** Prominent bar in bottom-left area — primary survivability indicator
- **Throttle:** "Regular", "Boost", "Brake" three-state system (changed from PC's nine-point throttle)

### E. Cockpit-Specific UI

- Xbox version moved primarily to third-person; cockpit view available but less emphasized
- Camera shifts to first-person when manning fixed weapon emplacements

### F. Third-Person Specific UI

- Primary play mode is third-person
- Targeting crosshair centered in screen space
- Radar always visible in bottom-right
- HUD briefly hidden when transitioning to free-roam areas (aircraft exits Pandora carrier)

### G. Score / Status / RPG Elements

- Cash displayed live during mission (spend on repairs and upgrades)
- Special meter: recharging resource for aerial maneuvers — not unlike an ability gauge
- No XP or ability tree (upgrades through cash, not XP progression)

### H. Minimal HUD / Immersive Options

- No documented HUD toggle
- Arcade design — HUD is always-on

### I. Visual Design Language

- **Style:** Colorful, bold, accessible — console arcade aesthetic
- **Color:** Health bar likely red/orange; special bar likely blue or yellow (not confirmed precisely in sources)
- **Crosshair:** Blue tint when targeting non-hostiles (smart allegiance coloring)
- **Layout:** Left-to-right bar cluster at bottom, radar bottom-right — standard late-2000s console action game convention

---

## Part 5: Dawn of Jets (Meta Quest, 2024/2025 Early Access)

### A. HUD Element Inventory

Dawn of Jets is a VR-only simcade on Meta Quest 3/3S/2/Pro. Its key design principle is **physical cockpit interaction over glass HUD overlays**. Almost no screen-space HUD exists — all information is embedded in the 3D cockpit.

**Element list:**

| Element | Location | Form | Notes |
|---|---|---|---|
| All flight instruments | Physical cockpit dashboard | 3D modeled gauges, dials, MFDs | Each aircraft has unique cockpit layout; everything "meticulously detailed" |
| Weapon selection | Physical cockpit switches/panels | Manual toggle switches | Gun/missile/rocket/bomb selection via physical controls |
| Lock-on indicator | Unknown — likely world-space or cockpit gauge | Not documented in available sources | Described as "lock-on missiles" function |
| Target spotting | No HUD overlay | Visual clarity via VR resolution | "Making it easy to spot distant targets" — relies on natural vision |
| Engine/system controls | Physical cockpit | Levers, switches | Throttle, flaps, landing gear all manual |

### B. Targeting and Weapon State UI

- Weapon switching done via physical cockpit controls, not a HUD panel
- Lock-on missiles exist but specific visual lock feedback not documented
- The core philosophy is: **real instruments replace HUD overlays**

### C. Threat Awareness UI

- No described radar/minimap HUD overlay
- Threat awareness through natural VR vision — look over shoulder, physically turn head
- "Looking over your shoulder to track an enemy jet" — head tracking is the radar replacement

### D. Flight State Indicators

- All via physical cockpit instruments — no floating numbers
- Each aircraft model has its own cockpit layout with accurate period instruments

### E. Cockpit-Specific UI

- This is the only view — everything is cockpit-based
- Interactive stick (grab with controller), throttle lever, flap handle, weapon switches, engine start, landing gear
- "Almost everything is done manually by activating switches or manipulating levers"
- Cockpit initially "overwhelming" for new players — guided procedure exists for takeoff/landing

### F. Third-Person Specific UI

- No third-person view exists — VR cockpit only

### G. Score / Status / RPG Elements

- Not documented in available sources

### H. Minimal HUD / Immersive Options

- The entire game is minimal HUD — by design
- Zero screen-space overlays described; all info via physical cockpit

### I. Visual Design Language

- Physical realism aesthetic — modeled gauges, historically accurate cockpit layouts
- Natural lighting on cockpit instruments
- No custom color palette for HUD (there is no HUD)

---

## Part 6: Fire & Ice HUD Design Specification

This section synthesizes all research findings into a complete, implementation-ready HUD design for Fire & Ice — a sci-fi aviation game with ice abilities, cooldown/mana systems, RPG elements, two camera modes (third-person orbit and cockpit), and fire elemental enemies.

---

### 1. Third-Person HUD Layout

**Design philosophy:** Borrow Ace Combat 7's approach (full HUD visible in third-person) but apply TCA's context-sensitivity (elements fade or condense when not relevant). The layout should frame the action without covering the center of the screen. Use screen-edge and screen-corner placement for all non-combat information.

**Screen regions and element placement:**

**TOP-LEFT CLUSTER (flight state, always visible):**
- Airspeed display — large monospace number + unit label ("482 kts"), top-left, approximately 5% from edge. Form: two-line block (label above, number below). Size: 36px number, 14px label at 1080p equivalent.
- Altitude display — directly below airspeed, same column. Form: number + "ft" or "m" unit.
- Heading — below altitude: three-digit degree readout + cardinal (e.g., "247° WSW"). Form: small numeric + abbreviated compass label.

**TOP-RIGHT CLUSTER (mission state):**
- Mission timer — top-right, numeric countdown MM:SS. Size: 20px.
- Score / Frost Crystal balance — below timer, right-aligned. Form: crystal icon + numeric count.

**TOP-CENTER (warnings and target identity):**
- Target name — appears only when target locked; centered near top-center, below the heading. Form: brief text label, ~18px.
- Warning text zone — "STALL", "OVERHEAT", "LOW MANA" — center-top, bold red/white flash text, size ~22px. Only active when warning condition exists.

**CENTER (targeting, world-space):**
- Target bracket — square corner brackets (not full box — use four L-shaped corners only, 20px each leg, 2px stroke) around locked enemy in world-space. Color state: Cyan `#00EEFF` (acquired) → White `#E8F4FF` (tracking) → Hot-white `#FFFFFF` flashing (ability in optimal range)
- Ability range circle — thin circle expanding from target bracket outward, radius indicates current ability's optimal range; circle color matches active ability's color (ice abilities use blue-white spectrum)
- Lead pipper — small crosshair offset from target center when using Frost Beam or Ice Shard Burst; computed for projectile travel time
- Off-screen target arrow — thin triangle arrow at screen edge pointing toward current locked target, same color as target bracket

**BOTTOM-LEFT (elemental threat awareness — replaces radar):**
- Fire Proximity Sensor — circular display, approximately 15% of screen height diameter. Center = player aircraft. Fire elementals appear as ember-orange `#FF6420` dots, size scaling with proximity; non-elemental enemies as dim white dots. Display uses a radial gradient background from near-transparent center to deep blue-black `#050A14` at edge. No range scale lines visible (clean), but implicit range from center: inner 30% = danger zone (ring tints red `#FF2200`), outer = awareness zone.
- Fire proximity intensity bar — thin arc around the FPS circle, like a progress bar that fills clockwise as nearest fire elemental approaches. Color: cool blue `#1A6FFF` when safe → warm amber `#FFA020` at 60% → red `#FF2200` at 90%+.
- Hostile count — small numeric in corner of FPS display: "x4" indicating enemies in sensor range.

**BOTTOM-RIGHT (RPG status):**
- Pilot XP bar — thin horizontal bar, bottom-right area, ~15% screen width. Color: `#7C4DFF` (purple-white gradient). Shows current XP within current level. Level number displayed to right ("LVL 12").
- Hull Integrity gauge — vertical or arc bar just inside the XP bar. Color: `#00CFFF` (ice-blue) fading to `#FF3300` as hull degrades. Form: arc (like a fuel gauge, 270° sweep, 12 o'clock = full).

**CENTER-BOTTOM (ability system — primary HUD element in combat):**
This is the most important custom element and the largest departure from reference games. Described in full in Section 3 below.

---

### 2. Cockpit HUD Layout

**Design philosophy:** Combine Tiny Combat Arena's physical cockpit philosophy (left MFD = attitude, right MFD = heading + sensors) with Ace Combat 7's practical "information on the glass" approach for the canopy overlay. Dawn of Jets' full-manual cockpit interaction is too demanding without VR — so the cockpit in Fire & Ice has functioning 3D instruments plus a supplemental glass overlay.

**Canopy glass overlay elements (always projected, semi-transparent):**
- Airspeed tape — left side of canopy glass, vertical ladder style (like TCA), cyan-tinted `#00DDFF` with white tick marks. Range ±50 kts visible, current speed centered. Size: spans from 20% to 80% screen height, 6% screen width.
- Altitude tape — right side of canopy glass, same format as airspeed. Color: slightly warmer `#00FFCC`.
- Artificial horizon line — center canopy, pitch ladder lines at ±5°, ±10°, ±20°, ±30°; bank angle arc at top. Color: `#00EEFF` lines on sky, `#FF6D00` (warm amber) on ground. Thickness: 1.5px for fine lines, 3px for horizon bar.
- Flight path marker — center, the TCA-style aircraft symbol (circle + stub wings + vertical line), color `#FFFFFF`. Indicates where the aircraft is actually going.
- Heading tape — along the bottom of the canopy glass, horizontal strip. Cardinal directions in bold (`N`, `S`, `E`, `W`), degree marks every 10°. Current heading under a top tick mark.
- G-meter — lower-left of glass overlay, numeric readout "4.2G", small size, white.
- Mana bar — center-bottom of glass overlay, thin horizontal bar ~30% screen width. Color: `#3AB7FF` → `#0044CC` gradient. Numeric percent overlay ("78%").

**Dashboard instruments (3D modeled, inside cockpit):**
- Left MFD: Mana/ability status page — shows 4 ability cooldown rings arranged in 2x2 grid, each with ability icon and remaining cooldown timer; or switchable to artificial horizon
- Right MFD: Fire proximity sensor (full circular display, higher resolution than third-person version) + enemy contact count
- Center console: Frost Crystal balance display (numeric, cold-blue `#BCE4FF` backlit)
- Throttle/thrust indicator: Physical lever with position indicator light strip
- Weapon selector (repurposed as ability selector): 6-position rotary switch, each position lights up with ability color when active

**Cockpit glass overlay elements not on third-person HUD:**
- Frost Nova readiness pulse — when Frost Nova is charged, a subtle pulsing ring appears in the periphery of the glass (all four edges) — signals area-of-effect readiness
- Pitch attitude numbers — appear at pitch ladder increments
- True airspeed vs. indicated marker — dual tick marks on airspeed tape

---

### 3. Ability System HUD

This is the core novel element. Replaces weapon selector + ammo counter entirely.

**Layout:** Horizontal row of ability icons, centered at the bottom of the screen. Positioned approximately 8% from the bottom edge (in third-person) or on Left MFD (in cockpit).

**Per ability slot (designed for 6 slots, expandable to 10):**

Each slot is a hexagonal tile (hex chosen for the ice crystal motif), dimensions approximately 64×72px at 1080p:
- **Icon:** Ability icon, 40×40px, centered in hex
- **Cooldown overlay:** Radial sweep overlay in dark blue `#001830` at 60% opacity, sweeps away clockwise as cooldown expires. When on cooldown, icon is desaturated to 40% opacity.
- **Cooldown timer:** Numeric countdown (seconds remaining) displayed inside hex while on cooldown — centered, bold, 14px white text
- **Mana cost indicator:** Small arc at bottom of each hex, partially filled to show mana cost relative to total pool. Color: `#3AB7FF`. If current mana is insufficient, the arc turns red `#FF3300` and the hex frame pulses red.
- **Ready glow:** When cooldown = 0 and mana sufficient, the hex border glows with the ability's signature color (see palette below) and pulses once per 2 seconds (not distracting, just alive)
- **Active/selected indicator:** Active ability has a bright white hex border `#FFFFFF`, 2px stroke. Others have dimmer borders `#1A3A5C`, 1px stroke.
- **Range state:** When target is within ability range, the selected hex brightens 30% and the hex corners emit small spark particles in the ability's color

**Ability color assignments:**
- Frost Beam: `#7BD4FF` — light sky blue
- Ice Shard Burst: `#FFFFFF` — pure white with blue tint
- Homing Ice Bolt: `#4DAFFF` — medium blue
- Glacial Prison: `#006FD4` — deep blue (heavy, slow ability)
- Frost Nova: `#B0F0FF` — pale icy cyan (area effect)
- Blizzard Veil: `#8EC5FF` — diffuse blue-grey (sustained/aura)

**Mana pool display:**
- Centered above the ability row (or below, depending on composition testing)
- Segmented horizontal bar: total bar is divided into segments equal to mana cost of current selected ability — so player can instantly see "how many more casts I have left"
- Color: `#3AB7FF` filled, `#0A1F3A` empty, 4px segment dividers in `#1C3D5A`
- Bar dimensions: 280px wide × 8px tall at 1080p, centered

**Switching abilities:** Clicking/bumper to cycle through active slot; the selected hex scales up 10% with a brief bounce animation (100ms ease-out). No delay — instant selection. DLZ equivalent for abilities: range indicator on selected hex brightens continuously from dimmer → full brightness as target enters optimal range.

---

### 4. Elemental Threat Awareness — Fire Proximity Sensor

**Replaces:** Traditional radar (PPI circular) and RWR (radar warning receiver).

**Core design principle:** The FPS (Fire Proximity Sensor) is not about radar lock or radio emissions — it detects heat signatures and elemental energy. This changes the visual language completely.

**Fire Proximity Sensor display (third-person bottom-left, cockpit right MFD):**

- Shape: Circle, ~13% screen height diameter (≈140px at 1080p)
- Background: Deep space-blue radial gradient: center `#0D1F35` → edge `#050A14`
- Ice shimmer: Subtle animated shimmer texture on the background (like looking through frosted glass) — animates at 0.3 Hz, amplitude very low — adds sci-fi character without distraction
- Player aircraft: Fixed center point, small upward-pointing diamond `◆` in white `#FFFFFF`
- Fire elementals: Rendered as orange-red ember glows `#FF6420` — NOT as sharp arrowheads. Size increases as they get closer (innermost = 12px dia, outermost = 4px dia). No direction indicator for individual enemies — they glow larger, not display an arrow (enemies are omnidirectional fire elementals, not missile-launching aircraft)
- Danger proximity ring: At 30% radius from center, a thin ring `#FF2200` at 30% opacity — crosses into this ring = engaged range. Ring pulses (0.8 Hz) when an enemy is inside it.
- Non-fire enemies: Same display as Ace Combat's radar but using `#C8E8FF` (cool blue-white) to distinguish from fire elementals
- Heat intensity bar: Wrapping arc outside the circle (270° sweep), fills clockwise: `#1A6FFF` → `#FFA020` → `#FF2200`. Represents the combined heat pressure from all nearby fire elementals.
- Range scale: Not visible by default (clean aesthetic). In cockpit view, range scale tick marks at 25%, 50%, 75% radius appear as faint labels.

**Directional fire threat indicator (screen-edge element):**
When a fire elemental is within the danger ring and outside the player's view cone: a heat shimmer distortion effect appears on the corresponding screen edge (similar to AC7's red bar but as a heat-wavering shimmer rather than a solid bar). Color: orange-red `#FF4A10` at 50% opacity, approximately 4% of screen height wide. Also accompanied by audio: a crackling heat sound directionally panned.

**Fire proximity warning states:**
- Safe (no enemies in range): FPS background is pure deep blue; heat arc = 0% filled; screen edge = clear
- Awareness (enemies detected, outer zone): Outer glow of FPS gets slight orange tinge; heat arc fills to 30%; soft crackle audio begins
- Danger (enemy in danger ring): Danger ring pulses; heat arc 60-90%; screen edges flicker amber; mana regeneration rate indicator (if shown) drops (fire suppresses ice)
- Critical (multiple enemies in danger ring): Full heat arc red; FPS background warms to dark orange tint; urgent audio; hull integrity bar brightens/pulses

---

### 5. RPG Status Elements

**Pilot XP bar:**
- Position: Third-person — bottom-right corner, above hull integrity arc. Cockpit — left MFD secondary page or bottom of left dash panel.
- Form: Thin horizontal bar (280px × 6px at 1080p), with level number to right ("LVL 14")
- Color: `#7C4DFF` → `#C084FC` gradient fill; `#0D0D2A` background; subtle glow on fill edge
- On level-up: Bar flashes white, then briefly displays "LEVEL UP" text in center screen (2 seconds, fades), then resets to zero fill. Accompanied by a crystalline chime audio.
- Visibility: Always-on — small enough not to distract, meaningful at a glance

**Frost Crystal balance:**
- Position: Top-right area, below score/timer
- Form: Crystal icon (snowflake or faceted gem) + numeric count (e.g., "◈ 1,247")
- Color: Icon `#BCE4FF`, numeric `#FFFFFF`
- On crystal pickup: Number increments with a brief sparkle particle effect; number briefly scales up 120% then returns to 100% (150ms animation)
- On crystal spend: Number decrements; brief blue pulse on icon

**Ability tier indicators:**
- Position: Small badge overlay on each ability hex tile (bottom-left of hex)
- Form: Roman numeral or star rating (I / II / III / IV) in matching ability color, 10px font
- Purpose: Shows enchantment/upgrade level of each ability — at-a-glance progression tracking
- On ability upgrade (between missions): Hex tile plays a sparkle-burst animation when first displaying upgraded tier

**Enchantment status (aircraft hull):**
- Not a mid-mission visible element — appears on a separate status overlay or in the pause menu
- During flight: Active enchantments subtly glow as particles on the aircraft model, not on the HUD

---

### 6. Hull Integrity / Damage System

**Replaces:** Ace Combat's vague condition scale and Crimson Skies' component damage schematic.

Fire & Ice uses "Ice Hull Integrity" — the aircraft's protective ice armor is its primary defense mechanism. Damage shows as cracking, melting, and shattering of the ice shell.

**Hull Integrity gauge:**
- Position: Bottom-right area, third-person HUD. Arc form (270° sweep), outside the pilot XP bar.
- Form: Arc gauge, 12 o'clock = full, sweeps clockwise. When full = bright ice-blue fill `#00CFFF`. Outer track in dark blue `#0A1F3A`.
- Segments: 10 equal segments separated by 2px gaps. Each segment is individually destroyable — damage removes whole segments with a shattering animation (500ms), not smooth depletion.
- Color progression (per remaining segments):
  - 10-8 segments: `#00CFFF` — full ice-blue
  - 7-5 segments: `#5599FF` — cooling, slightly purple
  - 4-3 segments: `#9966FF` — warning purple — regeneration rate slows
  - 2-1 segments: `#FF6644` — danger orange-red (structural failure imminent)
  - 0 segments: Aircraft destruction — FX sequence
- **Regeneration:** Ice hull slowly recharges at a base rate. Visual: segments tick back in at full brightness (not smooth fill) with a soft crystallization sound. Regeneration pauses when in the fire proximity danger zone.
- **Component damage:** Three sub-indicators as small icons below the arc: Left Wing, Right Wing, Fuselage — each as a small hex with color coding (same scale as above) — only visible if damaged. Normal state: invisible (clean HUD).
- **Hit flash:** On taking damage, the corresponding screen edge (or the whole edge if omni-directional hit) flashes with an ice-crack texture overlay, 300ms, white `#FFFFFF` at 60% opacity fading to transparent. Different from Ace Combat's solid red — more crystalline.

**Cockpit view hull damage:**
- Same arc gauge visible on right MFD or right side of glass overlay
- Physical cockpit responds: ice particle effects begin appearing on the canopy glass at 4/10 or less — visual ice cracking texture overlaid on the world view (immersive)

---

### 7. View Transition Design

**Cockpit → Third-person:**
1. Brief camera dolly-back animation (150ms ease-in-out) — camera pulls from eye position to orbit position, ~15-20m behind and above the aircraft
2. During dolly: HUD elements cross-fade. Glass overlay elements (speed tape, altitude tape, artificial horizon, heading) fade out over 200ms.
3. Third-person HUD cluster elements (top-left airspeed/altitude numerics, ability row) fade in over 200ms.
4. FPS display (bottom-left) stays visible throughout — it does not disappear during transition.
5. Cockpit physical view goes dark as camera exits — no jarring cut.
6. Total transition: ~400ms

**Third-person → Cockpit:**
1. Camera dolly-in from orbit to eye position (150ms ease-in)
2. Third-person top-corner numerics fade out (200ms)
3. Canopy glass overlay elements (speed tape, artificial horizon, heading tape) fade in (200ms)
4. Cockpit interior becomes visible with all instruments lit
5. Ice crack texture (if hull damaged) materializes on canopy glass over 300ms

**Elements that persist through both views (never transition):**
- Ability row (moves from center-bottom to left MFD — position animates)
- FPS display (position animates from bottom-left to right MFD)
- Warning text (always center-top)
- Target bracket (world-space — always visible)
- Mana bar (transitions from above ability row to center of glass overlay)

**Camera behavior in third-person:**
- Orbit camera stays level (does not roll with aircraft — Ace Combat convention)
- Camera lags behind aircraft heading by ~200ms for cinematic feel
- In hard maneuvers: camera pulls slightly further back (15%→20% distance increase) automatically

---

### 8. Color and Visual Language

**Master ice palette:**

| Use | Color Name | Hex | Application |
|---|---|---|---|
| Primary accent | Glacier Blue | `#00CFFF` | Hull integrity, primary targeting |
| Secondary accent | Arctic Cyan | `#00EEFF` | Target bracket, speed tape |
| Deep background | Abyss Navy | `#050A14` | FPS background, ability hex inactive |
| Mid background | Polar Night | `#0A1F3A` | Gauge backgrounds, MFD background |
| Frame / border | Ice Shelf | `#1C3D5A` | Inactive ability borders, MFD borders |
| Neutral elements | Frost White | `#E8F4FF` | Standard text, heading tape, tracking bracket |
| Active selection | Pure White | `#FFFFFF` | Selected ability border, FPM symbol |
| Mana pool | Deep Blue | `#3AB7FF` | Mana bar fill |
| Low mana warning | Cold Violet | `#9966FF` | When mana below 30% |
| Critical mana | Ice Rupture | `#CC44FF` | When mana below 15% (different from fire threat) |
| XP bar | Mystic Purple | `#7C4DFF` | Pilot XP fill |
| Frost Crystal | Crystal Blue | `#BCE4FF` | Resource icon |
| Fire threat | Elemental Ember | `#FF6420` | Fire elemental dots on FPS |
| Fire danger | Eruption Red | `#FF2200` | Danger proximity ring, critical heat arc |
| Heat shimmer | Combustion Amber | `#FFA020` | Mid-danger heat arc, screen-edge warning |
| Enemy missile/attack | Warning Flash | `#FF4A10` | Screen-edge directional threat shimmer |
| Hull safe | Ice Blue | `#00CFFF` | Hull integrity segments, full health |
| Hull warning | Cold Purple | `#9966FF` | Hull 40% — warning state |
| Hull critical | Burn Orange | `#FF6644` | Hull 20% — danger state |
| Ally targets | Safe Pale Blue | `#80C8FF` | Non-hostile detected entities on FPS |

**Typography:**
- Primary font: Monospace, condensed, angular — suggestion: Rajdhani Bold or Orbitron for sci-fi character. Fallback: system monospace.
- HUD overlay elements (numbers): 16-20px for secondary data, 28-36px for primary readouts (speed, altitude), 40px+ for critical warnings.
- Ability hex cooldown timers: 14px bold white, centered.
- All text should be rendered with a subtle drop shadow of `#001830` at 60% opacity, 2px offset — ensures legibility against sky backgrounds.

**Animation timing standards:**
- State changes (ability ready): 80ms fade-in
- Target bracket change (acquired → in-range): 100ms color transition + 1-frame scale pop (102% → 100%)
- Hull segment loss: 500ms shattering particle burst, then segment disappears
- Warning flash (hit): 300ms screen-edge flash
- Level-up: 2s center-screen text, 500ms bar flash
- FPS danger ring pulse: 0.8 Hz (1.25s period)
- Ready ability hex glow pulse: 2s period, amplitude ±20% brightness
- View transition: 400ms total (150ms camera + 200ms HUD crossfade with 50ms overlap)

**Sky legibility strategy:**
- All HUD elements have a thin `#000000` 20% opacity backdrop plate (not a box — just a tight padding of 4px around text/numbers, with 2px corner radius)
- Alternatively: thin outline on text (1px `#001830` stroke) instead of backdrop
- FPS display has its own background circle — no backdrop needed for that region
- Ability row has a minimal translucent bar behind the hex row: `#050A14` at 40% opacity, height matches hex tiles + 8px padding, full-width or ability-group-width

---

### 9. Minimal HUD Recommendation

If the player activates a minimal/immersive HUD mode, these 6 elements must remain visible at all times. Everything else can be hidden:

**The Non-Negotiable Six:**

1. **Active Ability indicator (single slot only)** — the currently selected ability with cooldown state. Without this, the player cannot know if their primary action is available. Minimum form: single small hex tile, 40×45px, bottom-center.

2. **Mana bar** — a 3px tall line below the active ability hex. Without mana awareness, players waste attempts. Minimum form: 80px wide line segment.

3. **Fire Proximity Sensor** — cannot be hidden even in minimal mode. Without it, player has zero threat awareness (there is no radar, no radar warning receiver, no missile trails — FPS is the *only* threat system). Minimum form: 60px circle, bottom-left, same ember dots, no heat arc (reduce to just the spatial display).

4. **Hull Integrity** — the game's equivalent of health. Minimum form: condensed 5-segment arc, 40px diameter, bottom-right corner.

5. **Target bracket** — world-space overlay on the locked enemy. Without it, there is no combat feedback loop. The bracket itself is small (only the four corner L-shapes) and minimally intrusive. Non-negotiable.

6. **Mana critical warning text** — the one warning text that must survive. "LOW MANA" flashing center-screen is not intrusive enough to matter, but its absence would cause death-by-inability-to-understand-failure. Display: flashing text only when mana below 15%, auto-hides above threshold.

**Rationale from research:**
- TCA: external views strip all HUD — but that game has a radar and missile audio; Fire & Ice has neither, making FPS non-removable.
- AC7: removing HUD entirely makes radar disappear and target interception become nearly impossible — same principle applies to FPS.
- Crimson Skies Xbox: health + special meter are the core survival gauges — direct analogues to Hull Integrity and Mana bar.
- Dawn of Jets: proves players can operate with near-zero HUD, but only in VR with physical instruments — not valid for flat-screen third-person.

---

## Implementation Notes for Flutter/WebGL

**Rendering layer stack (back to front):**
1. 3D world (WebGL scene)
2. World-space targeting brackets (rendered in 3D space, projected — not screen-space, to maintain parallax realism)
3. FPS display circle (Canvas 2D or WebGL 2D layer, fixed bottom-left)
4. Ability row hex tiles (Canvas 2D, fixed bottom-center)
5. All numerical readouts and text (Canvas 2D or DOM overlay)
6. Hit flash and screen-edge effects (fullscreen Canvas, top layer with pointer-events:none)
7. Cockpit 3D model (rendered as part of 3D scene with depth-buffer cleared before, to always appear in front of world)
8. Canopy glass overlay (2D Canvas layer between cockpit 3D and above layers)

**Key dimension guide (at 1920×1080, scale proportionally):**
- FPS circle: 140px diameter, positioned at (80, 940) — center coords
- Ability row: 6 hexes × 68px wide, centered horizontally at (960, 1020) — top edge of row
- Airspeed tape (cockpit): x=120, spans y=180–900
- Altitude tape (cockpit): x=1800, spans y=180–900
- Hull integrity arc: center at (1800, 980), radius 55px, 270° sweep
- XP bar: x=1620, y=1055, width=280, height=6
- Target bracket arms: 20px long, 2px wide, 8px gap from actual target bounds

---

Sources:
- [Tiny Combat Arena HUD Rendering and Elements - YouTube](https://www.youtube.com/watch?v=B5JnGtf7NJk)
- [Interview: Why485, developer of Tiny Combat Arena (Part 2)](https://www.skywardfm.com/post/interview-why485-developer-of-tiny-combat-arena-part-2)
- [Tiny Combat Arena Steam Community - UI Information Overload](https://steamcommunity.com/app/1347550/discussions/0/3843304884863510968/)
- [Tiny Combat Arena Steam Community News](https://steamcommunity.com/app/1347550/allnews/)
- [Tiny Combat Arena Weapons and Employment Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2773164469)
- [Tiny Combat Arena Modded Changelog](https://github.com/o7-Fire/Tiny-Combat-Arena-Modded/blob/main/changelog.txt)
- [Tiny Combat Arena 0.13.7 - Game Update Notifier](https://gameupdatenotifier.com/g/tiny-combat-arena/v/0-13-7)
- [Ace Combat HUD - Acepedia (Fandom)](https://acecombat.fandom.com/wiki/Head-up_display)
- [Ace Combat HUD - Ace Combat Wiki (wiki.gg)](https://acecombat.wiki.gg/wiki/Head-up_display)
- [Ace Combat 7 Tips and Tricks - Push Square](https://www.pushsquare.com/news/2019/02/guide_ace_combat_7_skies_unknown_-_tips_and_tricks_for_beginners)
- [Ace Combat 7 Avoiding Enemy Missiles - GamePressure](https://www.gamepressure.com/ace-combat-7/avoiding-enemy-missiles-and-fire/zbbccc)
- [Ace Combat 7 HUD Display - Steam Discussion](https://steamcommunity.com/app/502500/discussions/0/1840188800801957134/)
- [Ace Combat 7 Post Stall Maneuver - Acepedia](https://acecombat.fandom.com/wiki/Post_Stall_Maneuver)
- [Ace Combat 7 Daftest's Alternative HUD - NexusMods](https://www.nexusmods.com/acecombat7skiesunknown/mods/3594)
- [Crimson Skies (2000) Manual - Internet Archive](https://archive.org/stream/crimsonskies2000manual/Crimson%20Skies%20(2000)%20Manual_djvu.txt)
- [Crimson Skies Xbox Manual - Internet Archive](https://archive.org/stream/xboxmanual_Crimson_Skies/Crimson_Skies_djvu.txt)
- [Crimson Skies: High Road to Revenge - Wikipedia](https://en.wikipedia.org/wiki/Crimson_Skies:_High_Road_to_Revenge)
- [Crimson Skies: High Road to Revenge - en-academic](https://en-academic.com/dic.nsf/enwiki/11588645)
- [Crimson Skies: High Road to Revenge - Neoseeker FAQ](https://www.neoseeker.com/crimsonskies-revenge/faqs/)
- [Dawn of Jets - Meta Quest Store](https://www.meta.com/experiences/dawn-of-jets/3677727965681410/)
- [Dawn of Jets - UploadVR](https://www.uploadvr.com/dawn-of-jets-vr-quest-early-access/)
- [Dawn of Jets Review - Duuro Plays](https://duuro.net/blog/dawn-of-jets-review)
- [Dawn of Jets - Elite Institute Review](https://theeliteinstitute.net/2025/01/15/dawn-of-jets-early-access-meta-quest-3/)