import Foundation

/// The zero-spoiler rule (spec §5.1). Every step gets its sentences through here.
/// For an underline in sentence `s`, only sentences before `s` may be scored, become candidates or go into a prompt.
/// Indexes are iRead's global sentence indexes; `first...last` is the chapter.
enum ReadBoundary {
    /// `first..<sentence`, or nothing when `sentence` isn't in the chapter.
    static func searchable(before sentence: Int, first: Int, last: Int) -> [Int] {
        guard first <= last, (first...last).contains(sentence) else { return [] }
        return Array(first..<sentence)
    }
}
