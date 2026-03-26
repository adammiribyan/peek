import Foundation

struct UpdateInfo {
    let version: String
    let downloadURL: String
}

final class UpdateService {
    static let shared = UpdateService()
    private init() {}

    /// Check GitHub Releases for a newer version.
    /// Set your repo here once you push to GitHub.
    private let owner = "adammiribyan"
    private let repo = "peek"

    func checkForUpdate() async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String
        else { return nil }

        let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        guard isNewer(latestVersion, than: appVersion) else { return nil }

        // Find the DMG asset URL
        var downloadURL = json["html_url"] as? String ?? ""
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                   let url = asset["browser_download_url"] as? String {
                    downloadURL = url
                    break
                }
            }
        }

        return UpdateInfo(version: latestVersion, downloadURL: downloadURL)
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
