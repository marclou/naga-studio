import SwiftUI

struct BarHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 14) {
            Color.clear.frame(width: 62, height: 1)
            MarkBrand()
            Text("Naga Studio")
                .font(Theme.display(19, .bold))
                .foregroundStyle(Theme.textPrimary)
            MenuProfile()
            Spacer()
            ChipDevice()
            HStack(spacing: 10) {
                Text("Remapping")
                    .font(Theme.display(13, .medium))
                    .foregroundStyle(Theme.textSecondary)
                ToggleRazer(isOn: $model.settings.isRemappingEnabled)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .chamferedCard(cut: 8)
        }
        .padding(.horizontal, 18)
        .frame(height: 66)
        .background(Theme.ink.opacity(0.55))
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Theme.green.opacity(0.65), Theme.green.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }
}

struct MarkBrand: View {
    var body: some View {
        ZStack {
            ChamferedRectangle(cut: 7).fill(Theme.green.opacity(0.12))
            ChamferedRectangle(cut: 7).strokeBorder(Theme.green.opacity(0.6))
            Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
                ForEach(0..<3, id: \.self) { _ in
                    GridRow {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1).fill(Theme.green).frame(width: 3.5, height: 3.5)
                        }
                    }
                }
            }
            .neonGlow(radius: 3)
        }
        .frame(width: 30, height: 30)
    }
}

struct MenuProfile: View {
    @Environment(AppModel.self) private var model
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        @Bindable var model = model
        Menu {
            Picker("Profile", selection: $model.activeProfileID) {
                ForEach(model.settings.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("New profile") { model.addProfile() }
            Button("Duplicate profile") { model.duplicateActiveProfile() }
            Button("Rename profile…") {
                draftName = model.activeProfile.name
                isRenaming = true
            }
            Divider()
            Button("Reset all buttons") { model.resetActiveProfile() }
            Button("Delete profile…", role: .destructive) { isConfirmingDelete = true }
                .disabled(model.settings.profiles.count < 2)
        } label: {
            HStack(spacing: 8) {
                Text("Profile")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(model.activeProfile.name)
                    .font(Theme.display(13, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .chamferedCard(cut: 7)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .alert("Rename profile", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Save") { model.renameActiveProfile(to: draftName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete “\(model.activeProfile.name)”?", isPresented: $isConfirmingDelete) {
            Button("Delete profile", role: .destructive) { model.deleteActiveProfile() }
        } message: {
            Text("Its button assignments go away with it.")
        }
    }
}

struct ChipDevice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let device = model.device
        HStack(spacing: 10) {
            Circle()
                .fill(device.isConnected ? Theme.green : Theme.textTertiary)
                .frame(width: 7, height: 7)
                .neonGlow(radius: 4, isOn: device.isConnected)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(Theme.display(13, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle(for: device))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            if device.isConnected, let level = device.batteryLevel {
                GlyphBattery(level: level)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .chamferedCard(cut: 8)
    }

    private func subtitle(for device: DeviceStatus) -> String {
        guard device.isConnected else { return "Not connected" }
        return [device.transportLabel, device.batteryLevel.map { "\($0)%" }].compactMap { $0 }.joined(separator: " · ")
    }
}

struct GlyphBattery: View {
    let level: Int

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(Theme.textSecondary, lineWidth: 1)
                    .frame(width: 23, height: 12)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(level <= 20 ? Theme.amber : Theme.green)
                    .frame(width: max(2, 19 * CGFloat(level) / 100), height: 8)
                    .padding(.leading, 2)
                    .neonGlow(radius: 3, isOn: level > 20)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.textSecondary)
                .frame(width: 1.5, height: 4)
        }
    }
}
