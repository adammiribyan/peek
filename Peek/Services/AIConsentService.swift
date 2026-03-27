import Foundation
import PostHog

final class AIConsentService {
    static let shared = AIConsentService()
    private init() {}

    var activeProviderKey: String {
        PostHogSDK.shared.isFeatureEnabled("baseten_inference") ? "baseten" : "anthropic"
    }

    var activeProviderName: String {
        activeProviderKey == "baseten" ? "DeepSeek (via Baseten)" : "Anthropic Claude"
    }

    var hasValidConsent: Bool {
        guard UserDefaults.standard.bool(forKey: "aiConsentGiven") else { return false }
        return UserDefaults.standard.string(forKey: "aiConsentProvider") == activeProviderKey
    }

    static let consentGrantedNotification = Notification.Name("AIConsentGranted")

    func recordConsent() {
        UserDefaults.standard.set(true, forKey: "aiConsentGiven")
        UserDefaults.standard.set(activeProviderKey, forKey: "aiConsentProvider")
        NotificationCenter.default.post(name: Self.consentGrantedNotification, object: nil)
    }

    func revokeConsent() {
        UserDefaults.standard.removeObject(forKey: "aiConsentGiven")
        UserDefaults.standard.removeObject(forKey: "aiConsentProvider")
    }
}
