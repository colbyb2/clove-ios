import Foundation

enum NotificationWeekday: Int, Codable, CaseIterable, Identifiable {
   case sunday = 1
   case monday
   case tuesday
   case wednesday
   case thursday
   case friday
   case saturday

   var id: Int { rawValue }

   var shortName: String {
      Calendar.current.shortWeekdaySymbols[rawValue - 1]
   }
}

protocol LocalNotificationScheduling {
   func scheduleRepeatingNotification(
      id: String,
      title: String,
      body: String,
      hour: Int,
      minute: Int,
      weekdays: [Int]
   )
   func cancelNotification(id: String)
}

struct ScheduledNotification: Codable, Identifiable {
   static let defaultBody = "Don't forget to log your daily progress!"

   let id: String
   let title: String
   let body: String
   let hour: Int
   let minute: Int
   let isEnabled: Bool
   let weekdays: [Int]
   let createdAt: Date
   
   init(
      title: String,
      body: String,
      hour: Int,
      minute: Int,
      isEnabled: Bool = true,
      weekdays: [Int] = NotificationWeekday.allCases.map(\.rawValue)
   ) {
      self.id = UUID().uuidString
      self.title = title
      self.body = body
      self.hour = hour
      self.minute = minute
      self.isEnabled = isEnabled
      self.weekdays = Self.normalizedWeekdays(weekdays)
      self.createdAt = Date()
   }
   
   // Custom initializer to preserve existing ID
   init(
      id: String,
      title: String,
      body: String,
      hour: Int,
      minute: Int,
      isEnabled: Bool,
      weekdays: [Int] = NotificationWeekday.allCases.map(\.rawValue),
      createdAt: Date
   ) {
      self.id = id
      self.title = title
      self.body = body
      self.hour = hour
      self.minute = minute
      self.isEnabled = isEnabled
      self.weekdays = Self.normalizedWeekdays(weekdays)
      self.createdAt = createdAt
   }

   private enum CodingKeys: String, CodingKey {
      case id, title, body, hour, minute, isEnabled, weekdays, createdAt
   }

   init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      title = try container.decode(String.self, forKey: .title)
      body = try container.decode(String.self, forKey: .body)
      hour = try container.decode(Int.self, forKey: .hour)
      minute = try container.decode(Int.self, forKey: .minute)
      isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
      weekdays = Self.normalizedWeekdays(
         try container.decodeIfPresent([Int].self, forKey: .weekdays)
            ?? NotificationWeekday.allCases.map(\.rawValue)
      )
      createdAt = try container.decode(Date.self, forKey: .createdAt)
   }

   private static func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
      Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
   }
   
   var timeString: String {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      
      var components = DateComponents()
      components.hour = hour
      components.minute = minute
      
      if let date = Calendar.current.date(from: components) {
         return formatter.string(from: date)
      }
      return "\(hour):\(String(format: "%02d", minute))"
   }

   var daysString: String {
      if weekdays.count == 7 { return "Every day" }
      if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
      if weekdays == [1, 7] { return "Weekends" }
      return weekdays.compactMap(NotificationWeekday.init(rawValue:)).map(\.shortName).joined(separator: ", ")
   }

   var displayNote: String {
      let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? Self.defaultBody : trimmed
   }
}

@Observable
class NotificationStore {
   static let shared = NotificationStore()
   
   var notifications: [ScheduledNotification] = []
   
   private let userDefaults: UserDefaults
   private let notificationScheduler: any LocalNotificationScheduling
   private let storageKey: String
   
   init(
      userDefaults: UserDefaults = .standard,
      notificationScheduler: any LocalNotificationScheduling = NotificationManager.shared,
      storageKey: String = Constants.NOTIFICATIONS_KEY
   ) {
      self.userDefaults = userDefaults
      self.notificationScheduler = notificationScheduler
      self.storageKey = storageKey
      loadNotifications()
   }
   
   // MARK: Persistence
   
   func saveNotifications() {
      do {
         let encoded = try JSONEncoder().encode(notifications)
         userDefaults.set(encoded, forKey: storageKey)
         print("✅ NotificationStore: Saved \(notifications.count) notifications")
      } catch {
         print("❌ NotificationStore: Failed to save notifications - \(error)")
      }
   }
   
   func loadNotifications() {
      guard let data = userDefaults.data(forKey: storageKey) else {
         print("📝 NotificationStore: No existing notifications found")
         return
      }
      
      do {
         let decoded = try JSONDecoder().decode([ScheduledNotification].self, from: data)
         notifications = decoded
         print("✅ NotificationStore: Loaded \(notifications.count) notifications")
      } catch {
         print("❌ NotificationStore: Failed to load notifications - \(error)")
      }
   }
   
   // MARK: CRUD Operations
   
   func addNotification(_ notification: ScheduledNotification) {
      notifications.append(notification)
      saveNotifications()
      print("✅ NotificationStore: Added notification '\(notification.title)' at \(notification.timeString)")
      
      // Schedule the actual notification
      if notification.isEnabled {
         notificationScheduler.scheduleRepeatingNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            weekdays: notification.weekdays
         )
         print("🔔 NotificationStore: Scheduled notification for \(notification.timeString)")
      }
   }
   
   func updateNotification(_ notification: ScheduledNotification) {
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         notificationScheduler.cancelNotification(id: notification.id)
         
         // Update the notification (ID is already preserved in the passed notification)
         notifications[index] = notification
         saveNotifications()
         print("✅ NotificationStore: Updated notification '\(notification.title)' to \(notification.timeString)")
         
         // Reschedule if enabled
         if notification.isEnabled {
            notificationScheduler.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute,
               weekdays: notification.weekdays
            )
            print("🔔 NotificationStore: Rescheduled notification for \(notification.timeString)")
         }
      } else {
         print("❌ NotificationStore: Could not find notification with ID \(notification.id) to update")
      }
   }
   
   func deleteNotification(_ notification: ScheduledNotification) {
      // Cancel the notification
      notificationScheduler.cancelNotification(id: notification.id)
      
      // Remove from array
      notifications.removeAll { $0.id == notification.id }
      saveNotifications()
      print("✅ NotificationStore: Deleted notification '\(notification.title)'")
   }
   
   func toggleNotification(_ notification: ScheduledNotification) {
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         notificationScheduler.cancelNotification(id: notification.id)
         
         // Create updated notification preserving the original ID
         let updatedNotification = ScheduledNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            isEnabled: !notification.isEnabled,
            weekdays: notification.weekdays,
            createdAt: notification.createdAt
         )
         
         // Replace in array
         notifications[index] = updatedNotification
         saveNotifications()
         print("✅ NotificationStore: Toggled notification '\(notification.title)' to \(updatedNotification.isEnabled ? "enabled" : "disabled")")
         
         // Schedule if now enabled
         if updatedNotification.isEnabled {
            notificationScheduler.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute,
               weekdays: notification.weekdays
            )
            print("🔔 NotificationStore: Scheduled notification for \(notification.timeString)")
         }
      } else {
         print("❌ NotificationStore: Could not find notification with ID \(notification.id) to toggle")
      }
   }
}
