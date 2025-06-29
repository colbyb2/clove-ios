import SwiftUI

struct DateNavigationHeader: View {
   @State private var selectedDate = Date()
   
   var onDateChange: (Date) -> Void = {_ in}
   
   
   var body: some View {
      VStack(spacing: CloveSpacing.medium) {
         // Main navigation row
         HStack {
            // Previous day button
            Button(action: {
               let newDate = Calendar.current.date(byAdding: .day, value: -1, to: self.selectedDate)!
               self.selectedDate = newDate
               let impactFeedback = UIImpactFeedbackGenerator(style: .light)
               impactFeedback.impactOccurred()
            }) {
               Image(systemName: "chevron.left")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundStyle(CloveColors.primaryText)
                  .frame(width: 44, height: 44)
                  .background(
                     Circle()
                        .fill(CloveColors.card)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  )
            }
            .accessibilityLabel("Previous day")
            .accessibilityHint("Navigate to previous day")
            
            Spacer()
            
            // Current date display
            VStack(spacing: 4) {
               Text(formattedDateTitle)
                  .font(.system(size: 24, weight: .bold, design: .rounded))
                  .foregroundStyle(CloveColors.primaryText)
               
               Text(formattedDateSubtitle)
                  .font(.system(size: 14, weight: .medium))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current date: \(accessibilityDateString)")
            
            Spacer()
            
            // Next day button
            Button(action: {
               let newDate = Calendar.current.date(byAdding: .day, value: 1, to: self.selectedDate)!
               self.selectedDate = newDate
               let impactFeedback = UIImpactFeedbackGenerator(style: .light)
               impactFeedback.impactOccurred()
            }) {
               Image(systemName: "chevron.right")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundStyle(CloveColors.primaryText)
                  .frame(width: 44, height: 44)
                  .background(
                     Circle()
                        .fill(CloveColors.card)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  )
            }
            .accessibilityLabel("Next day")
            .accessibilityHint("Navigate to next day")
            .disabled(isToday) // Disable if already at today
            .opacity(isToday ? 0.5 : 1.0)
         }
         
         // Date status indicator
         if !isToday {
            HStack(spacing: CloveSpacing.small) {
               Image(systemName: "clock.arrow.circlepath")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(CloveColors.secondaryText)
               
               Text("Editing past entry")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(CloveColors.secondaryText)
               
               Spacer()
               
               // Quick jump to today button
               Button(action: {
                  self.selectedDate = Date()
                  let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                  impactFeedback.impactOccurred()
               }) {
                  HStack(spacing: 4) {
                     Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .medium))
                     Text("Today")
                        .font(.system(size: 12, weight: .medium))
                  }
                  .foregroundStyle(CloveColors.accent)
                  .padding(.horizontal, CloveSpacing.small)
                  .padding(.vertical, 6)
                  .background(
                     Capsule()
                        .fill(CloveColors.accent.opacity(0.1))
                  )
               }
               .accessibilityLabel("Jump to today")
               .accessibilityHint("Navigate back to today's entry")
            }
            .padding(.horizontal, CloveSpacing.small)
            .padding(.vertical, CloveSpacing.small)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.small)
                  .fill(CloveColors.background)
            )
         }
      }
      .padding(.horizontal, CloveSpacing.medium)
      .padding(.vertical, CloveSpacing.small)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .stroke(CloveColors.background, lineWidth: 1)
      )
      .onChange(of: selectedDate) {old, new in
         self.onDateChange(new)
      }
   }
   
   // MARK: - Computed Properties
   
   private var isToday: Bool {
      Calendar.current.isDate(selectedDate, inSameDayAs: Date())
   }
   
   private var formattedDateTitle: String {
      if isToday {
         return "Today"
      } else if Calendar.current.isDate(selectedDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
         return "Yesterday"
      } else if Calendar.current.isDate(selectedDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
         return "Tomorrow"
      } else {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE" // Day of week
         return formatter.string(from: selectedDate)
      }
   }
   
   private var formattedDateSubtitle: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMMM d, yyyy"
      return formatter.string(from: selectedDate)
   }
   
   private var accessibilityDateString: String {
      let formatter = DateFormatter()
      formatter.dateStyle = .full
      return formatter.string(from: selectedDate)
   }
}

#Preview {
   VStack(spacing: 20) {
      // Today
      DateNavigationHeader()
   }
   .padding()
   .background(CloveColors.background)
}
