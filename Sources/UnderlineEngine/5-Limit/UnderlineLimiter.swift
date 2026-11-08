import Foundation

/// An underline that passed pick, confirm and the guards, with the score the limiter ranks it by.
struct KeptUnderline: Sendable, Hashable {
    let underline: Underline
    /// The reference's unscaled search score (confirm is yes/no, so it can't rank).
    let score: Double
}

/// Density (spec §5.6): at most `maxPerParagraph` per paragraph, best first, never two overlapping phrases.
/// Per paragraph only, so the result doesn't depend on the order underlines arrive in.
enum UnderlineLimiter {
    /// `dropped` are positions in `kept`: an id can repeat (a name and an event starting at the same place).
    static func apply(_ kept: [KeptUnderline], maxPerParagraph: Int) -> (kept: [KeptUnderline], dropped: [Int]) {
        var survivors: [Int] = []
        var dropped: [Int] = []
        for (_, group) in Dictionary(grouping: kept.indices, by: { kept[$0].underline.paragraph }) {
            var taken: [Int] = []
            for i in group.sorted(by: { isBetter(kept[$0], kept[$1]) }) {
                let overlaps = taken.contains {
                    kept[$0].underline.sentence == kept[i].underline.sentence && NSIntersectionRange(kept[$0].underline.range, kept[i].underline.range).length > 0
                }
                if overlaps || taken.count >= maxPerParagraph { dropped.append(i) } else { taken.append(i) }
            }
            survivors += taken
        }
        let order = { (u: Underline) in (u.sentence, u.range.location, u.range.length) }
        return (survivors.map { kept[$0] }.sorted { order($0.underline) < order($1.underline) }, dropped.sorted())
    }

    /// Higher score first; ties: earlier sentence, earlier phrase, then `UnderlineKnobs.kindOrder`.
    private static func isBetter(_ a: KeptUnderline, _ b: KeptUnderline) -> Bool {
        if a.score != b.score { return a.score > b.score }
        if a.underline.sentence != b.underline.sentence { return a.underline.sentence < b.underline.sentence }
        if a.underline.range.location != b.underline.range.location { return a.underline.range.location < b.underline.range.location }
        let rank = { (k: UnderlineKind) in UnderlineKnobs.kindOrder.firstIndex(of: k) ?? Int.max }
        if rank(a.underline.kind) != rank(b.underline.kind) { return rank(a.underline.kind) < rank(b.underline.kind) }
        return a.underline.range.length < b.underline.range.length
    }
}
