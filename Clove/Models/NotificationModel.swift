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
   var notifications: [ScheduledNotification] = []
   
   private let userDefaults = UserDefaults.standard
   
   init() {
      loadNotifications()
   }
   
   // MARK: Persistence
   
   func saveNotifications() {
      if let encoded = try? JSONEncoder().encode(notifications) {
         userDefaults.set(encoded, forKey: Constants.NOTIFICATIONS_KEY)
      }
   }
   
   func loadNotifications() {
      if let data = userDefaults.data(forKey: Constants.NOTIFICATIONS_KEY),
         let decoded = try? JSONDecoder().decode([ScheduledNotification].self, from: data) {
         notifications = decoded
      }
   }
   
   // MARK: CRUD Operations
   
   func addNotification(_ notification: ScheduledNotification) {
      notifications.append(notification)
      saveNotifications()
      
      // Schedule the actual notification
      if notification.isEnabled {
         NotificationManager.shared.scheduleRepeatingNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute
         )
      }
   }
   
   func updateNotification(_ notification: ScheduledNotification) {
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         NotificationManager.shared.cancelNotification(id: notification.id)
         
         // Update the notification
         notifications[index] = notification
         saveNotifications()
         
         // Reschedule if enabled
         if notification.isEnabled {
            NotificationManager.shared.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute
            )
         }
      }
   }
   
   func deleteNotification(_ notification: ScheduledNotification) {
      // Cancel the notification
      NotificationManager.shared.cancelNotification(id: notification.id)
      
      // Remove from array
      notifications.removeAll { $0.id == notification.id }
      saveNotifications()
   }
   
   func toggleNotification(_ notification: ScheduledNotification) {
      let updatedNotification = ScheduledNotification(
         title: notification.title,
         body: notification.body,
         hour: notification.hour,
         minute: notification.minute,
         isEnabled: !notification.isEnabled
      )
      
      // Use the same ID
      let updatedWithSameId = ScheduledNotification(
         title: notification.title,
         body: notification.body,
         hour: notification.hour,
         minute: notification.minute,
         isEnabled: !notification.isEnabled
      )
      
      if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
         // Cancel existing notification
         NotificationManager.shared.cancelNotification(id: notification.id)
         
         // Create new notification with updated enabled state
         let newNotification = ScheduledNotification(
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            isEnabled: !notification.isEnabled
         )
         
         // Replace in array but keep same ID
         notifications[index] = ScheduledNotification(
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            isEnabled: !notification.isEnabled
         )
         
         saveNotifications()
         
         // Schedule if enabled
         if !notification.isEnabled { // Will be enabled after toggle
            NotificationManager.shared.scheduleRepeatingNotification(
               id: notification.id,
               title: notification.title,
               body: notification.body,
               hour: notification.hour,
               minute: notification.minute
            )
         }
      }
   }
}
