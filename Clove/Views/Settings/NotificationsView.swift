import SwiftUI
import UserNotifications
import UIKit

struct DailyReminderView: View {
    @State private var notificationStore = NotificationStore.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var showingEditor = false
    @State private var reminderBeingEdited: ScheduledNotification?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    reminderHeader
                    NotificationPermissionCard()

                    if notificationStore.notifications.isEmpty {
                        emptyState
                    } else {
                        reminderList
                    }

                    addButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            notificationManager.checkAuthorizationStatus()
        }
        .sheet(isPresented: $showingEditor) {
            ReminderEditorSheet(existingReminder: reminderBeingEdited)
        }
    }

    private var reminderHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.shared.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Build a routine that fits your day")
                    .font(.headline)
                Text("Add separate prompts for morning, midday, evening, or specific days.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reminderList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your reminders")
                    .font(.headline)
                Spacer()
                Text("\(notificationStore.notifications.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
            }

            ForEach(notificationStore.notifications) { reminder in
                ReminderRow(
                    reminder: reminder,
                    onToggle: { notificationStore.toggleNotification(reminder) },
                    onEdit: {
                        reminderBeingEdited = reminder
                        showingEditor = true
                    },
                    onDelete: { notificationStore.deleteNotification(reminder) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.secondary)
            Text("No reminders yet")
                .font(.headline)
            Text("Add your first reminder and choose exactly which days it should run.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var addButton: some View {
        Button {
            reminderBeingEdited = nil
            showingEditor = true
        } label: {
            Label("Add Reminder", systemImage: "plus")
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.shared.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct NotificationPermissionCard: View {
    @State private var notificationManager = NotificationManager.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch notificationManager.authorizationStatus {
        case .denied:
            permissionCard(
                icon: "bell.slash.fill",
                title: "Notifications are off",
                message: "Your reminders are saved, but iOS cannot deliver them until notifications are enabled.",
                buttonTitle: "Open Settings",
                action: openSystemSettings
            )
        case .notDetermined:
            permissionCard(
                icon: "bell.fill",
                title: "Allow reminder notifications",
                message: "Reminders stay on this device and can be changed at any time.",
                buttonTitle: "Allow Notifications",
                action: {
                    Task { await notificationManager.requestPermission() }
                }
            )
        default:
            EmptyView()
        }
    }

    private func permissionCard(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.shared.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.shared.accent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(buttonTitle, action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.shared.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.shared.accent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.shared.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct ReminderRow: View {
    let reminder: ScheduledNotification
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.timeString)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(reminder.displayNote)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(reminder.daysString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(Theme.shared.accent)

            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(reminder.isEnabled ? 1 : 0.65)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ReminderEditorSheet: View {
    @State private var notificationStore = NotificationStore.shared
    @Environment(\.dismiss) private var dismiss

    let existingReminder: ScheduledNotification?
    @State private var selectedTime: Date
    @State private var selectedDays: Set<Int>
    @State private var isEnabled: Bool
    @State private var reminderNote: String

    init(existingReminder: ScheduledNotification?) {
        self.existingReminder = existingReminder

        var components = DateComponents()
        components.hour = existingReminder?.hour ?? 9
        components.minute = existingReminder?.minute ?? 0
        _selectedTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        _selectedDays = State(initialValue: Set(
            existingReminder?.weekdays ?? NotificationWeekday.allCases.map(\.rawValue)
        ))
        _isEnabled = State(initialValue: existingReminder?.isEnabled ?? true)
        _reminderNote = State(initialValue: {
            guard let body = existingReminder?.body,
                  body != ScheduledNotification.defaultBody else { return "" }
            return body
        }())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker(
                        "Reminder time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                Section {
                    TextField("Example: Log evening symptoms", text: $reminderNote, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Reminder note")
                } footer: {
                    Text("Optional. This will appear in the notification.")
                }

                Section {
                    weekdayPicker
                } header: {
                    Text("Days")
                } footer: {
                    Text(selectedDays.isEmpty ? "Choose at least one day." : selectedDaysDescription)
                }

                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                        .tint(Theme.shared.accent)
                }

                if let reminder = existingReminder {
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            notificationStore.deleteNotification(reminder)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(selectedDays.isEmpty)
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 7) {
            ForEach(NotificationWeekday.allCases) { weekday in
                Button {
                    if selectedDays.contains(weekday.rawValue) {
                        selectedDays.remove(weekday.rawValue)
                    } else {
                        selectedDays.insert(weekday.rawValue)
                    }
                } label: {
                    Text(String(weekday.shortName.prefix(1)))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(selectedDays.contains(weekday.rawValue) ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            selectedDays.contains(weekday.rawValue)
                                ? Theme.shared.accent
                                : Color(UIColor.tertiarySystemFill)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.shortName)
                .accessibilityAddTraits(selectedDays.contains(weekday.rawValue) ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var selectedDaysDescription: String {
        ScheduledNotification(
            title: "",
            body: "",
            hour: 0,
            minute: 0,
            weekdays: Array(selectedDays)
        ).daysString
    }

    private func save() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        let weekdays = Array(selectedDays).sorted()
        let trimmedNote = reminderNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let notificationBody = trimmedNote.isEmpty ? ScheduledNotification.defaultBody : trimmedNote

        if let reminder = existingReminder {
            notificationStore.updateNotification(ScheduledNotification(
                id: reminder.id,
                title: reminder.title,
                body: notificationBody,
                hour: hour,
                minute: minute,
                isEnabled: isEnabled,
                weekdays: weekdays,
                createdAt: reminder.createdAt
            ))
        } else {
            notificationStore.addNotification(ScheduledNotification(
                title: "Daily Log Reminder",
                body: notificationBody,
                hour: hour,
                minute: minute,
                isEnabled: isEnabled,
                weekdays: weekdays
            ))
        }

        dismiss()
    }
}

// The onboarding flow still offers a focused one-time picker for its first reminder.
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @State private var notificationStore = NotificationStore.shared
    let existingReminder: ScheduledNotification?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "Reminder time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()

                Button("Save Time", action: save)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.shared.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let hour = Calendar.current.component(.hour, from: selectedTime)
        let minute = Calendar.current.component(.minute, from: selectedTime)

        if let reminder = existingReminder {
            notificationStore.updateNotification(ScheduledNotification(
                id: reminder.id,
                title: reminder.title,
                body: reminder.body,
                hour: hour,
                minute: minute,
                isEnabled: reminder.isEnabled,
                weekdays: reminder.weekdays,
                createdAt: reminder.createdAt
            ))
        } else {
            notificationStore.addNotification(ScheduledNotification(
                title: "Daily Log Reminder",
                body: ScheduledNotification.defaultBody,
                hour: hour,
                minute: minute
            ))
        }

        dismiss()
    }
}

#Preview {
    DailyReminderView()
}
