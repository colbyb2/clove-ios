import SwiftUI

struct SleepTracker: View {
    let period: SleepPeriod?
    let dayKey: String
    let onSave: (SleepPeriod?) -> Void
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 42, height: 42)
                    .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep").font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text(period?.timeRangeText() ?? "Bedtime & wake-up time")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text(period?.durationText ?? "Not logged")
                    .font(.subheadline.weight(period == nil ? .regular : .semibold))
                    .foregroundStyle(period == nil ? CloveColors.secondaryText : CloveColors.primaryText)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
            }
            .padding(16)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sleep, \(period.map { "\($0.durationText), \($0.timeRangeText(includeDays: true))" } ?? "Not logged")")
        .accessibilityHint("Edit bedtime and wake-up time")
        .sheet(isPresented: $editing) {
            SleepEntryEditor(dayKey: dayKey, existing: period) { onSave($0) }
        }
    }
}

struct SleepEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    let dayKey: String
    let existing: SleepPeriod?
    let onSave: (SleepPeriod?) throws -> Void
    private let recordingTimeZone: TimeZone
    @State private var bedtime: Date
    @State private var wakeTime: Date
    @State private var errorMessage: String?

    init(dayKey: String, existing: SleepPeriod?, onSave: @escaping (SleepPeriod?) throws -> Void) {
        self.dayKey = dayKey
        self.existing = existing
        self.onSave = onSave
        let zone = existing?.timeZone ?? .current
        recordingTimeZone = zone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = LocalDayKey.date(from: dayKey, calendar: calendar) ?? Date()
        _bedtime = State(initialValue: existing?.bedtime ?? calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day) ?? day)
        _wakeTime = State(initialValue: existing?.wakeTime ?? calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = recordingTimeZone
        return value
    }

    private var period: Result<SleepPeriod, Error> {
        Result {
            guard let day = LocalDayKey.date(from: dayKey, calendar: calendar) else { throw SleepEntryError.wrongDay }
            let bed = calendar.dateComponents([.hour, .minute], from: bedtime)
            let wake = calendar.dateComponents([.hour, .minute], from: wakeTime)
            // Preserve the exact interval if an existing repeated DST hour wasn't edited.
            if let existing,
               bed == calendar.dateComponents([.hour, .minute], from: existing.bedtime),
               wake == calendar.dateComponents([.hour, .minute], from: existing.wakeTime) {
                try existing.validate(dayKey: dayKey)
                return existing
            }
            return try SleepPeriod.fromTimes(wakeDay: day, bedtimeHour: bed.hour ?? 22, bedtimeMinute: bed.minute ?? 0,
                                              wakeHour: wake.hour ?? 7, wakeMinute: wake.minute ?? 0,
                                              timeZone: recordingTimeZone)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("When did you go to bed and wake up?")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Text("Saved on the day you woke up.")
                            .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                    }
                    VStack(spacing: 16) {
                        timeInput("Bedtime", icon: "moon.fill", date: $bedtime)
                        Divider()
                        timeInput("Woke up", icon: "sun.max.fill", date: $wakeTime)
                    }
                    .padding(16)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 16))

                    switch period {
                    case .success(let period):
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Time in bed", systemImage: "bed.double.fill")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(period.durationText).font(.system(.title2, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                            }
                            Text(period.timeRangeText(includeDays: true))
                                .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                            Text("Calculated from your times. Time awake during the night isn’t subtracted.")
                                .font(.caption).foregroundStyle(CloveColors.secondaryText)
                        }
                        .padding(18)
                        .background(Theme.shared.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    case .failure(let error):
                        Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(CloveColors.error)
                    }
                    if existing != nil {
                        Button("Clear sleep entry", role: .destructive) { save(nil) }
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }
                }
                .padding(20)
            }
            .background(CloveColors.background)
            .navigationTitle(existing == nil ? "Log Sleep" : "Edit Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(CloveColors.error) }
                    Button {
                        if case .success(let value) = period { save(value) }
                    } label: {
                        Text("Save Sleep").font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
                    .disabled((try? period.get()) == nil)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8).background(.bar)
            }
            .tint(Theme.shared.accent)
            .environment(\.timeZone, recordingTimeZone)
        }
    }

    private func timeInput(_ title: String, icon: String, date: Binding<Date>) -> some View {
        DatePicker(selection: date, displayedComponents: .hourAndMinute) {
            Label(title, systemImage: icon).font(.body.weight(.medium))
                .foregroundStyle(CloveColors.primaryText)
        }
    }

    private func save(_ value: SleepPeriod?) {
        do { try onSave(value); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
