import SwiftUI
import ServiceManagement
import AppKit

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
                    Slider(value: $preferences.bannerDuration, in: 60...600, step: 60)
                        .frame(width: 150)
                    Text("\(Int(preferences.bannerDuration / 60)) 分钟")
                        .frame(width: 50)
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
                Toggle("倒计时（如 5分钟后）", isOn: $preferences.showCountdown)
                Toggle("会议地点", isOn: $preferences.showLocation)
                Toggle("会议链接", isOn: $preferences.showURL)
                Toggle("参与人数", isOn: $preferences.showAttendeeCount)
            }

            Section("提醒音效") {
                HStack {
                    Picker("铃声", selection: $preferences.alertSound) {
                        ForEach(PreferencesStore.alertSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("试听") {
                        let vol = preferences.alertVolume > 0 ? preferences.alertVolume : 0.8
                        if let sound = NSSound(named: NSSound.Name(preferences.alertSound)) {
                            sound.volume = Float(vol)
                            sound.play()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Text("音量")
                    Spacer()
                    Slider(value: $preferences.alertVolume, in: 0...1, step: 0.1)
                        .frame(width: 150)
                    Text(preferences.alertVolume == 0 ? "关闭" : "\(Int(preferences.alertVolume * 100))%")
                        .foregroundColor(preferences.alertVolume == 0 ? .secondary : .primary)
                        .frame(width: 40)
                }
            }

            Section("启动") {
                Toggle("登录时自动启动", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enable in
                        do {
                            if enable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Launch at login error: \(error)")
                        }
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }
}

#Preview {
    SettingsView(preferences: PreferencesStore())
}
