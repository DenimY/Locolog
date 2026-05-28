import SwiftUI

struct ReminderPickerView: View {
    let reminderAt: Date?
    let onSave: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool
    @State private var selectedDate: Date

    init(reminderAt: Date?, onSave: @escaping (Date?) -> Void) {
        self.reminderAt = reminderAt
        self.onSave = onSave
        _isEnabled = State(initialValue: reminderAt != nil)
        _selectedDate = State(initialValue: reminderAt ?? Self.defaultReminderDate())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("알림 설정", isOn: $isEnabled)
                    if isEnabled {
                        DatePicker(
                            "날짜 및 시간",
                            selection: $selectedDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        #if os(iOS)
                        .datePickerStyle(.graphical)
                        #endif
                    }
                } footer: {
                    if isEnabled {
                        Text("설정한 시간에 메모 알림이 도착합니다.")
                    }
                }

                if reminderAt != nil {
                    Section {
                        Button(role: .destructive) {
                            onSave(nil)
                            dismiss()
                        } label: {
                            Label("알림 삭제", systemImage: "bell.slash")
                        }
                    }
                }
            }
            .navigationTitle("알림")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(isEnabled ? selectedDate : nil)
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 360).frame(minHeight: 260)
        #endif
    }

    private static func defaultReminderDate() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        components.hour = (components.hour ?? 9) + 1
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
