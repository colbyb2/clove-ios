import SwiftUI

struct CloveSlider: View {
   @State var value: Double = 0.0
   var barColor: Color = CloveColors.primary
   var backgroundColor: Color = .gray
   
   var height: CGFloat = 70
   
   var snapBarColor: Color = .white
   
   var options: SliderOptions = SliderOptions(start: 0, end: 10, interval: 1)
   
   var onChange: (Double) -> Void = {_ in}
   
   @State var isDragging: Bool = false
   @State var lastWidth: CGFloat = .zero
   @State private var hasAppeared: Bool = false
   
   var body: some View {
      ZStack {
         GeometryReader { proxy in
            ZStack {
               backgroundColor
               
               HStack {
                  barColor
                     .frame(width: value * proxy.size.width)
                  Spacer()
               }
               
               if let interval = options.interval  {
                  HStack {
                     ForEach(options.start...options.end, id: \.self) { num in
                        if num % interval != 0 {
                           EmptyView()
                        } else {
                           if num != options.start {
                              Spacer()
                           }
                           Rectangle()
                              .frame(width: 2)
                              .padding(.vertical, 5)
                              .foregroundStyle(snapBarColor.opacity(0.2))
                           if num != options.end {
                              Spacer()
                           }
                        }
                     }
                  }
               }
            }
            .gesture(
               DragGesture()
               .onChanged({ value in
                  isDragging = true
                  var newValue = (self.lastWidth + value.translation.width) / proxy.size.width
                  
                  let relEnd = 1.0
                  let relStart = Double(options.start) / Double(options.end)
                  
                  if newValue < relStart {
                     newValue = relStart
                  } else if newValue > relEnd {
                     newValue = relEnd
                  }
                  
                  self.value = newValue
                  guard options.interval != nil else {
                     onChange(newValue * Double(options.end))
                     return
                  }
                  let broadcastedValue: Double = calculateSnap() ?? self.value
                  onChange(broadcastedValue * Double(options.end))
                  
               })
               .onEnded({ value in
                  isDragging = false
                  self.lastWidth = self.value * proxy.size.width
                  if let snappedValue = calculateSnap() {
                     self.value = snappedValue
                  }
               })
            )
            .onChange(of: proxy.size.width) { _, newWidth in
               // Update lastWidth when the container size changes
               if !isDragging {
                  self.lastWidth = self.value * newWidth
               }
            }
            .onAppear {
               // Delay the initialization slightly to ensure layout is complete
               DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                  if !hasAppeared {
                     self.lastWidth = self.value * proxy.size.width
                     hasAppeared = true
                  }
               }
            }
         }
      }
      .frame(height: height)
      .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
      .animation(.smooth(), value: isDragging)
   }
   
   func calculateSnap() -> Double? {
      if let interval = options.interval {
         let rounded = Int(self.value * Double(options.end))
         let rem = rounded % interval
         return Double(rounded - rem) / Double(options.end)
      }
      
      return nil
   }
}

struct EmojiSlider: View {
   @Binding var value: Double
   var icon: Character = "😁"
   var emojiMap: [ClosedRange<Double>: Character]? = nil
   
   var options: SliderOptions = SliderOptions(start: 0, end: 10, interval: 1)
   
   @State var isDragging: Bool = false
   @State var lastOffset: CGFloat = 0.0
   @State private var sliderWidth: CGFloat = 0.0
   @State private var visualOffset: CGFloat = 0.0 // For smooth visual movement
   
   private var currentEmoji: Character {
      if let emojiMap = emojiMap {
         for (range, emoji) in emojiMap {
            if range.contains(value) {
               return emoji
            }
         }
      }
      return icon
   }
   
   var body: some View {
      ZStack {
         GeometryReader { proxy in
            let availableWidth = proxy.size.width - 30 // Account for emoji width
            let currentOffset = isDragging ? visualOffset : CGFloat(value / Double(options.end)) * availableWidth
            
            ZStack {
               // Track
               RoundedRectangle(cornerRadius: CloveCorners.small)
                  .frame(height: 8)
                  .foregroundStyle(.gray)
               
               // Emoji thumb
               HStack {
                  Text(verbatim: String(currentEmoji))
                     .font(.system(size: 45))
                     .offset(x: currentOffset)
                     .animation(.interactiveSpring(), value: currentOffset)
                  Spacer()
               }
               .padding(.leading, -5)
            }
            .onAppear {
               sliderWidth = availableWidth
               lastOffset = currentOffset
               visualOffset = currentOffset
            }
            .gesture(
               DragGesture(coordinateSpace: .local)
                  .onChanged({ gesture in
                     self.isDragging = true
                     
                     // Calculate new position for visual display
                     var newOffset = lastOffset + gesture.translation.width
                     
                     // Clamp to valid range
                     newOffset = max(-5, min(newOffset, availableWidth))
                     visualOffset = newOffset
                     
                     // Convert offset to raw value
                     let rawValue = (newOffset / availableWidth) * Double(options.end)
                     
                     // Calculate snapped value for binding
                     if let interval = options.interval {
                        let rounded = Int(rawValue)
                        let rem = rounded % interval
                        let snappedValue = Double(rounded - rem)
                        self.value = max(Double(options.start), min(snappedValue, Double(options.end)))
                     } else {
                        self.value = max(Double(options.start), min(rawValue, Double(options.end)))
                     }
                  })
                  .onEnded({ _ in
                     self.isDragging = false
                     
                     // Snap the visual position on release
                     if options.interval != nil {
                        let snappedValue = value
                        visualOffset = CGFloat(snappedValue / Double(options.end)) * availableWidth
                     }
                     
                     self.lastOffset = visualOffset
                  })
            )
         }
      }
      .frame(height: 60)
   }
}

struct SliderOptions {
   let start: Int
   let end: Int
   var interval: Int? = nil
}

fileprivate struct SliderPreview: View {
   let snapOptions = SliderOptions(start: 0, end: 10, interval: 1)
   
   @State var value: Int = 5
   
   @State var emojiValue: Double = 0.0
   
   // Emoji map for different value ranges
   let moodEmojiMap: [ClosedRange<Double>: Character] = [
      0.0...2.0: "😢",
      2.1...4.0: "😕",
      4.1...6.0: "😐",
      6.1...8.0: "🙂",
      8.1...10.0: "😁"
   ]
   
   var body: some View {
      VStack {
         Text("\(value)")
            .font(.largeTitle)
         CloveSlider(value: 0.3, barColor: .blue, options: snapOptions) { changedValue in
            self.value = Int(changedValue)
         }
         Text("\(Int(emojiValue))")
            .font(.largeTitle)
         EmojiSlider(value: $emojiValue, emojiMap: moodEmojiMap, options: snapOptions)
      }
   }
}

#Preview {
   SliderPreview()
}
