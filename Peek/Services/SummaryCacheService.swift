import Foundation

struct CachedSummary: Codable {
    let summary: String
    let riskLevel: String
    let riskReason: String
    let updatedAt: String // Jira's updated timestamp — cache key
}

@MainActor
final class SummaryCacheService {
    static let shared = SummaryCacheService()
    private init() { cache = Self.load() }

    private var cache: [String: CachedSummary] // keyed by ticket key

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("am.adam.peek", isDirectory: true)
        return dir.appendingPathComponent("summary_cache.json")
    }

    func get(key: String, updatedAt: String?) -> CachedSummary? {
        guard let entry = cache[key] else { return nil }
        // Only hit cache if the ticket hasn't been updated since
        guard let updatedAt, entry.updatedAt == updatedAt else { return nil }
        return entry
    }

    func set(key: String, summary: String, riskLevel: String, riskReason: String, updatedAt: String?) {
        cache[key] = CachedSummary(
            summary: summary,
            riskLevel: riskLevel,
            riskReason: riskReason,
            updatedAt: updatedAt ?? ""
        )
        save()
    }

    private func save() {
        let url = Self.fileURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(cache).write(to: url, options: .atomic)
        } catch {}
    }

    private static func load() -> [String: CachedSummary] {
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode([String: CachedSummary].self, from: data)
        else { return [:] }
        return cache
    }
}
