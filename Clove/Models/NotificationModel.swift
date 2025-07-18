import Foundation


struct ScheduledNotification: Codable, Identifiable {
   let id: String
   let title: String
   let body: String
   let hour: Int
   let minute: Int
   let isEnabled: Bool
   let createdAt: Date
   
   init(title: String, body: String, hour: Int, minute: Int, isEnabled: Bool = true) {
      self.id = UUID().uuidString
      self.title = title
      self.body = body
      self.hour = hour
      self.minute = minute
      self.isEnabled = isEnabled
      self.createdAt = Date()
   }
   
   // Custom initializer to preserve existing ID
   init(id: String, title: String, body: String, hour: Int, minute: Int, isEnabled: Bool, createdAt: Date) {
      self.id = id
      self.title = title
      self.body = body
      self.hour = hour
      self.minute = minute
      self.isEnabled = isEnabled
      self.createdAt = createdAt
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
}

@Observable
class NotificationStore {
   static let shared = NotificationStore()
   
   var notifications: [ScheduledNotification] = []
   
   private let userDefaults = UserDefaults.standard
   
   private init() {
      loadNotifications()
   }
   
   // MARK: Persistence
   
   func saveNotifications() {
      do {
         let encoded = try JSONEncoder().encode(notifications)
         userDefaults.set(encoded, forKey: Constants.NOTIFICATIONS_KEY)
         print("✅ NotificationStore: Saved \(notifications.count) notifications")
      } catch {
         print("❌ NotificationStore: Failed to save notifications - \(error)")
      }
   }
   
   func loadNotifications() {
      guard let data = userDefaults.data(forKey: Constants.NOTIFICATIONS_KEY) else {
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
         NotificationManager.shared.scheduleRepeatingNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute
         )
         print("🔔 NotificationStore: Scheduled notification for \(notification.timeString)")
      }
   }
   
   func updateNotification(_ notification: ScheduledNotification) {
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         NotificationManager.shared.cancelNotification(id: notification.id)
         
         // Update the notification (ID is already preserved in the passed notification)
         notifications[index] = notification
         saveNotifications()
         print("✅ NotificationStore: Updated notification '\(notification.title)' to \(notification.timeString)")
         
         // Reschedule if enabled
         if notification.isEnabled {
            NotificationManager.shared.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute
            )
            print("🔔 NotificationStore: Rescheduled notification for \(notification.timeString)")
         }
      } else {
         print("❌ NotificationStore: Could not find notification with ID \(notification.id) to update")
      }
   }
   
   func deleteNotification(_ notification: ScheduledNotification) {
      // Cancel the notification
      NotificationManager.shared.cancelNotification(id: notification.id)
      
      // Remove from array
      notifications.removeAll { $0.id == notification.id }
      saveNotifications()
      print("✅ NotificationStore: Deleted notification '\(notification.title)'")
   }
   
   func toggleNotification(_ notification: ScheduledNotification) {
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         NotificationManager.shared.cancelNotification(id: notification.id)
         
         // Create updated notification preserving the original ID
         let updatedNotification = ScheduledNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            isEnabled: !notification.isEnabled,
            createdAt: notification.createdAt
         )
         
         // Replace in array
         notifications[index] = updatedNotification
         saveNotifications()
         print("✅ NotificationStore: Toggled notification '\(notification.title)' to \(updatedNotification.isEnabled ? "enabled" : "disabled")")
         
         // Schedule if now enabled
         if updatedNotification.isEnabled {
            NotificationManager.shared.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute
            )
            print("🔔 NotificationStore: Scheduled notification for \(notification.timeString)")
         }
      } else {
         print("❌ NotificationStore: Could not find notification with ID \(notification.id) to toggle")
      }
   }
}
