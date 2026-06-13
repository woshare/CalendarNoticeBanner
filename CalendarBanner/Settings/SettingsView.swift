import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @State private var newReminderMinutes: Int = 10

    var body: some View {
        Form {
            Section("提醒时机") {
                ForEach(preferences.reminderMinutes.sorted(), id: \.self) { minute in
                    HStack {
                        Text("提前 \(minute) 分钟")
                        Spacer()
                        Button {
                            preferences.reminderMinutes.removeAll { $0 == minute }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Stepper("添加：提前 \(newReminderMinutes) 分钟",
                            value: $newReminderMinutes,
                            in: 1...60)
                    Button("添加") {
                        if !preferences.reminderMinutes.contains(newReminderMinutes) {
                            preferences.reminderMinutes.append(newReminderMinutes)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("横幅行为") {
                HStack {
                    Text("自动消失时长")
                    Spacer()
                    Slider(value: $preferences.bannerDuration, in: 3...30, step: 1)
                        .frame(width: 150)
                    Text("\(Int(preferences.bannerDuration))秒")
                        .frame(width: 40)
                }

                HStack {
                    Text("垂直位置")
                    Spacer()
                    Slider(value: $preferences.verticalPosition, in: 0.1...0.9)
                        .frame(width: 150)
                    Text("\(Int(preferences.verticalPosition * 100))%")
                        .frame(width: 40)
                }
            }

            Section("显示内容") {
                Toggle("开始时间", isOn: $preferences.showTime)
                Toggle("倒计时（如"5分钟后"）", isOn: $preferences.showCountdown)
                Toggle("会议地点", isOn: $preferences.showLocation)
                Toggle("会议链接", isOn: $preferences.showURL)
                Toggle("参与人数", isOn: $preferences.showAttendeeCount)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
    }
}

#Preview {
    SettingsView(preferences: PreferencesStore())
}
