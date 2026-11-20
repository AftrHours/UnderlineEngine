import Foundation
import Testing
@testable import UnderlineEngine

@Test func csvHeaderIsTheRowColumnsThenTheTwoReviewColumns() {
    #expect(QualitativeCSV.header == QualitativeRow.header + ["reviewer_verdict", "reviewer_note"])
    #expect(Array(QualitativeCSV.header.suffix(2)) == ["reviewer_verdict", "reviewer_note"])
}

@Test func quotesCommasQuotesAndLineBreaks() {
    let line = QualitativeCSV.line(["plain", "a, b", "say \"hi\"", "two\nlines"])
    #expect(line == "plain,\"a, b\",\"say \"\"hi\"\"\",\"two\nlines\"")
}

@Test func startsWithByteOrderMarkAndHeader() {
    let csv = QualitativeCSV.encode([])
    #expect(csv.hasPrefix("\u{FEFF}run_id,run_kind,"))
}

@Test func everyCsvRowHasTheHeadersColumnsAndEmptyReviewFields() {
    let row = QualitativeRow(values: QualitativeRow.header.map { "v-\($0)" }, sortRank: 50, sentence: 1, phrase: "p")
    let lines = QualitativeCSV.encode([row]).split(separator: "\n")
    #expect(lines.count == 2)
    let fields = lines[1].split(separator: ",", omittingEmptySubsequences: false)
    #expect(fields.count == QualitativeCSV.header.count)
    #expect(fields.suffix(2).allSatisfy { $0.isEmpty })
}
