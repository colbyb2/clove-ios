import SwiftUI

// MARK: - Main Daily Reminder View
struct DailyReminderView: View {
    @State private var notificationStore = NotificationStore.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var showingTimePicker = false
    @State private var selectedTime = Date()
    
    // Get the first (and only) daily reminder
    private var dailyReminder: ScheduledNotification? {
        notificationStore.notifications.first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !notificationManager.isAuthorized {
                    NotificationPermissionView()
                } else {
                    ReminderSettingsView(
                        dailyReminder: dailyReminder,
                        showingTimePicker: $showingTimePicker,
                        selectedTime: $selectedTime
                    )
                }
            }
            .navigationTitle("Daily Reminder")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            notificationManager.checkAuthorizationStatus()
            if let reminder = dailyReminder {
                var components = DateComponents()
                components.hour = reminder.hour
                components.minute = reminder.minute
                selectedTime = Calendar.current.date(from: components) ?? Date()
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                selectedTime: $selectedTime,
                existingReminder: dailyReminder
            )
        }
    }
}

// MARK: - Permission Request View
struct NotificationPermissionView: View {
    @State private var notificationManager = NotificationManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Bell Icon with animation
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(Theme.shared.accent)
                    .rotationEffect(.degrees(isAnimating ? -10 : 10))
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            }
            
            VStack(spacing: 16) {
                Text("Stay on Track")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Get daily reminders to log your progress and build consistent habits")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await notificationManager.requestPermission()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 16, weight: .medium))
                    Text("Enable Notifications")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.shared.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Reminder Settings View
struct ReminderSettingsView: View {
    @State var notificationStore = NotificationStore.shared
    let dailyReminder: ScheduledNotification?
    @Binding var showingTimePicker: Bool
    @Binding var selectedTime: Date
    @State private var isToggleAnimating = false
    
    private var isEnabled: Bool {
        dailyReminder?.isEnabled ?? false
    }
    
    private var timeString: String {
        dailyReminder?.timeString ?? "9:00 AM"
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Status Icon
            ZStack {
                Circle()
                    .fill(isEnabled ? Theme.shared.accent.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .animation(.easeInOut(duration: 0.3), value: isEnabled)
                
                Image(systemName: isEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(isEnabled ? Theme.shared.accent : .gray)
                    .scaleEffect(isToggleAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isToggleAnimating)
            }
            
            VStack(spacing: 24) {
                // Title and Description
                VStack(spacing: 8) {
                    Text("Daily Log Reminder")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(isEnabled ? "You'll be reminded at \(timeString)" : "Stay consistent with daily reminders")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: isEnabled)
                }
                
                // Toggle Switch
                VStack(spacing: 16) {
                    HStack {
                        Text("Enable Reminders")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: .init(
                            get: { isEnabled },
                            set: { newValue in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    isToggleAnimating = true
                                    toggleReminder(enabled: newValue)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isToggleAnimating = false
                                }
                            }
                        ))
                        .tint(Theme.shared.accent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Time Picker Button
                    if isEnabled {
                        Button(action: {
                            if let reminder = dailyReminder {
                                var components = DateComponents()
                                components.hour = reminder.hour
                                components.minute = reminder.minute
                                selectedTime = Calendar.current.date(from: components) ?? Date()
                            }
                            showingTimePicker = true
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Theme.shared.accent)
                                
                                Text("Reminder Time")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(timeString)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.shared.accent)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.3), value: isEnabled)
    }
    
    private func toggleReminder(enabled: Bool) {
        if enabled {
            // Create a new daily reminder if none exists
            if dailyReminder == nil {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: selectedTime)
                let minute = calendar.component(.minute, from: selectedTime)
                
                let newReminder = ScheduledNotification(
                    title: "Daily Log Reminder",
                    body: "Don't forget to log your daily progress!",
                    hour: hour,
                    minute: minute,
                    isEnabled: true
                )
                notificationStore.addNotification(newReminder)
            } else if let reminder = dailyReminder {
                // Toggle existing reminder
                notificationStore.toggleNotification(reminder)
            }
        } else {
            // Disable existing reminder
            if let reminder = dailyReminder {
                notificationStore.toggleNotification(reminder)
            }
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @State var notificationStore = NotificationStore.shared
    let existingReminder: ScheduledNotification?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Set Reminder Time")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose when you'd like to receive your daily reminder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
                
                Button(action: {
                    updateReminderTime()
                    dismiss()
                }) {
                    Text("Save Time")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.shared.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.shared.accent)
                }
            }
        }
    }
    
    private func updateReminderTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        
        if let reminder = existingReminder {
            // Update existing reminder preserving the original ID
            let updatedReminder = ScheduledNotification(
                id: reminder.id,
                title: reminder.title,
                body: reminder.body,
                hour: hour,
                minute: minute,
                isEnabled: reminder.isEnabled,
                createdAt: reminder.createdAt
            )
            notificationStore.updateNotification(updatedReminder)
        } else {
            // Create new reminder
            let newReminder = ScheduledNotification(
                title: "Daily Log Reminder",
                body: "Don't forget to log your daily progress!",
                hour: hour,
                minute: minute,
                isEnabled: true
            )
            notificationStore.addNotification(newReminder)
        }
    }
}

// MARK: - Preview
#Preview {
   DailyReminderView()
}
