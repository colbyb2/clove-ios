import SwiftUI

@Observable
class PopupManager {
   static let shared = PopupManager()
   
   var currentPopup: Popup?
   var stack: [Popup] = []
   
   let defaults = UserDefaults.standard
   
   private init() {
      check()
   }
   
   func check() {
      // Clear existing stack to prevent duplicates
      stack.removeAll()
      
      Popups.all.forEach { popup in
         let isDismissed = defaults.bool(forKey: popup.id)
         
         if !isDismissed {
            // Only add if not already in stack and not currently displayed
            if !stack.contains(where: { $0.id == popup.id }) && currentPopup?.id != popup.id {
               self.stack.append(popup)
            }
         }
      }
      
      
      // Only set currentPopup if we don't already have one displayed
      if currentPopup == nil && !stack.isEmpty {
         self.currentPopup = stack.popLast()
      }
   }
   
   func close() {
      guard let popup = currentPopup else { return }
      
      print("Setting popup: \(popup.id) to True")
      defaults.set(true, forKey: popup.id)
      
      // Force UserDefaults to synchronize immediately
      defaults.synchronize()
      
      // Clear the current popup first
      self.currentPopup = nil
      
      // Then check if there are more popups to show
      if !stack.isEmpty {
         self.currentPopup = stack.popLast()
      }
   }
   
   // Method to manually refresh popup check (useful for debugging or force refresh)
   func refresh() {
      check()
   }
   
   // Method to manually dismiss all popups (useful for debugging)
   func dismissAll() {
      currentPopup = nil
      stack.removeAll()
   }
}

enum PopupType {
    case terms
    case whatsNew
}

struct Popup: Identifiable, Equatable {
    let id: String
    let type: PopupType
    var icon: String? = nil
    let title: String
    let message: String
    let features: [WhatsNewFeature]?
    let version: String?
    
    init(id: String, type: PopupType = .terms, icon: String? = nil, title: String, message: String, features: [WhatsNewFeature]? = nil, version: String? = nil) {
        self.id = id
        self.type = type
        self.icon = icon
        self.title = title
        self.message = message
        self.features = features
        self.version = version
    }
    
    static func == (lhs: Popup, rhs: Popup) -> Bool {
        return lhs.id == rhs.id
    }
}

enum Popups {
   static let all: [Popup] = [
      Popup(
              id: "termsAndConditions",
              type: .terms,
              title: "Terms and Conditions",
              message: """
              Terms and Conditions of Use
              
              Last Updated: July 24th, 2025
              
              IMPORTANT: Please read these Terms and Conditions carefully before using this application.
              
              1. ACCEPTANCE OF TERMS
              By downloading, installing, or using Clove, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree with these terms, please do not use the App.
              
              2. NATURE OF THE APPLICATION
              This App is a FREE, OPEN SOURCE personal health tracking tool designed to help you:
              • Record and organize your personal health data
              • Track symptoms, mood, medications, and other health metrics
              • Visualize your data through charts and analytics
              • Generate mathematical insights based on correlation coefficients and statistical analysis
              • Maintain ownership and control of your personal health information
              
              3. NOT MEDICAL ADVICE - USE AT YOUR OWN RISK
              ⚠️ CRITICAL DISCLAIMER: This App is NOT a medical device and does NOT provide medical advice, diagnosis, or treatment recommendations.
              
              • All content, features, and insights are for informational purposes only
              • Mathematical correlations and statistical analyses do NOT constitute medical guidance
              • The App cannot replace professional medical consultation, diagnosis, or treatment
              • Any insights generated are based solely on mathematical formulas and data patterns
              • You use this App entirely at your own risk and discretion
              
              4. MEDICAL PROFESSIONAL CONSULTATION
              • Always consult qualified healthcare professionals for medical decisions
              • Never delay, disregard, or discontinue medical treatment based on App content
              • Share App data with your healthcare team only as supplementary information
              • Emergency situations require immediate professional medical attention, not App usage
              
              5. DATA OWNERSHIP AND RESPONSIBILITY
              You retain full ownership of all data you input into the App, including:
              • Personal health information and symptoms
              • Medication records and dosages  
              • Mood and wellness tracking data
              • Any notes, observations, or custom entries
              
              You are solely responsible for:
              • The accuracy and completeness of data you enter
              • Deciding how to interpret or act upon App-generated insights
              • Maintaining appropriate backups of your important health data
              • Understanding that data loss may occur due to technical issues
              
              6. LIMITATIONS AND RISKS
              By using this App, you acknowledge and accept the following risks:
              
              Technical Risks:
              • Software bugs, crashes, or unexpected behavior may occur
              • Data synchronization issues or loss may happen
              • App performance may vary across different devices and operating systems
              • Updates may change functionality or require data migration
              
              Health-Related Risks:
              • Misinterpretation of statistical correlations as causation
              • Over-reliance on mathematical insights without medical context
              • False sense of security from tracking data without professional oversight
              • Potential anxiety or distress from data patterns or trends
              
              7. OPEN SOURCE NATURE
              This App is provided as open source software, which means:
              • Source code is publicly available for review and modification
              • Community contributions may affect functionality
              • No warranty is provided regarding performance or reliability
              • Users may create modified versions with different behaviors
              • Support and maintenance depend on community involvement
              
              8. NO WARRANTIES
              The App is provided "AS IS" without warranties of any kind, including:
              • Fitness for a particular purpose
              • Accuracy of calculations or statistical analyses
              • Uninterrupted or error-free operation
              • Compatibility with your specific health conditions
              • Security against all potential data breaches
              
              9. LIMITATION OF LIABILITY
              To the fullest extent permitted by law:
              • Developers and contributors are not liable for any damages arising from App use
              • This includes direct, indirect, incidental, consequential, or punitive damages
              • No liability exists for health decisions made based on App insights
              • Users assume all risks associated with health data interpretation
              
              10. STATISTICAL ANALYSIS DISCLAIMER
              Mathematical insights and correlations provided by the App:
              • Are based on statistical formulas and data patterns only
              • Do not account for medical context, comorbidities, or individual circumstances
              • May identify spurious correlations without clinical significance
              • Should never be used as the basis for medical decisions
              • Require professional interpretation within proper medical context
              
              11. PRIVACY AND DATA SECURITY
              While we implement reasonable security measures:
              • No system is 100% secure against all potential threats
              • You are responsible for protecting your device and app access
              • Consider the sensitivity of health data you choose to store
              
              12. AGE RESTRICTIONS
              This App is intended for users 18 years of age and older. Users under 18 should:
              • Obtain parental or guardian consent before use
              • Use the App under adult supervision
              • Understand that pediatric health tracking requires professional guidance
              
              13. MODIFICATIONS TO TERMS
              These Terms may be updated periodically to reflect:
              • Changes in App functionality
              • Legal or regulatory requirements
              • Community feedback and best practices
              • Enhanced safety disclaimers
              
              Continued use after updates constitutes acceptance of modified Terms.
              
              14. GOVERNING LAW
              These Terms are governed by applicable local laws. Any disputes will be resolved through appropriate legal channels in your jurisdiction.
              
              15. CONTACT INFORMATION
              For questions about these Terms:
              • Review the open source documentation
              • Consult community forums and support channels
              • Contact the development team through official channels
              
              16. FINAL ACKNOWLEDGMENT
              By using this App, you confirm that you:
              ✓ Understand this is a tracking tool, not medical software
              ✓ Will not rely on App insights for medical decisions
              ✓ Accept all risks associated with personal health data tracking
              ✓ Will consult healthcare professionals for medical guidance
              ✓ Understand the open source nature and associated limitations
              ✓ Take full responsibility for how you use and interpret your data
              
              Remember: Your health is precious. This App is a tool to help you track and understand your data, but your healthcare team provides the medical expertise needed for proper health management.
              
              By clicking "Done" below, you acknowledge that you have read, understood, and agree to all terms outlined above.
              """
          ),
   ] + WhatsNewContent.allWhatsNewPopups
}
