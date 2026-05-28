import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var isAuthorized = false

    // MARK: - 권한

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - 알림 예약

    func scheduleReminder(for note: Note) {
        guard let date = note.reminderAt, date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = note.displayTitle.isEmpty ? "메모" : note.displayTitle
        content.body = note.displayPreview.isEmpty ? "메모를 확인하세요." : note.displayPreview
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: note.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for note: Note) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [note.id.uuidString])
    }

    // MARK: - 일괄 재등록 (앱 재시작 시)

    func rescheduleAll(notes: [Note]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        notes.filter { !$0.isDeleted }.forEach { scheduleReminder(for: $0) }
    }
}
