import Foundation
@testable import UnderlineEngine

/// The same rows as the Markdown report, as a CSV for Numbers or Excel: one column per value, one row per phrase,
/// so they can be sorted and filtered. The two review columns at the end are always empty, for you to fill in.
enum QualitativeCSV {
    static let header = QualitativeRow.header + ["reviewer_verdict", "reviewer_note"]

    /// UTF-8 with a byte-order mark (so Excel shows curly quotes), a header row, standard quoting.
    static func encode(_ rows: [QualitativeRow]) -> String {
        "\u{FEFF}" + ([line(header)] + rows.map { line($0.values + ["", ""]) }).joined(separator: "\n") + "\n"
    }

    /// A field with a comma, quote or line break is quoted, inner quotes doubled.
    static func line(_ fields: [String]) -> String {
        fields.map { f in
            f.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : f
        }.joined(separator: ",")
    }
}

@available(macOS 27, *)
extension Evals {
    /// Writes the CSV next to the saved result, with the same base name.
    static func saveCSV(_ rows: [QualitativeRow], beside json: URL) throws -> URL {
        let url = json.deletingPathExtension().appendingPathExtension("csv")
        try QualitativeCSV.encode(rows).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Writes both the Markdown report and the CSV next to the saved result, with the same base name.
    static func saveQualitative(_ rows: [QualitativeRow], run: RunInfo, beside json: URL) throws -> (report: URL, csv: URL) {
        (try saveReport(rows, run: run, beside: json), try saveCSV(rows, beside: json))
    }
}
