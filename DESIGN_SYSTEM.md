# BurnReward — Design System

Living reference for all visual and brand decisions. Update this when the code changes.  
Source of truth: `Theme.swift` for color/font tokens.

---

## 1. Brand Identity

**App name:** BurnReward  
**Tagline:** Earn your treat. Burn to unlock.  
**Concept:** A calorie-burning RPG for Apple Watch. Pick a food reward, work out, earn it.  
**Personality:** Energetic · Gamified · Honest · No-fluff  
**NOT:** Cold fitness tracker · Guilt-trip health app · Corporate wellness tool

---

## 2. Color Palette

All tokens are defined in `BurnReward Watch App/Theme.swift`.

### Core tokens

| Token | SwiftUI | Hex | Usage |
|---|---|---|---|
| `Theme.bg` | `Color(red:0.012, green:0.039, blue:0.016)` | `#030A04` | Screen background — near-black with a hint of dark green |
| `Theme.card` | `Color(white: 0.06)` | `#0F0F0F` | Stat cells, overlays, card surfaces |
| `Theme.green` | `Color(red:0, green:1, blue:0.53)` | `#00FF88` | Primary action color — "EARNED!", CTA button fill, progress % |
| `Theme.yellow` | `Color(red:1, green:0.84, blue:0)` | `#FFD700` | EXP bar fill + border, reward name text, "EXP" label |
| `Theme.orange` | `Color(red:1, green:0.42, blue:0.21)` | `#FF6B35` | Calories burned, stat values, mid-priority data |
| `Theme.red` | `Color(red:1, green:0.13, blue:0.27)` | `#FF2244` | Heart rate — danger/effort signal |
| `Theme.blue` | `Color(red:0, green:0.67, blue:1)` | `#00AAFF` | Timer, steps — cool/informational data |
| `Theme.muted` | `Color(red:0.38, green:0.38, blue:0.63)` | `#6060A0` | Secondary labels, disabled states |

### Derived / one-off values used in code

| Purpose | Value | Where used |
|---|---|---|
| Stat cell background | `Color(white: 0.08)` | `WorkoutView`, `EarnedView` — slightly lighter than card |
| CTA button shadow | `#007744` (dark green) | `PixelButtonStyle` — 3px press-depth shadow |
| Milestone overlay bg | `.black.opacity(0.85)` | `milestoneOverlay` in `WorkoutView` |
| EXP bar empty track | `Color(white: 0.1)` | `expBar` in `WorkoutView` |
| Scanline overlay | `.black.opacity(0.18)` | `ScanlineOverlay` — 3px gap CRT effect |
| Disabled button fg | `Color(white: 0.35)` | `PixelButtonStyle` disabled state |
| Disabled button bg | `Color(white: 0.1)` | `PixelButtonStyle` disabled state |

### Semantic meaning

- **Green = success / action** — earns rewards, confirms, primary CTA
- **Yellow = progress / XP** — the EXP bar is the game's heartbeat; yellow owns it
- **Orange = effort output** — calories burned; warm, energizing
- **Red = heart / intensity** — heart rate only; keeps its meaning unambiguous
- **Blue = time / steps** — neutral informational data; cool contrast
- **Muted purple = secondary** — labels, units, supporting text

### Marketing / external palette

For infographics, social posts, and App Store assets — a slight adjustment from
the in-app palette to read better on white/light backgrounds:

| Name | Hex | Notes |
|---|---|---|
| Flame orange | `#FF6B00` | Slightly deeper than `Theme.orange`; works on dark and light |
| Ember amber | `#FFB347` | Warmer than `Theme.yellow`; EXP bar analog for marketing |
| Near-black bg | `#0F0F0F` | Safe dark background for marketing dark mode |
| Surface | `#1C1C1E` | Apple dark grouped background; card surfaces in marketing |
| Body text | `#E5E5E5` | Off-white on dark backgrounds |
| Muted text | `#8E8E93` | Apple gray; labels, secondary copy |
| Divider | `#2C2C2E` | Subtle rules and borders |
| Success | `#30D158` | Apple green; checkmarks, completion states |

---

## 3. Typography

### In-app (watchOS)

**Primary typeface:** Press Start 2P (`PressStart2P-Regular`)  
**Access via:** `Font.pixel(_ size: CGFloat)` — defined in `Theme.swift`  
**Fallback:** System monospaced (automatic if font fails to load)  
**Character:** 8-bit pixel font — reinforces the RPG aesthetic on every screen

#### Size scale

| Size | Usage | Example |
|---|---|---|
| `pixel(5)` | Unit labels, secondary descriptors | "BPM", "STEPS", "LEFT" |
| `pixel(6)` | Navigation, tertiary labels | "BACK" button |
| `pixel(7)` | Small body text, "EXP" label | Reward description |
| `pixel(8)` | Body / timer | Timer display, calorie counter |
| `pixel(9)` | Emphasis labels | "★ EARNED! ★", victory screen |
| `pixel(10)` | Combo separator | "+" between combo rewards |
| `pixel(11)` | Primary stat values | Progress %, heart rate, steps |
| `pixel(13)` | Large stat values | Calories burned/left cells |

**System font** (`.system(size:)`) is used for:
- Emoji rendering (reward emoji, heart symbol) — pixel font does not render emoji
- Sizes: 11px (steps emoji), 12px (heart ♥), 28–36px (reward emoji mid-workout), 32px (milestone overlay emoji), 52px (victory screen single reward)

### Marketing / external

**Primary:** SF Pro Display (Apple) · fallback: Inter  
**Body:** SF Pro Text · fallback: Inter  
**Never use:** Press Start 2P in marketing — it reads too small and retro for App Store screenshots and social; keep it on-device where it's intentional  
**Never use:** Serif, script, or condensed typefaces

#### Marketing size hierarchy

| Role | Size | Weight | Color |
|---|---|---|---|
| App name / hero | 28–32px | Heavy | Ember amber `#FFB347` |
| Step label | 10px ALL CAPS + 0.12em tracking | Medium | Flame orange `#FF6B00` |
| Step title | 18–20px | Semibold | Body text `#E5E5E5` |
| Step body | 14–15px, line-height 1.5 | Regular | Muted `#8E8E93` |
| Pill / chip | 12px | Medium | Body text `#E5E5E5` |
| Footer / legal | 11px | Regular | Muted `#8E8E93` |

---

## 4. Components

### 4a. PixelButtonStyle (primary CTA)
Defined in `PixelButtonStyle.swift`.

- Background: `Theme.green` (#00FF88)
- Text: `.black`, `pixel(9)`
- 3px press-depth shadow: `#007744` (shifts to 0px on press)
- Disabled: bg `Color(white: 0.1)`, text `Color(white: 0.35)`
- Animation: `.easeInOut(duration: 0.08)` on press

### 4b. Stat cell
Used in `WorkoutView` and `EarnedView`.

- Background: `Color(white: 0.08)`
- Corner radius: 4px
- Padding vertical: 5px
- Value text: `pixel(9–13)`, tinted by data type (see color meanings above)
- Label text: `pixel(5)`, `.secondary`
- Always uses `.minimumScaleFactor(0.5)` + `.lineLimit(1)` to prevent overflow

### 4c. EXP bar
- Height: 12px, corner radius: 2px
- Track border: `Theme.yellow`, 1.5px stroke
- Track fill (empty): `Color(white: 0.1)`
- Fill: `Theme.yellow`, animates with `.easeInOut(duration: 0.3)`
- Combo marker: white 50% opacity, 2px wide vertical line at first reward's calorie ratio
- Labels: "EXP" in `Theme.yellow pixel(7)` left, progress % in `Theme.green pixel(11)` right

### 4d. Milestone overlay
- Semi-transparent card: `.black.opacity(0.85)`, `cornerRadius(8)`, 12px padding
- Reward emoji: 32px system
- "EARNED!" text: `pixel(9)`, `Theme.green`
- "KEEP GOING →": `pixel(6)`, `.secondary`
- Transition: `.scale.combined(with: .opacity)`, `.easeOut(duration: 0.2)`

### 4e. Scanline overlay
`ScanlineOverlay` — 1px black lines every 3px at 18% opacity.  
Applied full-screen on top of content. Non-interactive (`allowsHitTesting(false)`).  
Purpose: CRT retro effect, matches the landing page aesthetic.

### 4f. Marketing card (infographics)
- Background: `#1C1C1E`, border-radius 16px
- Left accent bar: 3px vertical, `#FF6B00`
- Step badge: 28px circle, filled `#FF6B00`, number in `#0F0F0F` bold
- Padding: 16px all sides
- No drop shadows — flat dark surfaces only

### 4g. Pill / chip (marketing)
- Border-radius: 100px (fully round)
- Border: `#2C2C2E`
- Background: `#1C1C1E`
- Text: 12px Medium, `#E5E5E5`

---

## 5. Spacing

### watchOS (in-app)
| Token | Value | Usage |
|---|---|---|
| `spacing.xs` | 3px | EXP bar label-to-bar gap |
| `spacing.sm` | 4px | Stat cell internal spacing |
| `spacing.md` | 6px | Between cells in a row, between screen sections |
| `spacing.lg` | 10px | Between major VStack sections |
| `padding.h` | 6px | Horizontal screen padding |
| `padding.cell.v` | 5px | Stat cell vertical padding |

### Marketing
| Usage | Value |
|---|---|
| Card padding | 16px |
| Card gap | 12px |
| Section gap | 24px |
| Pill padding | 8px vertical, 14px horizontal |
| Screen edge margin | 20px |

---

## 6. Motion & Haptics

### In-app animations

| Animation | Spec | Trigger |
|---|---|---|
| EXP bar fill | `.easeInOut(duration: 0.3)` | Calorie update |
| Victory emoji pulse | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` | `EarnedView.onAppear` |
| Milestone overlay appear | `.easeOut(duration: 0.2)` with `.scale + .opacity` | 25/50/75% crossed |
| Button press depth | `.easeInOut(duration: 0.08)` shadow shift | `isPressed` changes |

### Haptics (WKHapticType)
| Moment | Haptic | Notes |
|---|---|---|
| 25% milestone | `.notification` | First buzz |
| 50% milestone | `.notification` | Mid-point check-in |
| 75% milestone | `.notification` | Almost there signal |
| 100% / Victory | `.success` | Distinct from milestone buzzes |

---

## 7. watchOS Layout Constraints

These are hard constraints from the Apple Watch display, not design preferences.

| Constraint | Value |
|---|---|
| Display widths | 40mm: 162pt · 41mm: 176pt · 44mm: 184pt · 45mm: 198pt |
| Target device | Apple Watch SE (40mm) — design to this, test up to 45mm |
| Safe horizontal padding | 6pt (our standard), Apple recommends ~4–8pt |
| Max font size legible | `pixel(13)` is near the ceiling for pixel font readability |
| Scrollable screens | Always use `ScrollView` — content taller than ~160pt will clip |
| `minimumScaleFactor` | Required on any numeric value that can overflow (steps, calories) |
| Avoid | Fixed-width cells without `Spacer` — breaks on smaller watches |

---

## 8. Icon & Brand Assets

| Asset | Spec | Location |
|---|---|---|
| App icon | 1024×1024px, pixel-art flame | `BurnReward Watch App/Assets.xcassets/AppIcon.appiconset` |
| Complication icon | Xcode-generated from app icon | `BurnRewardComplication` target |
| Flame character | Pixel-art, orange/red, on dark bg | Master file on Xavier's machine |
| No wordmark exists yet | Text-based "BurnReward" in Press Start 2P serves as wordmark in-app | — |

### Icon usage rules
- Never place the flame on a white or light background in marketing
- Minimum display size: 44×44pt (tap target minimum)
- For social/marketing: use on `#0F0F0F` or `#1C1C1E` backgrounds only

---

## 9. Voice & Tone

### UI copy rules
- **ALL CAPS for labels and actions** — matches pixel font aesthetic: "EARNED!", "NEW GOAL", "BACK"
- **Sentence case for descriptions** — reward descriptions are casual, friendly: "Bakery-fresh", "NYC-style"
- **Short and punchy** — every string on a watch screen fights for pixels; cut ruthlessly
- **Game language, not fitness language** — "EXP", "EARNED", "QUEST", "★" — not "calories", "goal met", "session complete"
- **No guilt** — never frame calorie deficit as punishment; BurnReward earns, never restricts

### Marketing copy rules
- Speak to the user's motivation: the reward, not the workout
- Lead with the reward: "Earn a burrito" beats "burn 980 calories"
- Casual, personal — written like a text from a friend, not a brand
- Avoid: "wellness", "journey", "transform", "lifestyle"
- Emojis allowed in marketing (🔥 🍕 ⌚) — never in-app UI (pixel font + emoji don't mix)

---

## 10. App Store & Marketing Specs

| Asset | Spec |
|---|---|
| Watch screenshots | 410×502px (Apple Watch Ultra 2 / Series 9 display size) |
| Screenshot count | 4–5 required by App Store |
| Screenshot bg | `#030A04` (match in-app bg) or `#0F0F0F` (marketing dark) |
| Marketing infographic width | 390px (iPhone 14/15 screen width), export @2x (780px) |
| Tester onboarding infographic | Dark bg, vertical, mobile-first — designed for iMessage sharing |

---

## 11. What We Don't Use

| Element | Why not |
|---|---|
| White or light backgrounds | Breaks the dark RPG aesthetic; looks like a generic health app |
| Blue as a brand color | Clashes with Apple's default blue system UI |
| Drop shadows on cards | Flat dark surfaces are the system; shadows add noise |
| More than 2 font weights per screen section | Pixel font is already high-contrast; mixing weights creates chaos |
| Gradients on backgrounds | Flat only; gradients only on EXP bar fill and hero text |
| Serif or script typefaces | Wrong register entirely |
| Mascots or cartoon illustrations | Not the tone; emoji + pixel art does all the personality work needed |

---

*Last updated: 2026-06-20 · Source file: `BurnReward Watch App/Theme.swift`*
