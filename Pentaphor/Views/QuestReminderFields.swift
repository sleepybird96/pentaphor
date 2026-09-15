import SwiftUI
import PentaphorCore

struct QuestReminderFields: View {
    @Binding var isEnabled: Bool
    @Binding var reminder: QuestReminder
    let timeZoneID: String
    let globallyEnabled: Bool
    @Environment(QuestReminderService.self) private var reminderService
    @Environment(\.openURL) private var openURL

    private let weekdays: [(value: Int, name: String)] = [
        (2, "월"), (3, "화"), (4, "수"), (5, "목"), (6, "금"), (7, "토"), (1, "일")
    ]
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
            Toggle("퀘스트 알림", isOn: $isEnabled)
                .font(.headline).frame(minHeight: 44)
                .accessibilityIdentifier("quest.reminder.enabled")
            Text("목표를 아직 채우지 않았다면, 고른 요일에 알려줘.")
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
                            .accessibilityLabel("\(day.name)요일")
                            .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("quest.reminder.weekday.\(day.value)")
                    }
                }
                if reminder.weekdays.isEmpty {
                    Text("알림을 받을 요일을 하나 이상 골라줘.")
                        .font(.caption).foregroundStyle(Palette.teal)
                }
                DatePicker("알림 시각", selection: selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact).frame(minHeight: 44)
                    .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
                    .accessibilityIdentifier("quest.reminder.time")
                HStack(spacing: 4) {
                    Text("선택한 요일마다")
                    Text(String(format: "%02d:%02d", reminder.hour, reminder.minute))
                        .accessibilityIdentifier("quest.reminder.time.summary")
                }.font(.caption).foregroundStyle(Palette.muted)
                Text("\(timeZoneID) 기준 · 저장하면 적용돼.")
                    .font(.caption).foregroundStyle(Palette.muted)
                if !globallyEnabled {
                    Text("전체 알림이 꺼져 있어. 저장한 알림을 받으려면 설정에서 퀘스트 알림을 켜줘.")
                        .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                }
                if reminderService.authorization == .denied {
                    Text("아이폰에서 알림이 꺼져 있어. 설정을 허용하면 저장한 요일과 시각으로 다시 알릴 수 있어.")
                        .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                    Button("아이폰 알림 설정 열기") {
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
