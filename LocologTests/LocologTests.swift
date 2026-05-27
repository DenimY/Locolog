import XCTest
@testable import Locolog

final class LocologTests: XCTestCase {

    func testNoteAutoTitle_firstLineExtracted() {
        let note = Note(content: "# 오늘 배운 것\n두 번째 줄입니다.")
        XCTAssertEqual(note.displayTitle, "오늘 배운 것")
    }

    func testNoteAutoTitle_emptyContentFallsBackToDate() {
        let note = Note(content: "")
        XCTAssertFalse(note.displayTitle.isEmpty)
    }

    func testNoteAutoTitle_markdownHeaderStripped() {
        let note = Note(content: "## 제목입니다")
        XCTAssertEqual(note.displayTitle, "제목입니다")
    }

    func testNoteDirtyOnCreation() {
        let note = Note(content: "테스트")
        XCTAssertTrue(note.isDirty)
    }
}
