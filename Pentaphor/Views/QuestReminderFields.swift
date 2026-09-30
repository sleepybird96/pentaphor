import SwiftUI
import PentaphorCore

struct QuestReminderFields: View {
    @Binding var isEnabled: Bool
    @Binding var reminder: QuestReminder
    let timeZoneID: String
    let globallyEnabled: Bool
    @Environment(QuestReminderService.self) private var reminderService
    @Environment(\.openURL) private var openURL

    private var weekdays: [(value: Int, name: String)] {
        [2, 3, 4, 5, 6, 7, 1].map { ($0, LocalizedDisplayFormat.weekday($0, locale: Locale(identifier: AppLocalization.current.language))) }
    }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }
    private var selectedTime: Binding<Date> {
        Binding(get: {
            calendar.date(from: DateComponents(year: 2001, month: 1, day: 15,
                                               hour: reminder.hour, minute: reminder.minute)) ?? .now
        }, set: { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            reminder.hour = components.hour ?? reminder.hour
            reminder.minute = components.minute ?? reminder.minute
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(AppLocalization.string("QuestReminderFields.8"), isOn: $isEnabled)
                .font(.headline).frame(minHeight: 44)
                .accessibilityIdentifier("quest.reminder.enabled")
            Text(AppLocalization.string("QuestReminderFields.9"))
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            if isEnabled {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 5)], spacing: 7) {
                    ForEach(weekdays, id: \.value) { day in
                        let selected = reminder.weekdays.contains(day.value)
                        Button {
                            if selected { reminder.weekdays.removeAll { $0 == day.value } }
                            else { reminder.weekdays.append(day.value) }
                        } label: {
                            Text(day.name).font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(selected ? Palette.paper : Palette.ink)
                                .background(selected ? Palette.teal : Palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                            .accessibilityLabel(LocalizedDisplayFormat.weekday(day.value, locale: Locale(identifier: AppLocalization.current.language), full: true))
                            .accessibilityValue(selected ? AppLocalization.string("QuestReminderFields.11") : AppLocalization.string("QuestReminderFields.12"))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("quest.reminder.weekday.\(day.value)")
                    }
                }
                if reminder.weekdays.isEmpty {
                    Text(AppLocalization.string("QuestReminderFields.13"))
                        .font(.caption).foregroundStyle(Palette.teal)
                }
                DatePicker(AppLocalization.string("QuestReminderFields.14"), selection: selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact).frame(minHeight: 44)
                    .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
                    .accessibilityIdentifier("quest.reminder.time")
                HStack(spacing: 4) {
                    Text(AppLocalization.string("QuestReminderFields.15"))
                    Text(selectedTime.wrappedValue.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone)))
                        .accessibilityIdentifier("quest.reminder.time.summary")
                }.font(.caption).foregroundStyle(Palette.muted)
                Text(AppLocalization.format("QuestReminderFields.16", AppLocalization.argument(timeZoneID)))
                    .font(.caption).foregroundStyle(Palette.muted)
                if !globallyEnabled {
                    Text(AppLocalization.string("QuestReminderFields.17"))
                        .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                }
                if reminderService.authorization == .denied {
                    Text(AppLocalization.string("QuestReminderFields.18"))
                        .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                    Button(AppLocalization.string("QuestReminderFields.19")) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }.font(.subheadline.bold()).frame(minHeight: 44)
                        .accessibilityIdentifier("quest.reminder.settings")
                }
            }
        }.onChange(of: isEnabled) { _, enabled in
            if enabled && globallyEnabled { Task { await reminderService.requestPermission() } }
        }
    }
}
