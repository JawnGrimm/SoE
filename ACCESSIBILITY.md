# Accessibility Standards

*Scribe of Eras* aims for WCAG 2.2 Level AA-equivalent presentation and interaction where applicable to a desktop Godot game. These standards are design and implementation requirements, not a claim of formal certification.

## Readability and contrast

- Normal text must achieve at least **4.5:1** contrast against its actual background.
- Large text (at least 18 pt / 24 px, or 14 pt / 18.7 px when bold) must achieve at least **3:1**.
- Essential UI boundaries, focus indicators, icons, and state indicators must achieve at least **3:1** against adjacent colors.
- Never communicate meaning by color alone. Pair color with text, shape, icon, or an explicit state label.
- Prefer clear, high-contrast text over decorative texture. Text placed on clay, wood, parchment, or portrait art must use a sufficiently opaque backing or scrim.
- Default body/evidence text should be **14 px or larger** at the intended reference resolution. Dense secondary labels should remain at least **12 px**, with no essential information hidden in smaller text. Scale gracefully with window size and UI scale.
- Avoid long all-caps passages, low-contrast muted text, excessive italics, and text over busy backgrounds. Use sentence case for spoken lines and prompts.

## Keyboard and focus

- Every interactive control must be reachable and operable with keyboard alone.
- Establish a predictable focus order matching the visual reading order; avoid focus traps.
- Provide a visible, high-contrast focus indicator that is not conveyed by color alone (for example, a clear outline or raised border).
- Support standard keyboard activation: Enter/Space for buttons, arrows for grouped controls where appropriate, Escape to close overlays or return when safe.
- When an overlay opens, move focus to its heading or first meaningful control. When it closes, restore focus to the control that opened it.
- Do not steal focus during routine updates or turn transitions.
- The Work Queue must have a keyboard-accessible action equivalent to clicking the archive stack. Decorative props must not enter the focus order.
- Disabled controls must remain understandable: expose why an action is unavailable in adjacent text or a tooltip, and do not make disabled state depend only on dimming.

## Pointer, touch, and input targets

- Interactive targets should be at least **44 × 44 px** where practical; never make critical actions tiny or tightly packed.
- Provide clear hover, pressed, focused, disabled, and selected states. Hover must not be the only way to reveal information or preview consequences.
- Avoid requiring precision dragging. Provide button or keyboard alternatives for desk props, survey controls, and queue access.

## Motion and feedback

- Use short, purposeful motion to communicate physical interaction, not to delay the player.
- Provide a reduced-motion setting or global motion scale. Under reduced motion, remove or shorten movement, screen shake, pulsing, and repeated animation while preserving the state change and feedback.
- Do not use flashing or rapid high-contrast blinking.
- Audio cues (seal, stylus, music, dialogue) must have visual equivalents. Important information must never be audio-only.
- Avoid playing overlapping UI sounds for repeated actions; respect audio volume settings.

## Content, labels, and assistive descriptions

- Give controls clear visible names and useful tooltips. Tooltips supplement, but never replace, visible labels or keyboard access.
- Icon-only controls need an accessible name and a tooltip.
- Evidence, spoken quotes, resource values, debt, audit exposure, and inquiry count must be presented as readable text, not only as texture, glyph, animation, or color.
- Cuneiform marks are atmospheric and historical notation; pair each mark with a plain-language action label and a descriptive tooltip. Do not require the player to recognize a glyph to understand an action.
- Use readable text for dates, BCE/CE, locations, office, and queue category. Avoid unexplained abbreviations and raw internal IDs/metrics.
- Keep narrative copy concise, structured, and scannable. Use headings and spacing to separate prompt, evidence, choices, and status.

## UI layout and scaling

- The interface must remain usable at common desktop resolutions and when resized. Avoid fixed heights that clip text; containers should expand or scroll as needed.
- Keep the most important current prompt and available actions visible without requiring the player to hunt through the sidebar.
- Character creation and regional survey should receive the available workspace rather than being squeezed by hidden evidence panels.
- Maintain a consistent hierarchy: header/status, primary prompt and choices, evidence/characters, queue and secondary compound information.
- Test long names, long quotes, translated strings, missing portraits, zero/negative resource values, and empty institutional inventories.

## Godot implementation and verification

- Prefer Godot's built-in focus/navigation properties and theme overrides; keep focus logic in reusable UI components.
- Use `focus_mode = Control.FOCUS_ALL` for actionable controls and `FOCUS_NONE` for decorative controls.
- Set accessible_name/accessible_description when supported by the project's Godot version and control type; otherwise provide visible labels and tooltips.
- Do not change simulation rules, assignment resolution, world state, or save schema to implement accessibility.
- Verify focus order and overlay focus restoration manually in a running build. Headless tests can validate state and signals, but cannot certify visual contrast, readability, or actual keyboard navigation.
- Run the full headless test suite and editor import validation after UI changes; record manual visual checks separately from automated results.
