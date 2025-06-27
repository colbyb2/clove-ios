import SwiftUI

struct TodayView: View {
   @State var viewModel = TodayViewModel()
   
   @State private var showEditSymptoms: Bool = true
   @State private var newSymptom: String = ""
   @State private var newSymptoms: [TrackedSymptom] = []
   
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 24) {
            
            if viewModel.settings.trackMood {
               ZStack {
                  HStack {
                     Text("Mood").font(.system(size: 22, weight: .semibold, design: .rounded))
                     Spacer()
                  }
                  HStack {
                     Spacer()
                     Text("\(Int(viewModel.mood))\(viewModel.currentMoodEmoji)")
                        .font(.system(size: 28, weight: .bold))
                     Spacer()
                  }
               }
               CloveSlider(value: 0.5, height: 40) { value in
                  viewModel.mood = value
               }
            }
            
            if viewModel.settings.trackPain {
               ZStack {
                  HStack {
                     Text("Pain").font(.system(size: 22, weight: .semibold, design: .rounded))
                     Spacer()
                  }
                  HStack {
                     Spacer()
                     Text("\(Int(viewModel.painLevel))")
                        .font(.system(size: 28, weight: .bold))
                     Spacer()
                  }
               }
               CloveSlider(value: 0.5, height: 40) { value in
                  viewModel.painLevel = value
               }
            }
            
            if viewModel.settings.trackEnergy {
               ZStack {
                  HStack {
                     Text("Energy").font(.system(size: 22, weight: .semibold, design: .rounded))
                     Spacer()
                  }
                  HStack {
                     Spacer()
                     Text("\(Int(viewModel.energyLevel))")
                        .font(.system(size: 28, weight: .bold))
                     Spacer()
                  }
               }
               CloveSlider(value: 0.5, height: 40) { value in
                  viewModel.energyLevel = value
               }
            }
            
            if viewModel.settings.trackSymptoms {
               HStack {
                  Text("Symptoms").font(.system(size: 22, weight: .semibold, design: .rounded))
                  Spacer()
                  Button("Edit") { showEditSymptoms = true }
                     .foregroundStyle(CloveColors.primaryText)
               }
               ForEach(viewModel.symptomRatings.indices, id: \.self) { i in
                  let symptom = viewModel.symptomRatings[i]
                  VStack(alignment: .leading) {
                     ZStack {
                        HStack {
                           Text(symptom.symptomName).font(.system(size: 18, weight: .semibold, design: .rounded))
                              .foregroundStyle(CloveColors.secondaryText)
                           Spacer()
                        }
                        HStack {
                           Spacer()
                           Text("\(Int(viewModel.symptomRatings[i].ratingDouble))").font(.system(size: 26, weight: .semibold, design: .rounded))
                              .foregroundStyle(CloveColors.secondaryText)
                           Spacer()
                        }
                     }
                     CloveSlider(value: 0.5, height: 40) { value in
                        viewModel.symptomRatings[i].ratingDouble = value
                     }
                  }
               }
               if (viewModel.symptomRatings.isEmpty) {
                  HStack {
                     Spacer()
                     Text("No Symptoms Being Tracked")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                     Spacer()
                  }
               }
            }
            
            if viewModel.settings.showFlareToggle {
               HStack {
                  Spacer()
                  Text("Flare Up?").font(.system(size: 18, weight: .semibold, design: .rounded))
                  CloveToggle(toggled: $viewModel.isFlareDay, onColor: .error, handleColor: .card.opacity(0.6))
                  Spacer()
               }
            }
            
            CloveButton(text: "Save", background: .blue) {
               viewModel.saveLog()
            }
            
//            Button("DEV - Add Logs") {
//               DEVCreateLogs.execute()
//            }
         }
         .padding()
      }
      .navigationTitle("Today")
      .onAppear {
         viewModel.load()
      }
      .sheet(isPresented: $showEditSymptoms) {
         VStack(spacing: 30) {
            Text("Tracked Symptoms").font(.system(size: 22, weight: .semibold, design: .rounded))
            HStack {
               TextField("New Symptom", text: $newSymptom)
                  .padding(10)
                  .font(.system(size: 24))
                  .frame(height: 45)
                  .background(CloveColors.background)
                  .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
               Button {} label: {
                  Image(systemName: "plus.circle.fill")
                     .resizable()
                     .scaledToFit()
                     .frame(width: 40)
                     .foregroundStyle(CloveColors.primary)
               }
            }
            List {
               ForEach(viewModel.symptomRatings.indices, id: \.self) { i in
                  let symptom = viewModel.symptomRatings[i]
                  HStack {
                     Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color(hex: "b17ad6"))
                     
                     Text("\(symptom.symptomName)")
                        .font(.system(size: 22))
                  }
                  .padding(5)
               }
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
         }
         .padding()
         .background(CloveColors.card)
         .clipShape(RoundedRectangle(cornerRadius: 20))
         .padding(5)
         .presentationDetents([.medium])
         .presentationDragIndicator(.hidden)
         .presentationBackground(.clear)
      }
   }
}

#Preview {
   NavigationStack {
      TodayView(viewModel: TodayViewModel(settings: UserSettings(trackMood: true, trackPain: true, trackEnergy: true, trackSymptoms: true, trackMeals: false, trackActivities: false, trackMeds: false, showFlareToggle: true)))
   }
}
