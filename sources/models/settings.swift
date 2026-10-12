import Foundation

nonisolated enum ScrollDirection: String, Codable, CaseIterable, Sendable {
    case standard, natural

    var title: String { self == .standard ? "Standard" : "Natural" }
}

nonisolated struct Profile: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var actions: [NagaButton: ButtonAction] = [:]
}

nonisolated struct Settings: Codable, Sendable {
    var profiles = [Profile(name: "Default")]
    var activeProfileID: UUID?
    var isRemappingEnabled = true
    var scrollDirection = ScrollDirection.standard
    var learnedInputs: [NagaButton: NagaInput] = [:]

    private static let storageKey = "settings.v1"

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([Profile].self, forKey: .profiles) ?? profiles
        activeProfileID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        isRemappingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRemappingEnabled) ?? isRemappingEnabled
        scrollDirection = try container.decodeIfPresent(ScrollDirection.self, forKey: .scrollDirection) ?? scrollDirection
        learnedInputs = try container.decodeIfPresent([NagaButton: NagaInput].self, forKey: .learnedInputs) ?? [:]
        if profiles.isEmpty { profiles = [Profile(name: "Default")] }
    }

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
