import SwiftUI

struct SymptomSelectionView: View {
   @Environment(OnboardingViewModel.self) var viewModel
   @FocusState private var isTextFieldFocused: Bool
   
   @State var symptomName: String = ""
   
   var body: some View {
      VStack {
         VStack(spacing: 20) {
            Text("What symptoms do you want to track?")
               .font(.system(.title, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primary)
            
            Text("Add the symptoms that matter most to you. You can always add more later.")
               .foregroundStyle(CloveColors.secondaryText)
         }
         .multilineTextAlignment(.center)
         .padding(.top, 50)
         .padding(.horizontal)
         
         VStack(spacing: 20) {
            // Symptom input field
            HStack {
               TextField("Enter symptom name", text: $symptomName)
                  .padding()
                  .background(CloveColors.card)
                  .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                  .focused($isTextFieldFocused)
                  .submitLabel(.done)
                  .onSubmit {
                     viewModel.addSymptom(name: symptomName)
                     symptomName = ""
                  }
               
               Button(action: {
                  viewModel.addSymptom(name: symptomName)
                  symptomName = ""
                  isTextFieldFocused = true
               }) {
                  Image(systemName: "plus.circle.fill")
                     .resizable()
                     .frame(width: 30, height: 30)
                     .foregroundStyle(CloveColors.primary)
               }
               .disabled(symptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            // List of added symptoms
            if viewModel.trackedSymptoms.isEmpty {
               VStack(spacing: 15) {
                  Image(systemName: "list.bullet.clipboard")
                     .resizable()
                     .scaledToFit()
                     .frame(width: 50, height: 50)
                     .foregroundStyle(Color(hex: "b17ad6").opacity(0.5))
                  
                  Text("No symptoms added yet")
                     .foregroundStyle(CloveColors.secondaryText)
               }
               .frame(maxWidth: .infinity)
               .padding(.vertical, 40)
            } else {
               List {
                  ForEach(viewModel.trackedSymptoms, id: \.name) { symptom in
                     HStack {
                        Image(systemName: "circle.fill")
                           .resizable()
                           .frame(width: 10, height: 10)
                           .foregroundStyle(Color(hex: "b17ad6"))
                        
                        Text(symptom.name)
                           .font(.system(size: 22))
                     }
                     .padding(5)
                  }
                  .onDelete(perform: viewModel.removeSymptom)
               }
               .background(Color.clear)
               .scrollContentBackground(.hidden)
               .frame(maxHeight: 300)
            }
            
            Spacer()
            
            // Common symptoms suggestions
            if viewModel.trackedSymptoms.isEmpty {
               VStack(alignment: .leading, spacing: 10) {
                  Text("Common symptoms")
                     .font(.headline)
                     .foregroundStyle(CloveColors.secondaryText)
                  
                  ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: 10) {
                        suggestionChip("Fatigue")
                        suggestionChip("Headache")
                        suggestionChip("Joint Pain")
                        suggestionChip("Brain Fog")
                        suggestionChip("Nausea")
                     }
                  }
               }
               .padding(.horizontal)
            }
         }
         .padding(.vertical)
         
         Spacer()
         
         // Continue button
         CloveButton(
            text: viewModel.trackedSymptoms.isEmpty ? "Add at least one..." : "Continue",
            fontColor: .white
         ) {
            viewModel.nextStep()
         }
         .padding(.horizontal)
         .padding(.bottom, 24)
         .disabled(viewModel.trackedSymptoms.isEmpty)
      }
      .onAppear {
         isTextFieldFocused = true
      }
   }
   
   private func suggestionChip(_ symptom: String) -> some View {
      Button(action: {
         viewModel.addSymptom(name: symptom)
      }) {
         Text(symptom)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CloveColors.card)
            .foregroundStyle(CloveColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.full))
      }
   }
}

#Preview {
   SymptomSelectionView()
      .environment(OnboardingViewModel())
}
