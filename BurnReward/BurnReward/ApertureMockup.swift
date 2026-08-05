import SwiftUI

// MOCKUP — not production. Launch with `-BRDemoAperture`.
//
// The aperture fix makes BurnReward count every workout in Apple Health, not
// just the ones its own watch app recorded (LAUNCH_SCOPE.md). That raises three
// visible questions this screen exists to answer, and every option below is a
// real draft rather than a picture of one:
//
//   1. What does a workout with no reward attached look like in the LOG?
//   2. Do we show WHERE it came from, and where?
//   3. How does the x0.8 factor appear on the XP receipt without reading as a
//      punishment for training outside the app?
//
// Delete this file once Xavier locks the answers and the real views absorb them.

struct ApertureMockupView: View {
    /// Paged only so each half fits one screenshot: `-BRDemoAperture` shows the
    /// LOG and the naming options, `-BRDemoAperture2` the receipt and detail.
    var page: Int = 1

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if page == 1 { pageOne } else { pageTwo }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var pageOne: some View {
                    section("1 · THE LOG ROW") {
                        VStack(spacing: 0) {
                            mockRow(
                                emoji: "🌯",
                                title: "Burrito Supreme",
                                subtitle: "Jul 12 · Run · 34 min · 412 cal",
                                xp: 498,
                                tag: nil,
                                sourceChip: nil
                            )
                            divider
                            mockRow(
                                emoji: "🏃",
                                title: "Run",
                                subtitle: "Jul 13 · Strava · 28 min · 305 cal",
                                xp: 244,
                                tag: "SIDE QUEST",
                                sourceChip: nil
                            )
                            divider
                            mockRow(
                                emoji: "🚴",
                                title: "Ride",
                                subtitle: "Jul 13 · 52 min · 486 cal",
                                xp: 389,
                                tag: nil,
                                sourceChip: "GARMIN"
                            )
                        }
                        .brCard(padding: 14)

                        caption("Row 1 is today's quest row, unchanged, for reference. Row 2 carries the kind as a tag and the source inline. Row 3 carries the source as a chip and drops the tag. The subtitle already runs long at large Dynamic Type — it can hold the source or the type, not comfortably both.")
                    }

                    section("2 · WHAT WE CALL A WORKOUT WITH NO REWARD") {
                        HStack(spacing: 8) {
                            tag("SIDE QUEST", BRTheme.blueFG)
                            tag("ROAMING", BRTheme.orangeFG)
                            tag("FREE RUN", BRTheme.greenFG)
                        }
                        HStack(spacing: 8) {
                            tag("LOGGED", BRTheme.textMuted)
                            Text("…or no tag at all — the missing reward emoji already says it")
                                .font(.footnote)
                                .foregroundStyle(BRTheme.textMuted)
                        }
                        caption("SIDE QUEST is the one that means the right thing in RPG grammar: it earns XP, it counts, it is not the main line, and it does not hand you the story reward. That maps exactly onto the locked rule — foreign workouts earn everything except the treat.")
                    }
    }

    @ViewBuilder
    private var pageTwo: some View {
                    section("3 · THE XP RECEIPT") {
                        Text("TREATMENT A — the factor as a deduction")
                            .font(.pixel(9))
                            .foregroundStyle(BRTheme.textMuted)
                        VStack(spacing: 0) {
                            receiptRow("Base · 1 XP per calorie", "305")
                            receiptRow("Intensity ×1.1", "+31", BRTheme.orangeFG)
                            receiptRow("Outside workout ×0.8", "−68", BRTheme.alertRed)
                            receiptTotal(268)
                        }
                        .brCard(padding: 0)

                        Text("TREATMENT B — the factor as a rate")
                            .font(.pixel(9))
                            .foregroundStyle(BRTheme.greenFG)
                        VStack(spacing: 0) {
                            receiptRow("Base · 0.8 XP per calorie", "244")
                            receiptRow("Intensity ×1.1", "+24", BRTheme.orangeFG)
                            receiptTotal(268)
                            HStack(spacing: 6) {
                                Text("⚔️").font(.system(size: 11))
                                Text("Run a quest in BurnReward to earn at the full rate.")
                                    .font(.caption)
                                    .foregroundStyle(BRTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                        }
                        .brCard(padding: 0)

                        caption("Identical arithmetic — both land on 268. The difference is entirely in the reading. A red −68 tells a tester that BurnReward docked them for going on a run, which is the exact resentment the aperture fix exists to remove. A 0.8 rate states the rule plainly and turns the same gap into a reason to run a quest. It also preserves the XP v2.1 invariant in CLAUDE.md — every factor ≥ 1, every bonus ≥ 0, so re-derived history can only ever level a player up.")
                    }

                    section("4 · THE DETAIL VIEW") {
                        VStack(spacing: 0) {
                            detail("Date", "Jul 13, 2026 at 7:12 AM")
                            detail("Workout", "Run")
                            detail("Recorded by", "Strava")
                            detail("Distance", "5.2 km")
                            detail("Duration", "28:04")
                            detail("Avg heart rate", "148 BPM")
                            detail("Steps", "6,204")
                            detail("Calories burned", "305", isLast: true)
                        }
                        .brCard(padding: 0)

                        caption("Two new rows: RECORDED BY (the trust line — testers want to see the app noticed their Garmin) and DISTANCE, which arrives free with the aperture and covers most of tester item 1. No reward, no goal, no EARNED chip — the detail simply has less to say, and does not pretend otherwise.")
                    }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("APERTURE MOCKUP")
                .font(.pixel(13))
                .foregroundStyle(BRTheme.greenFG)
            Text("How a workout BurnReward didn't record shows up in the game.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
        }
        .padding(.bottom, 2)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: title)
            content()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(BRTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var divider: some View {
        Rectangle().fill(BRTheme.divider).frame(height: 1).padding(.vertical, 4)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.pixel(8))
            .foregroundStyle(color)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color, lineWidth: 1)
            )
    }

    private func mockRow(emoji: String, title: String, subtitle: String,
                         xp: Int, tag tagText: String?, sourceChip: String?) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(1)
                    if let sourceChip {
                        Text(sourceChip)
                            .font(.pixel(7))
                            .foregroundStyle(BRTheme.textMuted)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(BRTheme.track)
                            )
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("+\(xp.formatted()) XP")
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.yellowFG)
                if let tagText {
                    Text(tagText)
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.blueFG)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func receiptRow(_ label: String, _ value: String,
                            _ color: Color = BRTheme.textPrimary) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                Spacer()
                Text(value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Rectangle().fill(BRTheme.divider).frame(height: 1).padding(.leading, 14)
        }
    }

    private func receiptTotal(_ total: Int) -> some View {
        HStack {
            Text("TOTAL")
                .font(.pixel(11))
                .foregroundStyle(BRTheme.textPrimary)
            Spacer()
            Text("+\(total.formatted()) XP")
                .font(.pixel(12))
                .foregroundStyle(BRTheme.yellowFG)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func detail(_ label: String, _ value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                Spacer()
                Text(value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BRTheme.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if !isLast {
                Rectangle().fill(BRTheme.divider).frame(height: 1).padding(.leading, 14)
            }
        }
    }
}

#Preview("Aperture mockup — log + naming") {
    ApertureMockupView(page: 1)
}

#Preview("Aperture mockup — receipt + detail") {
    ApertureMockupView(page: 2)
}
