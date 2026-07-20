import SwiftUI

// Social P3 — the weekly XP leaderboard (mockup draft, 2026-07-20). Framed as
// the party's ⚔️ WEEKLY CHALLENGE rather than a "leaderboard": one screen that
// is both Xavier's ⚔️ CHALLENGE button and the friends board.
//
// Health guardrail, load-bearing: ranked by **XP earned this week**, never raw
// calories or heart rate. XP already bakes in precision + type factor (v2.1),
// so the thing being competed on is skill, not max burn. It's a weekly
// aggregate that resets, so rest days never cost a place — the copy says so.

/// One person's standing this week. `weeklyXP` is derived on each device from
/// that week's quests (XPEngine) and posted opt-in; nothing raw travels.
struct LeaderboardEntry: Identifiable, Equatable {
    let id: UUID
    let username: String
    let level: Int
    let title: String
    let weeklyXP: Int
    var isMe: Bool = false

    var display: String { isMe ? "YOU" : "@\(username)" }
}

/// Medal treatment for the top three; everyone else is a plain rank number.
/// Gold reuses the theme token; silver/bronze are mid-tones that read on both
/// the cream and the dark surface (BRTheme's own light/dark init is private).
private enum Medal {
    static let gold   = BRTheme.gold
    static let silver = Color(red: 0.62, green: 0.65, blue: 0.71)
    static let bronze = Color(red: 0.72, green: 0.47, blue: 0.24)

    static func color(forRank rank: Int) -> Color? {
        switch rank {
        case 1: gold
        case 2: silver
        case 3: bronze
        default: nil
        }
    }
}

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    /// Whether the player has opted into posting their weekly XP. Off → they
    /// can see the board but appear nowhere on it, and get the join prompt.
    let isParticipating: Bool
    let resetText: String
    let onJoin: () -> Void
    let onRecruit: () -> Void

    /// Highest XP first; ties break on name so the order is stable.
    private var ranked: [LeaderboardEntry] {
        entries.sorted {
            $0.weeklyXP != $1.weeklyXP ? $0.weeklyXP > $1.weeklyXP
                                       : $0.username < $1.username
        }
    }

    private var topXP: Int { ranked.first?.weeklyXP ?? 0 }

    private var myRank: Int? {
        ranked.firstIndex { $0.isMe }.map { $0 + 1 }
    }

    var body: some View {
        if entries.filter({ !$0.isMe }).isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    banner
                    if let myRank { yourStanding(rank: myRank) }
                    else if !isParticipating { joinPrompt }
                    standings
                    footnote
                }
                .padding(16)
            }
        }
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("⚔️").font(.system(size: 20))
                Text("WEEKLY CHALLENGE")
                    .font(.pixel(15))
                    .foregroundStyle(BRTheme.gold)
            }
            Text("Top the party in XP")
                .font(.pixel(8))
                .foregroundStyle(BRTheme.mutedOnDark)
            Text(resetText)
                .font(.pixel(7))
                .foregroundStyle(BRTheme.expFill)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(BRTheme.expFill.opacity(0.15)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BRTheme.darkIsland)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(BRTheme.gold.opacity(0.55), lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly Challenge. Top the party in XP. \(resetText).")
    }

    // MARK: - Your standing (pinned)

    private func yourStanding(rank: Int) -> some View {
        HStack(spacing: 14) {
            rankBadge(rank, big: true)
            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR RANK")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.mutedOnDark)
                Text(standingLine(rank))
                    .font(.pixel(10))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranked[rank - 1].weeklyXP)")
                    .font(.pixel(16))
                    .foregroundStyle(BRTheme.expFill)
                Text("XP THIS WEEK")
                    .font(.pixel(6))
                    .foregroundStyle(BRTheme.mutedOnDark)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BRTheme.darkIsland)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BRTheme.gold, lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your rank: \(rank) of \(ranked.count). \(ranked[rank - 1].weeklyXP) XP this week.")
    }

    /// The one motivating line — how far to the next place up, or that you're
    /// on top. Never a scolding, and never about raw effort.
    private func standingLine(_ rank: Int) -> String {
        guard rank > 1 else { return "You're leading the party" }
        let ahead = ranked[rank - 2]
        let gap = ahead.weeklyXP - ranked[rank - 1].weeklyXP
        return gap > 0 ? "\(gap) XP behind @\(ahead.username)" : "Tied for \(ordinal(rank))"
    }

    // MARK: - Standings list

    private var standings: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelSectionLabel(text: "PARTY STANDINGS")
            VStack(spacing: 6) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                    row(rank: index + 1, entry: entry)
                }
            }
        }
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        let fraction = topXP > 0 ? Double(entry.weeklyXP) / Double(topXP) : 0
        return HStack(spacing: 12) {
            rankBadge(rank, big: false)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.display)
                        .font(.subheadline.weight(entry.isMe ? .bold : .semibold))
                        .foregroundStyle(entry.isMe ? BRTheme.gold : BRTheme.textPrimary)
                        .lineLimit(1)
                    Text("LVL \(entry.level)")
                        .font(.pixel(6))
                        .foregroundStyle(BRTheme.textMuted)
                }
                // Relative XP bar — the visual pecking order at a glance.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BRTheme.track)
                        Capsule()
                            .fill(Medal.color(forRank: rank) ?? BRTheme.greenFG)
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.weeklyXP)")
                    .font(.pixel(11))
                    .foregroundStyle(entry.isMe ? BRTheme.gold : BRTheme.textPrimary)
                Text("XP")
                    .font(.pixel(6))
                    .foregroundStyle(BRTheme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(entry.isMe ? BRTheme.gold.opacity(0.10) : BRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(entry.isMe ? BRTheme.gold.opacity(0.6) : BRTheme.cardBorder,
                                      lineWidth: entry.isMe ? 1.5 : 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ordinal(rank)) place, \(entry.isMe ? "you" : entry.username), level \(entry.level), \(entry.weeklyXP) XP.")
    }

    /// Rank chip: a champion's dark medallion with a gold crown for #1, a
    /// medal-tinted coin with its number for #2–3, a plain number below. #1
    /// gets the dark backing on purpose — a crown emoji washed out against the
    /// gold coin in light mode; a vector crown on near-black reads in both.
    private func rankBadge(_ rank: Int, big: Bool) -> some View {
        let medal = Medal.color(forRank: rank)
        let side: CGFloat = big ? 46 : 34
        return ZStack {
            if rank == 1 {
                Circle()
                    .fill(BRTheme.darkIsland)
                    .overlay(Circle().strokeBorder(Medal.gold, lineWidth: 1.5))
                Image(systemName: "crown.fill")
                    .font(.system(size: big ? 18 : 13))
                    .foregroundStyle(Medal.gold)
            } else {
                Circle()
                    .fill((medal ?? BRTheme.textMuted).opacity(medal == nil ? 0.12 : 0.20))
                    .overlay(Circle().strokeBorder(medal ?? BRTheme.cardBorder,
                                                   lineWidth: medal == nil ? 1 : 1.5))
                Text("\(rank)")
                    .font(.pixel(big ? 16 : 12))
                    .foregroundStyle(medal ?? BRTheme.textMuted)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    // MARK: - Prompts + footnote

    private var joinPrompt: some View {
        VStack(spacing: 10) {
            Text("YOU'RE WATCHING FROM THE STANDS")
                .font(.pixel(9))
                .foregroundStyle(BRTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Post your weekly XP to take your place in the party's challenge. Only your party sees it, and only the XP number — never your workouts.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
            Button(action: onJoin) {
                Text("ENTER THE CHALLENGE")
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.onNeonGreen)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.neonGreen))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(BRTheme.cardBorder, lineWidth: 1))
        )
    }

    private var footnote: some View {
        Text("Ranked by XP earned this week — skill, not raw burn. Resets Monday, so rest days never cost you a place.")
            .font(.caption2)
            .foregroundStyle(BRTheme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 2)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("⚔️").font(.system(size: 40))
                    .padding(.top, 40)
                Text("NO CHALLENGERS YET")
                    .font(.pixel(12))
                    .foregroundStyle(BRTheme.textPrimary)
                Text("Recruit a friend and the weekly challenge begins — whoever earns the most XP tops the party.")
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button(action: onRecruit) {
                    Label("RECRUIT A FRIEND", systemImage: "person.badge.plus")
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.neonGreen))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"; case 2: "2nd"; case 3: "3rd"
        default: "\(n)th"
        }
    }
}

// MARK: - Mockup fixtures (`-BRDemoLeaderboard`, `-BRDemoLeaderboardJoin`)

enum DemoLeaderboard {
    static let myID = UUID()

    static let entries: [LeaderboardEntry] = [
        LeaderboardEntry(id: UUID(), username: "mika_runs", level: 8, title: "DUNGEON DINER", weeklyXP: 2_140),
        LeaderboardEntry(id: UUID(), username: "ana_walks", level: 11, title: "FEAST PHANTOM", weeklyXP: 1_760),
        LeaderboardEntry(id: myID, username: "xavier_pr", level: 6, title: "SNACK SLAYER", weeklyXP: 1_505, isMe: true),
        LeaderboardEntry(id: UUID(), username: "carlos_lifts", level: 4, title: "TREAT APPRENTICE", weeklyXP: 980),
        LeaderboardEntry(id: UUID(), username: "pedro_bikes", level: 3, title: "SNACK ROOKIE", weeklyXP: 615),
    ]

    /// Same party, but the player hasn't opted in — no `isMe` row.
    static let watching: [LeaderboardEntry] = entries.map {
        LeaderboardEntry(id: $0.id, username: $0.username, level: $0.level,
                         title: $0.title, weeklyXP: $0.weeklyXP, isMe: false)
    }
}

#Preview("Leaderboard — in it") {
    LeaderboardView(entries: DemoLeaderboard.entries, isParticipating: true,
                    resetText: "RESETS IN 3 DAYS", onJoin: {}, onRecruit: {})
        .background(BRTheme.bg)
}

#Preview("Leaderboard — watching") {
    LeaderboardView(entries: DemoLeaderboard.watching, isParticipating: false,
                    resetText: "RESETS IN 3 DAYS", onJoin: {}, onRecruit: {})
        .background(BRTheme.bg)
}
