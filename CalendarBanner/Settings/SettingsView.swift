import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @State private var newReminderMinutes: Int = 10
    @State private var launchStatusMessage: String? = nil

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                modernForm
            } else {
                legacyScrollForm
            }
        }
        .frame(width: 420, height: 600)
    }

    // MARK: - macOS 13+ grouped Form

    @available(macOS 13.0, *)
    private var modernForm: some View {
        Form {
            // 提醒时机
            Section("提醒时机") {
                ForEach(preferences.reminderMinutes.sorted(), id: \.self) { minute in
                    HStack {
                        Text("提前 \(minute) 分钟")
                        Spacer()
                        Button {
                            preferences.reminderMinutes.removeAll { $0 == minute }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    Stepper("添加：提前 \(newReminderMinutes) 分钟",
                            value: $newReminderMinutes, in: 1...60)
                    Button("添加") {
                        if !preferences.reminderMinutes.contains(newReminderMinutes) {
                            preferences.reminderMinutes.append(newReminderMinutes)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 开机启动
            Section("开机启动") {
                Toggle("开机时自动启动", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enable in
                        do {
                            if enable { try SMAppService.mainApp.register() }
                            else       { try SMAppService.mainApp.unregister() }
                            launchStatusMessage = enable ? "✓ 已开启，下次开机将自动启动"
                                                         : "✓ 已关闭，下次开机不再自动启动"
                        } catch {
                            launchStatusMessage = "操作失败：\(error.localizedDescription)"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { launchStatusMessage = nil }
                    }
                ))
                if let msg = launchStatusMessage {
                    Text(msg).font(.caption).foregroundColor(.secondary)
                }
            }

            // 横幅皮肤
            Section("横幅皮肤") {
                Picker("皮肤", selection: $preferences.bannerSkin) {
                    ForEach(BannerSkinID.selectableCases, id: \.self) { skin in
                        Text(skin.displayName).tag(skin)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            // 横幅行为
            Section("横幅行为") {
                HStack {
                    Text("自动消失时长")
                    Spacer()
                    Slider(value: $preferences.bannerDuration, in: 60...600, step: 60)
                        .frame(width: 150)
                    Text("\(Int(preferences.bannerDuration / 60)) 分钟")
                        .frame(width: 50).monospacedDigit()
                }
                HStack {
                    Text("垂直位置")
                    Spacer()
                    Slider(value: $preferences.verticalPosition, in: 0.1...0.9)
                        .frame(width: 150)
                    Text("\(Int(preferences.verticalPosition * 100))%")
                        .frame(width: 40).monospacedDigit()
                }
                Stepper("Snooze 时长：\(preferences.snoozeDuration) 分钟",
                        value: $preferences.snoozeDuration, in: 1...30)
            }

            // 显示内容
            Section("显示内容") {
                Toggle("开始时间",             isOn: $preferences.showTime)
                Toggle("倒计时（如 5分钟后）",  isOn: $preferences.showCountdown)
                Toggle("会议地点",             isOn: $preferences.showLocation)
                Toggle("会议链接",             isOn: $preferences.showURL)
                Toggle("参与人数",             isOn: $preferences.showAttendeeCount)
                Toggle("结束时间",             isOn: $preferences.showEndTime)
            }

            // 提醒音效
            Section("提醒音效") {
                HStack {
                    Picker("铃声", selection: $preferences.alertSound) {
                        ForEach(PreferencesStore.alertSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("试听") { playPreview() }
                        .buttonStyle(.bordered)
                }
                HStack {
                    Text("音量")
                    Spacer()
                    Slider(value: $preferences.alertVolume, in: 0...1, step: 0.1)
                        .frame(width: 150)
                    Text(preferences.alertVolume == 0 ? "关闭" : "\(Int(preferences.alertVolume * 100))%")
                        .foregroundColor(preferences.alertVolume == 0 ? .secondary : .primary)
                        .frame(width: 40).monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - macOS 12 ScrollView fallback

    private var legacyScrollForm: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {

                // 提醒时机
                legacySection("提醒时机") {
                    ForEach(preferences.reminderMinutes.sorted(), id: \.self) { minute in
                        legacyRow {
                            Text("提前 \(minute) 分钟")
                            Spacer()
                            Button {
                                preferences.reminderMinutes.removeAll { $0 == minute }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    legacyRow {
                        Stepper("添加：提前 \(newReminderMinutes) 分钟",
                                value: $newReminderMinutes, in: 1...60)
                        Button("添加") {
                            if !preferences.reminderMinutes.contains(newReminderMinutes) {
                                preferences.reminderMinutes.append(newReminderMinutes)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // 开机启动
                legacySection("开机启动") {
                    legacyRow {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("请在「系统偏好设置 → 用户与群组 → 登录项」中手动添加 MeetBell。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("打开登录项设置") {
                                NSWorkspace.shared.open(
                                    URL(string: "x-apple.systempreferences:com.apple.preferences.users")!
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // 横幅皮肤
                legacySection("横幅皮肤") {
                    Picker("皮肤", selection: $preferences.bannerSkin) {
                        ForEach(BannerSkinID.selectableCases, id: \.self) { skin in
                            Text(skin.displayName).tag(skin)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                // 横幅行为
                legacySection("横幅行为") {
                    legacyRow {
                        Text("自动消失时长").frame(width: 90, alignment: .leading)
                        Slider(value: $preferences.bannerDuration, in: 60...600, step: 60)
                        Text("\(Int(preferences.bannerDuration / 60)) 分钟")
                            .frame(width: 46).monospacedDigit()
                    }
                    legacyRow {
                        Text("垂直位置").frame(width: 90, alignment: .leading)
                        Slider(value: $preferences.verticalPosition, in: 0.1...0.9)
                        Text("\(Int(preferences.verticalPosition * 100))%")
                            .frame(width: 46).monospacedDigit()
                    }
                    legacyRow {
                        Stepper("Snooze 时长：\(preferences.snoozeDuration) 分钟",
                                value: $preferences.snoozeDuration, in: 1...30)
                    }
                }

                // 显示内容
                legacySection("显示内容") {
                    legacyRow { Toggle("开始时间",             isOn: $preferences.showTime) }
                    legacyRow { Toggle("倒计时（如 5分钟后）",  isOn: $preferences.showCountdown) }
                    legacyRow { Toggle("会议地点",             isOn: $preferences.showLocation) }
                    legacyRow { Toggle("会议链接",             isOn: $preferences.showURL) }
                    legacyRow { Toggle("参与人数",             isOn: $preferences.showAttendeeCount) }
                    legacyRow { Toggle("结束时间",             isOn: $preferences.showEndTime) }
                }

                // 提醒音效
                legacySection("提醒音效") {
                    legacyRow {
                        Picker("铃声", selection: $preferences.alertSound) {
                            ForEach(PreferencesStore.alertSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Button("试听") { playPreview() }
                            .buttonStyle(.bordered)
                    }
                    legacyRow {
                        Text("音量").frame(width: 90, alignment: .leading)
                        Slider(value: $preferences.alertVolume, in: 0...1, step: 0.1)
                        Text(preferences.alertVolume == 0 ? "关闭" : "\(Int(preferences.alertVolume * 100))%")
                            .foregroundColor(preferences.alertVolume == 0 ? .secondary : .primary)
                            .frame(width: 46).monospacedDigit()
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Legacy helpers

    @ViewBuilder
    private func legacySection<Content: View>(_ title: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func legacyRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider().padding(.leading, 14)
        }
    }

    // MARK: - Shared

    private func playPreview() {
        let vol = preferences.alertVolume > 0 ? preferences.alertVolume : 0.8
        if let sound = NSSound(named: NSSound.Name(preferences.alertSound)) {
            sound.volume = Float(vol)
            sound.play()
        }
    }
}

#Preview {
    SettingsView(preferences: PreferencesStore())
}
