import Foundation
import UserNotifications
import SwiftUI

@Observable
class NotificationManager {
   static let shared = NotificationManager()
   
   var isAuthorized = false
   
   private init() {
      checkAuthorizationStatus()
   }
   
   // MARK: Authorization
   
   func requestPermission() async {
      do {
         let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
         await MainActor.run {
            self.isAuthorized = granted
         }
      } catch {
         print("Failed to request notification permission: \(error)")
      }
   }
   
   func checkAuthorizationStatus() {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
         DispatchQueue.main.async {
            self.isAuthorized = settings.authorizationStatus == .authorized
         }
      }
   }
   
   // MARK: - Schedule Notifications
   
   func scheduleRepeatingNotification(
      id: String,
      title: String,
      body: String,
      hour: Int,
      minute: Int,
      repeats: Bool = true
   )
   {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.badge = 1
      
      // Create date components for the trigger
      var dateComponents = DateComponents()
      dateComponents.hour = hour
      dateComponents.minute = minute
      
      let trigger = UNCalendarNotificationTrigger(
         dateMatching: dateComponents,
         repeats: repeats
      )
      
      let request = UNNotificationRequest(
         identifier: id,
         content: content,
         trigger: trigger
      )
      
      UNUserNotificationCenter.current().add(request) { error in
         if let error = error {
            print("Failed to schedule notification: \(error)")
         } else {
            print("Notification scheduled successfully with ID: \(id)")
         }
      }
   }
   
   // MARK: Cancel Notifications
   
   func cancelNotification(id: String) {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
   }
   
   func cancelAllNotifications() {
      UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
   }
   
   // MARK: Get Scheduled Notifications
   func getScheduledNotifications() async -> [UNNotificationRequest] {
      return await UNUserNotificationCenter.current().pendingNotificationRequests()
   }
   
   // MARK: Badge Management
   
   func clearBadge() {
      UNUserNotificationCenter.current().setBadgeCount(0)
   }
}
