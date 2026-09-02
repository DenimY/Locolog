import XCTest
import SwiftData
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

    func testParsedTagNames_hashtagsExtracted() {
        let note = Note(content: "작업 #개발 메모 #swift")
        XCTAssertEqual(Set(note.parsedTagNames), ["개발", "swift"])
    }

    func testPushSnapshot_matchesUnchangedNote() {
        let note = Note(content: "hello")
        let snap = NotePushSnapshot(note: note)
        XCTAssertTrue(snap.matches(note))
    }

    func testPushSnapshot_doesNotMatchAfterEdit() {
        let note = Note(content: "hello")
        let snap = NotePushSnapshot(note: note)
        note.content = "hello world"
        note.markDirty()
        XCTAssertFalse(snap.matches(note))
        XCTAssertTrue(note.isDirty)
    }

    func testMarkDirty_setsFlagAndUpdatesTimestamp() {
        let note = Note(content: "a")
        let before = note.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        note.markDirty()
        XCTAssertTrue(note.isDirty)
        XCTAssertGreaterThan(note.updatedAt, before)
    }

    func testStampPreset_matchesFolderByEmoji() {
        let folder = Folder(name: "회의록", iconEmoji: "📋")
        XCTAssertEqual(CategoryStampPreset.meeting.matchingFolder(in: [folder])?.id, folder.id)
        XCTAssertNil(CategoryStampPreset.code.matchingFolder(in: [folder]))
    }

    func testStampPreset_matchesFolderByName() {
        let folder = Folder(name: "코드")
        XCTAssertEqual(CategoryStampPreset.code.matchingFolder(in: [folder])?.id, folder.id)
    }

    @MainActor
    func testStampAssign_createsFolderAndSetsNote() throws {
        let schema = Schema([Note.self, Folder.self, Tag.self, SmartFolder.self, Category.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let note = Note(content: "안건")
        context.insert(note)

        CategoryStampAssigner.apply(
            preset: .meeting,
            to: note,
            folders: [],
            context: context,
            toggleIfSame: true
        )

        XCTAssertNotNil(note.folderId)
        let folders = try context.fetch(FetchDescriptor<Folder>())
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "회의")
        XCTAssertEqual(folders.first?.iconEmoji, "📋")
        XCTAssertEqual(note.folderId, folders.first?.id)
    }

    @MainActor
    func testStampAssign_toggleRemovesFolder() throws {
        let schema = Schema([Note.self, Folder.self, Tag.self, SmartFolder.self, Category.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let folder = Folder(name: "회의", iconEmoji: "📋")
        let note = Note(content: "안건")
        note.folderId = folder.id
        context.insert(folder)
        context.insert(note)

        CategoryStampAssigner.apply(
            preset: .meeting,
            to: note,
            folders: [folder],
            context: context,
            toggleIfSame: true
        )

        XCTAssertNil(note.folderId)
    }
}
