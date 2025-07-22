import Foundation

enum Tutorials {
   // MARK: - Today View Tutorial
   static let TodayView: Tutorial = Tutorial(id: "todayViewTutorial", steps: [
      TutorialStep(id: 0, icon: "sun.max.fill", title: "Welcome to Clove!",
                   description: "This is your daily health logging hub. Track your mood, energy, symptoms, and more!",
                   subtitle: "Let's explore what you can do here"),
      
      TutorialStep(id: 1, icon: "slider.horizontal.3", title: "Rate Your Metrics",
                   description: "Use the sliders to quickly rate your mood, energy, etc. Your ratings help identify patterns over time.",
                   subtitle: "Slide to adjust - it only takes a few seconds!"),
      
      TutorialStep(id: 2, icon: "fork.knife", title: "Log Activities",
                   description: "Record what you ate, activities you did, and medications you took. These details help connect the dots in your health journey.",
                   subtitle: "The more you track, the better insights you'll get"),
      
      TutorialStep(id: 3, icon: "note.text", title: "Add Personal Notes",
                   description: "Include any additional thoughts, observations, or context about your day. Sometimes the details make all the difference.",
                   subtitle: "Your personal health diary"),
      
      TutorialStep(id: 4, icon: "checkmark.seal.fill", title: "Save Your Day",
                   description: "Tap 'Save Log' when you're done to save your entry. You can always come back to update or add more information later.",
                   subtitle: "Your daily health snapshot is complete!"),
      
      TutorialStep(id: 5, icon: "arrowshape.left.arrowshape.right.fill", title: "Editing Past Days",
                   description: "Use the arrows at the top to move between days!",
                   subtitle: "You can also jump to a specific date using the History view."),
      
      TutorialStep(id: 5, icon: "gear", title: "Want to track more or less?",
                   description: "Head over to Feature Selection within Settings! Turn a metric on or off in one click!",
                   subtitle: "Keep yourself from getting overwhelmed.")
   ])
   
   // MARK: - Insights View Tutorial
   static let InsightsView: Tutorial = Tutorial(id: "insightsViewTutorial", steps: [
      TutorialStep(id: 0, icon: "chart.bar.fill", title: "Discover Your Insights",
                   description: "Welcome to your personal health analytics! Here you'll find patterns, trends, and correlations in your health data.",
                   subtitle: "Turn your daily logs into meaningful insights"),
      
      TutorialStep(id: 1, icon: "bell.fill", title: "Reminder",
                   description: "Quck Reminder: This app should make your life easier and less stressful, not overwhelming. Everything can be customized to your liking.",
                   subtitle: nil),
      
      TutorialStep(id: 2, icon: "bell.fill", title: "Reminder",
                   description: "Turn off any features or insights at any time from settings.",
                   subtitle: "You got this!"),
      
      TutorialStep(id: 3, icon: "square.grid.2x2", title: "Overview Dashboard",
                   description: "Get a quick snapshot of your recent health metrics. This gives you a customizable, at-a-glance overview.",
                   subtitle: "Your health summary in one view"),
      
      TutorialStep(id: 4, icon: "chart.line.uptrend.xyaxis", title: "Interactive Charts",
                   description: "Select any metric to view a graph. Get a visual glance at a metric over time.",
                   subtitle: "Visualize your health journey"),
      
      TutorialStep(id: 5, icon: "brain.head.profile", title: "Smart Insights",
                   description: "AI-powered analysis identifies patterns you might miss. Discover correlations between your activities, symptoms, and feelings.",
                   subtitle: "Let technology help you understand your health"),
      
      TutorialStep(id: 6, icon: "chart.bar.xaxis", title: "Correlation Analysis",
                   description: "See how different aspects of your health relate to each other. Maybe your energy dips after certain meals, or pain increases with weather changes.",
                   subtitle: "Connect the dots in your health data"),
      
      TutorialStep(id: 7, icon: "gear", title: "Customize Your View",
                   description: "Use the settings to adjust which insights you see. Start simple and add more complexity as you get comfortable with the data.",
                   subtitle: "Make insights work for you, not against you")
   ])
   
   // MARK: - Calendar View Tutorial  
   static let CalendarView: Tutorial = Tutorial(id: "calendarViewTutorial", steps: [
      TutorialStep(id: 0, icon: "calendar", title: "Your Health History",
                   description: "Welcome to your health calendar! This is where you can explore your past logs, spot patterns, and track your progress over time.",
                   subtitle: "Every day tells part of your health story"),
      
      TutorialStep(id: 1, icon: "circle.fill", title: "Daily Indicators",
                   description: "Each day shows a colored dot indicating your overall well-being. Colors help you quickly spot good days, challenging days, and patterns.",
                   subtitle: "See your health at a glance"),
      
      TutorialStep(id: 2, icon: "hand.tap", title: "Tap to Explore",
                   description: "Tap any day to see your detailed log from that date. View your mood, energy, symptoms, and notes from any day in your history.",
                   subtitle: "Dive deep into any day that interests you"),
      
      TutorialStep(id: 3, icon: "calendar.badge.clock", title: "Navigate Through Time",
                   description: "Tape the arrows to move between months. Go back as far as you want to explore your health journey.",
                   subtitle: nil),
      
      TutorialStep(id: 4, icon: "magnifyingglass", title: "Spot the Patterns",
                   description: "Look for recurring patterns - do you have better weeks? Seasonal changes? Monthly cycles? Your calendar reveals these trends.",
                   subtitle: "Patterns often tell the most important stories"),
      
      TutorialStep(id: 5, icon: "square.and.pencil", title: "Edit Past Entries",
                   description: "Forgot to log something? Want to add a note about a past day? Tap any day to edit or add to your previous entries.",
                   subtitle: "Your health history is always editable")
   ])
}
