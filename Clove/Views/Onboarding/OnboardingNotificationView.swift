import SwiftUI
import UserNotifications

struct OnboardingNotificationView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var notificationManager = NotificationManager.shared
    @State private var notificationStore = NotificationStore.shared
    @State private var selectedTime = Self.defaultReminderTime
    @State private var isRequesting = false
    @State private var permissionDenied = false
    @State private var appeared = false

    private static var defaultReminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    }

    private var onboardingReminder: ScheduledNotification? {
        notificationStore.notifications.first { $0.title == "Daily Log Reminder" }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 12)

                    ZStack {
                        Circle()
                            .fill(Theme.shared.accent.opacity(0.12))
                            .frame(width: 132, height: 132)
                            .blur(radius: 8)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 98, height: 98)
                            .shadow(color: Theme.shared.accent.opacity(0.24), radius: 16, y: 8)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(appeared ? 1 : 0.72)

                    VStack(spacing: 9) {
                        Text("A gentle reminder")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(CloveColors.primaryText)
                        Text("Choose a time that fits naturally into your day. Reminders stay on this device and can be changed anytime.")
                            .font(.subheadline)
                            .foregroundStyle(CloveColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.shared.accent)
                                .frame(width: 38, height: 38)
                                .background(Theme.shared.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily check-in")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CloveColors.primaryText)
                                Text("Pick a time that works for most days")
                                    .font(.caption)
                                    .foregroundStyle(CloveColors.secondaryText)
                            }

                            Spacer()

                            DatePicker("Reminder time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Theme.shared.accent)
                        }
                        .padding(14)
                    }
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(CloveColors.secondaryText.opacity(0.09)))

                    if permissionDenied || notificationManager.authorizationStatus == .denied {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Notifications are currently off", systemImage: "bell.slash.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            Text("You can continue without a reminder, or allow notifications in iOS Settings.")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                            Button("Open Settings") {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(url)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.shared.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(CloveColors.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CloveColors.error.opacity(0.18)))
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 12) {
                        Button(action: enableReminder) {
                            HStack(spacing: 8) {
                                if isRequesting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "bell.fill")
                                }
                                Text(isRequesting ? "Requesting permission…" : "Enable reminder")
                            }
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.shared.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequesting || notificationManager.authorizationStatus == .denied)
                        .opacity(notificationManager.authorizationStatus == .denied ? 0.45 : 1)

                        Button("Not now") {
                            viewModel.nextStep()
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(minHeight: 42)
                    }
                }
                .frame(minHeight: geometry.size.height - 16)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 14))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            notificationManager.checkAuthorizationStatus()
            if let reminder = onboardingReminder {
                selectedTime = Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? selectedTime
            }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.84)) {
                    appeared = true
                }
            }
        }
    }

    private func enableReminder() {
        guard !isRequesting else { return }
        isRequesting = true

        Task {
            let granted: Bool
            if notificationManager.isAuthorized {
                granted = true
            } else {
                granted = await notificationManager.requestPermission()
            }

            await MainActor.run {
                isRequesting = false
                permissionDenied = !granted
                guard granted else { return }
                saveReminder()
                viewModel.nextStep()
            }
        }
    }

    private func saveReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 20
        let minute = components.minute ?? 0

        if let existing = onboardingReminder {
            let updated = ScheduledNotification(
                id: existing.id,
                title: existing.title,
                body: existing.body,
                hour: hour,
                minute: minute,
                isEnabled: true,
                weekdays: existing.weekdays,
                createdAt: existing.createdAt
            )
            notificationStore.updateNotification(updated)
        } else {
            notificationStore.addNotification(
                ScheduledNotification(
                    title: "Daily Log Reminder",
                    body: "Take a moment for your Clove check-in.",
                    hour: hour,
                    minute: minute
                )
            )
        }
    }
}

#Preview {
    OnboardingNotificationView()
        .environment(OnboardingViewModel())
}
