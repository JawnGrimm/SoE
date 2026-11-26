# Scribe of Eras — Second Workday Milestone

A Godot 4.7 GDScript prototype for a data-driven historical scribal career simulation.

## Run it

Open the repository root in Godot **4.7.x stable** and press **F5**. The root project launches the case-file interface.

## Headless event test

From the repository root:

```sh
godot --headless --path . --script res://tests/test_event_slice.gd
```

On Windows, if `godot` is not on PATH, run the executable by its full path, for example:

```powershell
& "C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/test_event_slice.gd
```

The test covers both first-case outcomes, archived assessments, persistence across period advances, era-aware eligibility, flag expiry, form deadlines, both condition-driven follow-up branches, and the empty-queue result.

## Current desk loop

1. Examine the surviving dispatch copy, receiving tally, and missing loading observation.
2. Enter one assessment:
   - No individual responsibility assigned
   - Origin-side dispatch count or handling requires verification
3. Choose whether to certify the tally or open a formal inquiry.
4. Select **End Period** to advance the monthly desk turn.
5. The EventScheduler evaluates the available `.tres` cases against the current actor and world state. The North-Bay Roof Inspection is offered from the temple path as a separate cedar-desk docket; consult Ur-Nanna, inspect the beams, and submit a supported assessment.
   - The `complicit` trait makes **A Routine Adjustment** eligible.
   - The `grain_scandal` flag plus a pending `inquiry` form makes **The Origin-Side Reply** eligible. Its case text quotes the assessment stored on the archived grain levy.
6. When no event is eligible, the desk displays **END OF QUEUE / All cases filed for now**. The player may continue advancing periods; the scheduler checks again each time.

The clock uses 12 periods per year. `WorldState.current_period_index()` provides an absolute period index (`year * 12 + period`) for durations and deadlines. Flag effects accept `periods` (or legacy `years`, converted to 12 periods per year); flags expire automatically when their expiry period begins. Forms may include an absolute `due_period`; they become overdue after that period passes, remain pending until resolved, and retain an overdue record in the archive. Forms without a deadline are unaffected. `WorldState.advance_period()` processes expiry and deadlines without recreating world state or discarding stockpiles, people, traits, memories, forms, or event history.

## Included

- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState, EventContext, ConditionEvaluator, EffectExecutor, EventRunner, EventScheduler
- Persistent 12-period clock
- Pending and archived form records, including assessment and disposition
- Three data-driven case definitions: the missing measures, routine tally adjustment, and origin-side reply
- Resource-driven North-Bay assignment offer, consultation and inspection records, and assessment settlement
- Persistent North-Bay roof leak that spoils one measure of barley per elapsed period
- Case-file UI with an explicit end-of-queue state

## Not included yet

- Versioned save format
- Office roster and extracted relationship component
- Historical flag expiry and deadline processing (implemented in the current milestone)
- Full calendar presentation and production UI polish
- Seven-era content or simulation systems

## Guardrails

Definitions are Resources; runtime changes affect only world/person state. Unknown condition/effect types fail closed with warnings. Unsupported resource scopes warn and do not mutate state. The scheduler selects only templates whose existing conditions and eligibility gates pass; story branches are data, not day-number script branches.


<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 840" width="100%" height="100%" role="img" aria-labelledby="title desc">
  <title id="title">Scribe of Eras — Conceptual Gameplay Loop</title>
  <desc>Conceptual diagram showing Player choosing a Professional Orientation, interacting bidirectionally through one shared World with an unordered, scattered Assignment pool, feeding shared context into Challenges, and encountering historical Works (the sole source of Historical Progress XP).</desc>

  <defs>
    <radialGradient id="bgGlow" cx="68%" cy="54%" r="55%">
      <stop offset="0%" stop-color="#28211A"/>
      <stop offset="60%" stop-color="#171310"/>
      <stop offset="100%" stop-color="#110E0C"/>
    </radialGradient>

    <linearGradient id="bronzeGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#8C5828"/>
      <stop offset="60%" stop-color="#C88746"/>
      <stop offset="100%" stop-color="#E4AC6B"/>
    </linearGradient>

    <linearGradient id="worksGrad" x1="100%" y1="0%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#1E6B47"/>
      <stop offset="65%" stop-color="#2E9D68"/>
      <stop offset="100%" stop-color="#5ED396"/>
    </linearGradient>

    <radialGradient id="starGlow" cx="50%" cy="50%" r="55%">
      <stop offset="0%" stop-color="#3BD188" stop-opacity="0.22"/>
      <stop offset="70%" stop-color="#2E9D68" stop-opacity="0.06"/>
      <stop offset="100%" stop-color="#2E9D68" stop-opacity="0"/>
    </radialGradient>

    <radialGradient id="nexusGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#F6E2B3" stop-opacity="0.9"/>
      <stop offset="35%" stop-color="#D49B4B" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#D49B4B" stop-opacity="0"/>
    </radialGradient>

    <linearGradient id="membraneGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#2C241D" stop-opacity="0.82"/>
      <stop offset="50%" stop-color="#221C17" stop-opacity="0.58"/>
      <stop offset="100%" stop-color="#2C241D" stop-opacity="0.82"/>
    </linearGradient>

    <filter id="softGlow" x="-25%" y="-25%" width="150%" height="150%">
      <feGaussianBlur stdDeviation="5" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Background & Tablet Frame -->
  <rect width="1600" height="840" fill="url(#bgGlow)"/>
  <rect x="20" y="20" width="1560" height="800" rx="14" fill="none" stroke="#3D3228" stroke-width="1.5"/>
  <rect x="28" y="28" width="1544" height="784" rx="10" fill="none" stroke="#2B231C" stroke-width="1"/>

  <!-- Subtle architectural grid -->
  <g stroke="#251F19" stroke-width="1" opacity="0.65">
    <line x1="28" y1="210" x2="1572" y2="210" stroke-dasharray="4 6"/>
    <line x1="28" y1="690" x2="1572" y2="690" stroke-dasharray="4 6"/>
  </g>

  <!-- Header -->
  <text x="58" y="68" fill="#C89D54" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="12" font-weight="700" letter-spacing="3.5">SCRIBE OF ERAS · CONCEPTUAL GAMEPLAY LOOP</text>
  <text x="58" y="100" fill="#F3EAD8" font-family="'Georgia', 'Times New Roman', serif" font-size="28" font-weight="700" letter-spacing="0.5">Different Set &amp; Setting, One Shared Historical World</text>
  <text x="1542" y="92" text-anchor="end" fill="#9A8C7A" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="13" letter-spacing="2">ORIENTATION  →  CONVERGENCE  →  ENCOUNTER</text>

  <!-- Ambient glow behind Works star -->
  <circle cx="1415" cy="450" r="195" fill="url(#starGlow)"/>

  <!-- ==================== 1. PLAYER (HEART) ==================== -->
  <text x="105" y="370" text-anchor="middle" fill="#B9AA96" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="13" font-weight="700" letter-spacing="2.5">PLAYER</text>

  <g stroke="#8C7B65" stroke-width="2" stroke-linecap="round" opacity="0.85">
    <line x1="142" y1="450" x2="236" y2="270"/>
    <line x1="142" y1="450" x2="236" y2="390"/>
    <line x1="142" y1="450" x2="236" y2="510"/>
    <line x1="142" y1="450" x2="236" y2="630"/>
  </g>
  <circle cx="142" cy="450" r="3.5" fill="#E4AC6B"/>

  <g transform="translate(105, 450)" filter="url(#softGlow)">
    <circle cx="0" cy="0" r="46" fill="#1C1713" stroke="#5A4937" stroke-width="1.5"/>
    <path d="M 0 21 C -4 17, -25 3, -25 -10 C -25 -20, -16 -26, -8 -26 C -3 -26, 0 -22, 0 -19 C 0 -22, 3 -26, 8 -26 C 16 -26, 25 -20, 25 -10 C 25 3, 4 17, 0 21 Z"
          fill="#2D1916" stroke="#E4C99B" stroke-width="2.5" stroke-linejoin="round"/>
  </g>

  <!-- ==================== 2. PROFESSIONAL ORIENTATION ==================== -->
  <g text-anchor="middle" fill="#D8C9B4" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="12" font-weight="700" letter-spacing="1.6">
    <text x="275" y="176">PROFESSIONAL</text>
    <text x="275" y="193">ORIENTATION</text>
  </g>

  <!-- Triangle (Malachite Green) -->
  <g transform="translate(275, 270)">
    <polygon points="0,-29 27,20 -27,20" fill="#162920" stroke="#4EA874" stroke-width="2.75" stroke-linejoin="round"/>
    <polygon points="0,-16 14,11 -14,11" fill="none" stroke="#4EA874" stroke-width="1" opacity="0.45"/>
  </g>

  <!-- Diamond (Carnelian Red) -->
  <g transform="translate(275, 390)">
    <polygon points="0,-30 26,0 0,30 -26,0" fill="#2A1714" stroke="#D15B47" stroke-width="2.75" stroke-linejoin="round"/>
    <polygon points="0,-17 14,0 0,17 -14,0" fill="none" stroke="#D15B47" stroke-width="1" opacity="0.45"/>
  </g>

  <!-- Pentagon (Lapis Blue) -->
  <g transform="translate(275, 510)">
    <polygon points="0,-29 28,-9 17,24 -17,24 -28,-9" fill="#15212E" stroke="#4B89C8" stroke-width="2.75" stroke-linejoin="round"/>
    <polygon points="0,-17 16,-5 10,14 -10,14 -16,-5" fill="none" stroke="#4B89C8" stroke-width="1" opacity="0.45"/>
  </g>

  <!-- Hexagon (Carved Bone) -->
  <g transform="translate(275, 630)">
    <polygon points="0,-29 25,-14 25,14 0,29 -25,14 -25,-14" fill="#23201C" stroke="#D6CFC2" stroke-width="2.75" stroke-linejoin="round"/>
    <polygon points="0,-17 15,-8 15,8 0,17 -15,8 -15,-8" fill="none" stroke="#D6CFC2" stroke-width="1" opacity="0.4"/>
  </g>

  <!-- ==================== 3. LEFT WORLD LENS ==================== -->
  <rect x="345" y="138" width="120" height="558" rx="8" fill="url(#membraneGrad)" stroke="#6C5B49" stroke-width="1.75"/>
  <g text-anchor="middle" fill="#D8C9B4" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="11" font-weight="700" letter-spacing="0.8">
    <text x="405" y="162">THE WORLD</text>
    <text x="405" y="177" fill="#9E8F7B" font-weight="600">through gameplay /</text>
    <text x="405" y="192" fill="#9E8F7B" font-weight="600">player actions</text>
  </g>
  <line x1="358" y1="204" x2="452" y2="204" stroke="#4E4134" stroke-width="1"/>

  <!-- ==================== 4. ASSIGNMENTS (OPEN, SCATTERED POOL) ==================== -->
  <text x="585" y="175" text-anchor="middle" fill="#D8C9B4" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="14" font-weight="700" letter-spacing="2">ASSIGNMENTS</text>
  <text x="585" y="194" text-anchor="middle" fill="#9E8F7B" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="9.5" font-weight="600" letter-spacing="1.1">SHARED POOL · VARIED &amp; SCATTERED</text>

  <rect x="495" y="210" width="180" height="480" rx="8" fill="#1D1814" stroke="#6C5B49" stroke-width="1.75"/>

  <!-- Meandering cross-cutting paths across the open pool -->
  <g fill="none" stroke-width="1.6" stroke-dasharray="4 4" opacity="0.42">
    <path d="M 505 270 C 555 245, 595 435, 665 374" stroke="#4EA874"/>
    <path d="M 505 390 C 545 365, 595 245, 665 258" stroke="#D15B47"/>
    <path d="M 505 510 C 565 520, 610 640, 665 622" stroke="#4B89C8"/>
    <path d="M 505 630 C 555 610, 600 475, 665 498" stroke="#D6CFC2"/>
    <path d="M 505 270 C 545 310, 560 560, 625 608" stroke="#4EA874" opacity="0.55"/>
    <path d="M 505 510 C 540 450, 580 315, 615 304" stroke="#4B89C8" opacity="0.55"/>
  </g>

  <!-- Scattered clay tags / bulla tiles all over the Assignments pool -->
  <g>
    <!-- Row 1 area -->
    <g transform="translate(520, 224) rotate(-2.5)">
      <rect width="46" height="24" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="30" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="24" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="8" r="2.6" fill="#4EA874"/>
      <circle cx="38" cy="16" r="2.6" fill="#D6CFC2"/>
    </g>
    <g transform="translate(590, 232) rotate(2)">
      <rect width="52" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="36" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="28" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="44" cy="13" r="2.8" fill="#D15B47"/>
    </g>

    <!-- Upper-mid -->
    <g transform="translate(542, 268) rotate(1.5)">
      <rect width="48" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="30" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="40" cy="8" r="2.6" fill="#4B89C8"/>
      <circle cx="40" cy="16" r="2.6" fill="#4EA874"/>
    </g>
    <g transform="translate(516, 312) rotate(-3)">
      <rect width="44" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="28" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="22" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="36" cy="13" r="2.8" fill="#D6CFC2"/>
    </g>
    <g transform="translate(584, 302) rotate(-1.5)">
      <rect width="54" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="34" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="26" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="45" cy="8" r="2.5" fill="#4EA874"/>
      <circle cx="45" cy="16" r="2.5" fill="#D15B47"/>
    </g>

    <!-- Mid -->
    <g transform="translate(534, 358) rotate(3)">
      <rect width="50" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="32" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="24" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="41" cy="9" r="2.5" fill="#D15B47"/>
      <circle cx="41" cy="17" r="2.5" fill="#4B89C8"/>
    </g>
    <g transform="translate(600, 366) rotate(-2)">
      <rect width="46" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="28" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="12" r="2.8" fill="#D6CFC2"/>
    </g>
    <g transform="translate(522, 418) rotate(2)">
      <rect width="46" height="24" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="28" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="20" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="12" r="2.8" fill="#4EA874"/>
    </g>
    <g transform="translate(578, 424) rotate(-2.5)">
      <rect width="58" height="28" rx="3" fill="#2E251D" stroke="#8C7355" stroke-width="1.3"/>
      <line x1="8" y1="10" x2="36" y2="10" stroke="#8C7B65" stroke-width="1.2"/>
      <line x1="8" y1="17" x2="28" y2="17" stroke="#6E5D4B" stroke-width="1.2"/>
      <circle cx="48" cy="7" r="2.2" fill="#4EA874"/>
      <circle cx="48" cy="14" r="2.2" fill="#D15B47"/>
      <circle cx="48" cy="21" r="2.2" fill="#4B89C8"/>
    </g>

    <!-- Lower-mid -->
    <g transform="translate(536, 476) rotate(-1.5)">
      <rect width="46" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="28" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="22" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="9" r="2.5" fill="#4B89C8"/>
      <circle cx="38" cy="17" r="2.5" fill="#D6CFC2"/>
    </g>
    <g transform="translate(596, 488) rotate(2.5)">
      <rect width="48" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="30" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="40" cy="12" r="2.8" fill="#D15B47"/>
    </g>
    <g transform="translate(518, 536) rotate(1.5)">
      <rect width="52" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="34" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="24" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="43" cy="9" r="2.5" fill="#D6CFC2"/>
      <circle cx="43" cy="17" r="2.5" fill="#4EA874"/>
    </g>
    <g transform="translate(584, 548) rotate(-3)">
      <rect width="46" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="28" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="12" r="2.8" fill="#4B89C8"/>
    </g>

    <!-- Bottom area -->
    <g transform="translate(540, 594) rotate(2)">
      <rect width="50" height="26" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="10" x2="32" y2="10" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="16" x2="24" y2="16" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="41" cy="9" r="2.5" fill="#D15B47"/>
      <circle cx="41" cy="17" r="2.5" fill="#D6CFC2"/>
    </g>
    <g transform="translate(598, 608) rotate(-1.5)">
      <rect width="46" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="28" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="12" r="2.8" fill="#4EA874"/>
    </g>
    <g transform="translate(526, 648) rotate(-2)">
      <rect width="54" height="24" rx="3" fill="#2A221B" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="34" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="26" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="45" cy="8" r="2.5" fill="#4B89C8"/>
      <circle cx="45" cy="16" r="2.5" fill="#D15B47"/>
    </g>
    <g transform="translate(602, 650) rotate(2.5)">
      <rect width="46" height="24" rx="3" fill="#261F19" stroke="#6E5D4B" stroke-width="1.2"/>
      <line x1="8" y1="9" x2="28" y2="9" stroke="#7A6955" stroke-width="1.2"/>
      <line x1="8" y1="15" x2="22" y2="15" stroke="#5A4C3D" stroke-width="1.2"/>
      <circle cx="38" cy="8" r="2.5" fill="#4EA874"/>
      <circle cx="38" cy="16" r="2.5" fill="#4B89C8"/>
    </g>
  </g>

  <!-- Bidirectional hollow arrows: Orientation <-> Shared World <-> Assignments -->
  <g stroke-width="2.4" stroke-linejoin="round">
    <polygon points="310,270 332,256 332,264 483,264 483,256 505,270 483,284 483,276 332,276 332,284"
             fill="#14231B" fill-opacity="0.9" stroke="#4EA874"/>
    <polygon points="310,390 332,376 332,384 483,384 483,376 505,390 483,404 483,396 332,396 332,404"
             fill="#241512" fill-opacity="0.9" stroke="#D15B47"/>
    <polygon points="310,510 332,496 332,504 483,504 483,496 505,510 483,524 483,516 332,516 332,524"
             fill="#131D27" fill-opacity="0.9" stroke="#4B89C8"/>
    <polygon points="310,630 332,616 332,624 483,624 483,616 505,630 483,644 483,636 332,636 332,644"
             fill="#1E1B18" fill-opacity="0.9" stroke="#D6CFC2"/>
  </g>

  <!-- Label clarifying Assignments -> Challenges is shared context, not mandatory linear pipeline -->
  <g text-anchor="middle" fill="#9E8F7B" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="9" font-weight="600" letter-spacing="0.8">
    <text x="715" y="216">SHARED</text>
    <text x="715" y="228">CONTEXT</text>
  </g>

  <!-- Staggered, swapped-height exit arrows: Assignments -> Challenges -->
  <g stroke-width="2.4" stroke-linejoin="round">
    <!-- Red exiting high -->
    <polygon points="665,251 726,251 726,242 749,258 726,274 726,265 665,265"
             fill="#241512" stroke="#D15B47"/>
    <!-- Green exiting upper-mid -->
    <polygon points="665,367 726,367 726,358 749,374 726,390 726,381 665,381"
             fill="#14231B" stroke="#4EA874"/>
    <!-- Ivory exiting lower-mid -->
    <polygon points="665,491 726,491 726,482 749,498 726,514 726,505 665,505"
             fill="#1E1B18" stroke="#D6CFC2"/>
    <!-- Blue exiting low -->
    <polygon points="665,615 726,615 726,606 749,622 726,638 726,629 665,629"
             fill="#131D27" stroke="#4B89C8"/>
  </g>

  <!-- ==================== 5. CHALLENGES (UNIFIED MONOLITH) ==================== -->
  <text x="835" y="175" text-anchor="middle" fill="#D8C9B4" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="14" font-weight="700" letter-spacing="2">CHALLENGES</text>
  <text x="835" y="194" text-anchor="middle" fill="#C89D54" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="10" font-weight="600" letter-spacing="1">CONSEQUENCES</text>

  <rect x="755" y="210" width="160" height="480" rx="6" fill="#1F1915" stroke="#8C7355" stroke-width="2"/>
  <g fill="none" stroke-width="1.5" opacity="0.32">
    <path d="M 762 258 C 825 258, 845 450, 908 450" stroke="#D15B47"/>
    <path d="M 762 374 C 825 374, 845 450, 908 450" stroke="#4EA874"/>
    <path d="M 762 498 C 825 498, 845 450, 908 450" stroke="#D6CFC2"/>
    <path d="M 762 622 C 825 622, 845 450, 908 450" stroke="#4B89C8"/>
  </g>

  <!-- ==================== 6. RIGHT WORLD ARENA ==================== -->
  <rect x="995" y="138" width="250" height="558" rx="10" fill="#1C1713" stroke="#8C7355" stroke-width="2"/>
  <rect x="1002" y="145" width="236" height="544" rx="6" fill="none" stroke="#362C22" stroke-width="1"/>
  <g text-anchor="middle" fill="#F3EAD8" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="14" font-weight="700" letter-spacing="1.4">
    <text x="1120" y="176">THE WORLD</text>
    <text x="1120" y="196" fill="#C4B49E" font-size="12.5" font-weight="600">through gameplay /</text>
    <text x="1120" y="214" fill="#C4B49E" font-size="12.5" font-weight="600">player actions</text>
  </g>
  <line x1="1028" y1="230" x2="1212" y2="230" stroke="#3D3228" stroke-width="1"/>

  <circle cx="1120" cy="450" r="64" fill="url(#nexusGlow)"/>

  <!-- ==================== 7. ONE SHARED WORLD CONDUIT ==================== -->
  <g stroke="#8C7355" stroke-width="1.6" fill="none">
    <path d="M 405 696 L 405 720 L 1120 720 L 1120 696"/>
    <circle cx="405" cy="696" r="3" fill="#C89D54" stroke="none"/>
    <circle cx="1120" cy="696" r="3" fill="#C89D54" stroke="none"/>
  </g>
  <rect x="652" y="707" width="220" height="26" rx="13" fill="#181410" stroke="#8C7355" stroke-width="1.4"/>
  <text x="762" y="724" text-anchor="middle" fill="#E4C99B" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="10.5" font-weight="700" letter-spacing="1.6">ONE SHARED WORLD MODEL</text>

  <!-- ==================== 8. WORKS (6-POINTED STAR) ==================== -->
  <g filter="url(#softGlow)">
    <polygon points="1415,314 1453,384 1533,382 1491,450 1533,518 1453,516 1415,586 1377,516 1297,518 1339,450 1297,382 1377,384"
             fill="#13251B" stroke="#4DC484" stroke-width="3" stroke-linejoin="round"/>
    <polygon points="1415,340 1444,398 1509,396 1475,450 1509,504 1444,502 1415,560 1386,502 1321,504 1355,450 1321,396 1386,398"
             fill="none" stroke="#4DC484" stroke-width="1" opacity="0.35" stroke-linejoin="round"/>
  </g>
  <text x="1415" y="457" text-anchor="middle" fill="#E8F6EE" font-family="'Georgia', 'Times New Roman', serif" font-size="24" font-weight="700" letter-spacing="2.5">WORKS</text>

  <!-- Works XP & intervention inscription -->
  <g text-anchor="middle" font-family="'Inter', 'Segoe UI', system-ui, sans-serif">
    <text x="1415" y="616" fill="#5ED396" font-size="10.5" font-weight="700" letter-spacing="1.4">SOLE SOURCE OF</text>
    <text x="1415" y="632" fill="#5ED396" font-size="10.5" font-weight="700" letter-spacing="1.4">HISTORICAL PROGRESS XP</text>
    <text x="1415" y="652" fill="#9E8F7B" font-size="10" font-weight="600" letter-spacing="0.8">INTERVENTION · DELIVERABLES · IMPACT</text>
  </g>

  <!-- ==================== 9. CONVERGING / ENCOUNTER ARROWS ==================== -->
  <polygon points="915,431 1062,431 1062,412 1106,450 1062,488 1062,469 915,469"
           fill="url(#bronzeGrad)" stroke="#F3D6A4" stroke-width="1.2" stroke-linejoin="round" filter="url(#softGlow)"/>

  <polygon points="1352,431 1178,431 1178,412 1134,450 1178,488 1178,469 1352,469"
           fill="url(#worksGrad)" stroke="#A7F0C7" stroke-width="1.2" stroke-linejoin="round" filter="url(#softGlow)"/>

  <polygon points="1120,432 1132,450 1120,468 1108,450" fill="#FFF2D6" stroke="#C89D54" stroke-width="1.5" filter="url(#softGlow)"/>

  <!-- ==================== 10. FOOTER PHASE BRACKETS ==================== -->
  <g stroke="#4E4134" stroke-width="1.25" fill="none">
    <path d="M 65 752 L 65 762 L 675 762 L 675 752"/>
    <path d="M 755 752 L 755 762 L 915 762 L 915 752"/>
    <path d="M 995 752 L 995 762 L 1545 762 L 1545 752"/>
  </g>
  <g text-anchor="middle" font-family="'Inter', 'Segoe UI', system-ui, sans-serif" font-size="11.5" font-weight="600" letter-spacing="1.6">
    <text x="370" y="786" fill="#9E8F7B">I. SET &amp; SETTING  —  ORIENTATION &amp; SCATTERED ROUTINE POOL</text>
    <text x="835" y="786" fill="#C89D54">II. CONVERGENCE</text>
    <text x="1270" y="786" fill="#5ED396">III. ENCOUNTER  —  HISTORICAL INTERVENTION</text>
  </g>
</svg>
