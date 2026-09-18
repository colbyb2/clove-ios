import Foundation
import UserNotifications
import SwiftUI

@Observable
class NotificationManager: LocalNotificationScheduling {
   static let shared = NotificationManager()
   
   var isAuthorized = false
   var authorizationStatus: UNAuthorizationStatus = .notDetermined
   
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
         checkAuthorizationStatus()
      } catch {
         print("Failed to request notification permission: \(error)")
      }
   }
   
   func checkAuthorizationStatus() {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
         DispatchQueue.main.async {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
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
      weekdays: [Int] = NotificationWeekday.allCases.map(\.rawValue)
   )
   {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.badge = 1
      
      let validWeekdays = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
      let schedules = validWeekdays.count == 7
         ? [(identifier: id, weekday: Optional<Int>.none)]
         : validWeekdays.map { (identifier: "\(id)-weekday-\($0)", weekday: Optional($0)) }

      for schedule in schedules {
         var dateComponents = DateComponents()
         dateComponents.hour = hour
         dateComponents.minute = minute
         dateComponents.weekday = schedule.weekday

         let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
         )

         let request = UNNotificationRequest(
            identifier: schedule.identifier,
            content: content,
            trigger: trigger
         )

         UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
               print("Failed to schedule notification: \(error)")
            } else {
               print("Notification scheduled successfully with ID: \(schedule.identifier)")
            }
         }
      }
   }
   
   // MARK: Cancel Notifications
   
   func cancelNotification(id: String) {
      let identifiers = [id] + (1...7).map { "\(id)-weekday-\($0)" }
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
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
