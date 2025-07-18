import SwiftUI

struct OnboardingNotificationView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @State private var notificationManager = NotificationManager.shared
    @State private var notificationStore = NotificationStore.shared
    @State private var iconScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    @State private var showingTimePicker = false
    @State private var selectedTime = Date()
    @State private var isNotificationEnabled = false
    @State private var isToggleAnimating = false
    
    // Get the first (and only) daily reminder
    private var dailyReminder: ScheduledNotification? {
        notificationStore.notifications.first
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.shared.accent.opacity(0.05),
                        Theme.shared.accent.opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hero content
                    VStack(spacing: 24) {
                        // Icon with enhanced styling
                        ZStack {
                            // Soft shadow circle
                            Circle()
                                .fill(Theme.shared.accent.opacity(0.1))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                                .offset(y: 10)
                            
                            // Icon background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            isNotificationEnabled ? Theme.shared.accent.opacity(0.8) : Color.gray.opacity(0.6),
                                            isNotificationEnabled ? Theme.shared.accent.opacity(0.6) : Color.gray.opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .animation(.easeInOut(duration: 0.3), value: isNotificationEnabled)
                            
                            // Main icon
                            Image(systemName: isNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.white)
                                .scaleEffect(isToggleAnimating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isToggleAnimating)
                        }
                        .scaleEffect(iconScale)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: iconScale)
                        
                        // Text content
                        VStack(spacing: 16) {
                            Text("Stay Consistent")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Theme.shared.accent,
                                            Theme.shared.accent.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(isNotificationEnabled ? "You'll be reminded at \(timeString)" : "Get gentle daily reminders to track your progress and build healthy habits.")
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                                .animation(.easeInOut(duration: 0.3), value: isNotificationEnabled)
                        }
                        .opacity(contentOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: contentOpacity)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Settings Controls
                    VStack(spacing: 16) {
                        // Toggle Switch
                        HStack {
                            Text("Enable Daily Reminders")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Spacer()
                            
                            Toggle("", isOn: .init(
                                get: { isNotificationEnabled },
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
                        if isNotificationEnabled {
                            Button(action: {
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
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.3), value: isNotificationEnabled)
                    
                    Spacer()
                    
                    // Enhanced button area
                    VStack(spacing: 16) {
                        CloveButton(text: "Continue", fontColor: .white) {
                            viewModel.nextStep()
                        }
                        .shadow(color: Theme.shared.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // Skip button
                        Button(action: {
                            viewModel.nextStep()
                        }) {
                            Text("Skip for now")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                    .offset(y: buttonOffset)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: buttonOffset)
                }
            }
        }
        .onAppear {
            // Check current authorization status
            notificationManager.checkAuthorizationStatus()
            
            // Check if we already have a reminder
            if let reminder = dailyReminder {
                isNotificationEnabled = reminder.isEnabled
                var components = DateComponents()
                components.hour = reminder.hour
                components.minute = reminder.minute
                selectedTime = Calendar.current.date(from: components) ?? Date()
            } else {
                // Default to 9:00 AM
                var components = DateComponents()
                components.hour = 9
                components.minute = 0
                selectedTime = Calendar.current.date(from: components) ?? Date()
            }
            
            // Trigger animations
            withAnimation {
                iconScale = 1.0
                contentOpacity = 1.0
                buttonOffset = 0
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                selectedTime: $selectedTime,
                existingReminder: dailyReminder
            )
        }
    }
    
    private func toggleReminder(enabled: Bool) {
        if enabled {
            // Request permission first
            Task {
                await notificationManager.requestPermission()
                
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
                
                // Update UI state
                await MainActor.run {
                    isNotificationEnabled = enabled
                }
            }
        } else {
            // Disable existing reminder
            if let reminder = dailyReminder {
                notificationStore.toggleNotification(reminder)
            }
            isNotificationEnabled = enabled
        }
    }
}

#Preview {
    OnboardingNotificationView()
        .environment(OnboardingViewModel())
}