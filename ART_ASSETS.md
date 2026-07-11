# BurnReward — Art Asset Spec

What to hand off so it drops straight into the app. Decided with Xavier 2026-07-10.

## Universal rules (both sets)

- **Format:** PNG, **transparent background**, **sRGB** color profile.
- **Canvas:** square, art centered with consistent padding across a set.
- **Pixel art stays crisp:** author on a small base grid, then scale up by a
  whole-number factor with **no smoothing** (nearest-neighbor). In-app I render
  with `.interpolation(.none)`, so upscales never blur — provide the largest
  size listed and I downscale cleanly for smaller placements.
- **Dropping in:** the project uses Xcode 16 synchronized folders, so new
  images need **no project setup** — they go in the asset catalog and I
  reference them by name. Filenames matter (see the trophy table).

---

## 1. Tab bar icons

Xavier draws the 4 icons; I build the full-width, edge-to-edge console frame in
SwiftUI (it replaces the system tab bar, bleeds to the bottom, and fits every
iPhone width). **I'll mock up that frame first with placeholder icons** so the
final icon size/slot is exact before you finish them.

- **4 icons:** `HOME`, `LOG`, `FORGE`, `SYSTEM`
- **Size:** **128 × 128 px** each (author on a ~32×32 grid, scale ×4)
- Transparent, square, single color or full art — I can tint the active tab
  green, so a **single icon per tab is enough**.
- **Optional:** a second "selected" variant per icon (e.g. brighter / glow) if
  you want the active state hand-drawn instead of tinted. Name them
  `tab_<name>.png` and `tab_<name>_on.png`.
- Suggested filenames: `tab_home.png`, `tab_log.png`, `tab_forge.png`, `tab_system.png`

---

## 2. Trophy medallions (30)

Whole medallion — frame/ring **and** emblem — on a transparent background. I
drop the code-drawn gold ring and just place your art. **One state per badge is
all you ever draw:** locked badges render the same art as a gray ghost
(desaturated + dimmed in code), so there's no second "locked" set to make.

- **Size:** **256 × 256 px** each (covers the 84 pt detail medallion at @3x;
  author on a 48–64 px grid and scale up)
- Transparent, square, roughly circular medallion centered with even padding so
  the grid reads as a unified set.
- **Naming = the badge's ID:** `badge_<id>.png`. Match these exactly and each
  wires itself up — no code changes needed.

| Filename | Badge | Theme (current placeholder) |
|---|---|---|
| `badge_first_burn.png` | First Burn | first quest · 🔥 |
| `badge_decade.png` | Decade | 10 quests · 🔟 |
| `badge_full_party.png` | Full Party | all 4 core classes · 🎲 |
| `badge_spark.png` | Spark | burn 250+ · ⚡ |
| `badge_inferno.png` | Inferno | burn 500+ · 🌋 |
| `badge_titan.png` | Titan | burn 800+ · 🏔️ |
| `badge_dragon_slayer.png` | Dragon Slayer | burn 1,000+ · 🐉 |
| `badge_long_walk.png` | Long Walk | 30+ min · 🥾 |
| `badge_marathoner.png` | Marathoner | 60+ min · ⏱️ |
| `badge_endurance_tank.png` | Endurance Tank | 90+ min · 🛡️ |
| `badge_foot_soldier.png` | Foot Soldier | 5,000+ steps · 🐾 |
| `badge_trailblazer.png` | Trailblazer | 10,000+ steps · 👣 |
| `badge_long_march.png` | Long March | 15,000+ steps · 🧗 |
| `badge_strategist.png` | Strategist | within 10% of goal · 🧠 |
| `badge_sharpshooter.png` | Sharpshooter | within 5% · 🎯 |
| `badge_needle_threader.png` | Needle Threader | within 2% · 🪡 |
| `badge_week_warrior.png` | Week Warrior | 7-day streak · 📅 |
| `badge_brick_by_brick.png` | Brick by Brick | a quest/week × 4 weeks · 🧱 |
| `badge_double_feature.png` | Double Feature | 2 quests in a day · 🌗 |
| `badge_comeback.png` | Comeback | back after 7+ days · 🔁 |
| `badge_back_from_dead.png` | Back From the Dead | back after 30+ days · 🧟 |
| `badge_multiclass.png` | Multiclass | 3 classes in a week · 🧩 |
| `badge_class_master.png` | Class Master | 10 quests, one class · 🧙 |
| `badge_dawn_raid.png` | Dawn Raid | start before 7 AM · 🌅 |
| `badge_night_owl.png` | Night Owl | finish after 9 PM · 🦉 |
| `badge_sweet_ten.png` | Sweet Ten | win 10 rewards · 🍭 |
| `badge_paid_in_sweat.png` | Paid in Sweat | win 25 rewards · 💰 |
| `badge_combo_king.png` | Combo King | two-reward combo · 👑 |
| `badge_centurion.png` | Centurion | 100 quests · 💯 |
| `badge_legend.png` | Legend | 250 quests · 🏛️ |

The emoji are the current in-app placeholders — they tell you each badge's
theme; your medallion replaces them. Source of truth for names/requirements is
`BadgeCatalog` in `QuestModels.swift` (if a badge is ever added, add a row here).
