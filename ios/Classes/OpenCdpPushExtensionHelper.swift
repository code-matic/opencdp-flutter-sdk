import Foundation
import UserNotifications
import os.log

public class OpenCdpPushExtensionHelper {

    private static let deliveryPath = "/v1/message/delivery/push"
    private static let maxRetries = 3
    private static let baseRetryDelayMs: UInt64 = 1000

    private static let defaultGatewayHosts = [
        "https://api.opencdp.io/gateway/data-gateway",
        "https://api.opencdp.com/gateway/data-gateway",
        "https://api.opencdp.xyz/gateway/data-gateway",
    ]

    public static func didReceiveNotificationExtensionRequest(
        _ request: UNNotificationRequest,
        appGroup: String,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        log("Push notification received in extension")
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo

        guard let deliveryMessageId = userInfo["delivery_message_id"] as? String,
              let deliverySendContext = userInfo["delivery_send_context"] as? String else {
            log("Missing delivery tracking info. Returning original content.")
            completion(request.content)
            return
        }

        guard let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) else {
            log("API Key not found. Returning original content.")
            completion(request.content)
            return
        }

        let userId = readUserIdFromSharedStorage(appGroup: appGroup)
        let personIdFromPayload = userInfo["person_id"] as? String

        guard let personId = personIdFromPayload ?? userId else {
            log("Could not find person_id. Returning original content.")
            completion(request.content)
            return
        }

        let deliverySendContextId = userInfo["delivery_send_context_id"] as? String ?? ""

        attachImageIfPresent(userInfo: userInfo, to: bestAttemptContent)

        reportPushStatus(
            deliveryMessageId: deliveryMessageId,
            personId: personId,
            deliverySendContext: deliverySendContext,
            deliverySendContextId: deliverySendContextId,
            status: "delivered",
            apiKey: apiKey,
            appGroup: appGroup
        ) {
            completion(bestAttemptContent)
        }
    }

    static func resolveGatewayHosts(appGroup: String) -> [String] {
        if let stored = readBaseUrlsFromSharedStorage(appGroup: appGroup), !stored.isEmpty {
            return dedupeHosts(stored)
        }
        if let single = readBaseUrlFromSharedStorage(appGroup: appGroup), !single.isEmpty {
            let fallbacks = [
                "https://api.opencdp.com/gateway/data-gateway",
                "https://api.opencdp.xyz/gateway/data-gateway",
            ]
            return dedupeHosts([single] + fallbacks)
        }
        return defaultGatewayHosts
    }

    static func dedupeHosts(_ hosts: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for host in hosts {
            let normalized = normalizeRoot(host)
            if normalized.isEmpty || seen.contains(normalized) { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }
        return ordered
    }

    static func normalizeRoot(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    static func parseImageUrl(from userInfo: [AnyHashable: Any]) -> String? {
        guard let raw = userInfo["image_url"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func attachImageIfPresent(
        userInfo: [AnyHashable: Any],
        to content: UNMutableNotificationContent
    ) {
        guard let imageUrl = parseImageUrl(from: userInfo),
              let url = URL(string: imageUrl) else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let semaphore = DispatchSemaphore(value: 0)
        var attachment: UNNotificationAttachment?

        let task = URLSession.shared.downloadTask(with: request) { location, response, error in
            defer { semaphore.signal() }

            guard let location = location, error == nil else { return }
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return
            }

            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                attachment = try UNNotificationAttachment(
                    identifier: "opencdp_image",
                    url: destination,
                    options: nil
                )
            } catch {
                log("Failed to attach push image: \(error.localizedDescription)")
            }
        }
        task.resume()

        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            task.cancel()
            log("Timed out downloading push image")
            return
        }

        if let attachment = attachment {
            content.attachments = [attachment]
        }
    }

    private static func readApiKeyFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_api_key")
        }
        log("Could not read API Key: Invalid App Group ID provided.")
        return nil
    }

    private static func readUserIdFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_user_id")
        }
        log("Could not read User ID: Invalid App Group ID provided.")
        return nil
    }

    private static func readBaseUrlFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_base_url")
        }
        return nil
    }

    private static func readBaseUrlsFromSharedStorage(appGroup: String) -> [String]? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.stringArray(forKey: "opencdpsdk_base_urls")
        }
        return nil
    }

    private static func reportPushStatus(
        deliveryMessageId: String,
        personId: String,
        deliverySendContext: String,
        deliverySendContextId: String,
        status: String,
        apiKey: String,
        appGroup: String,
        completion: @escaping () -> Void
    ) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = dateFormatter.string(from: Date())

        let body: [String: Any] = [
            "message_id": deliveryMessageId,
            "person_id": personId,
            "send_context": deliverySendContext,
            "send_context_id": deliverySendContextId,
            "status": status,
            "ts": timestamp
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            log("Failed to serialize request body to JSON")
            completion()
            return
        }

        let hosts = resolveGatewayHosts(appGroup: appGroup)
        postWithFailover(
            apiKey: apiKey,
            jsonData: jsonData,
            hosts: hosts,
            retryCount: 0,
            completion: completion
        )
    }

    private static func postWithFailover(
        apiKey: String,
        jsonData: Data,
        hosts: [String],
        retryCount: Int,
        completion: @escaping () -> Void
    ) {
        tryNextHost(
            apiKey: apiKey,
            jsonData: jsonData,
            hosts: hosts,
            hostIndex: 0,
            retryCount: retryCount,
            completion: completion
        )
    }

    private static func tryNextHost(
        apiKey: String,
        jsonData: Data,
        hosts: [String],
        hostIndex: Int,
        retryCount: Int,
        completion: @escaping () -> Void
    ) {
        if hostIndex >= hosts.count {
            if retryCount >= maxRetries {
                log("Push metric failed on all gateway hosts after retries")
                completion()
                return
            }
            let delayMs = baseRetryDelayMs * UInt64(pow(2.0, Double(retryCount))) +
                UInt64.random(in: 0..<baseRetryDelayMs)
            DispatchQueue.global().asyncAfter(
                deadline: .now() + Double(delayMs) / 1000.0
            ) {
                postWithFailover(
                    apiKey: apiKey,
                    jsonData: jsonData,
                    hosts: hosts,
                    retryCount: retryCount + 1,
                    completion: completion
                )
            }
            return
        }

        let root = normalizeRoot(hosts[hostIndex])
        let full = "\(root)\(deliveryPath)"
        guard let url = URL(string: full) else {
            tryNextHost(
                apiKey: apiKey,
                jsonData: jsonData,
                hosts: hosts,
                hostIndex: hostIndex + 1,
                retryCount: retryCount,
                completion: completion
            )
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                log("Push metric failed on \(root): \(error.localizedDescription)")
                tryNextHost(
                    apiKey: apiKey,
                    jsonData: jsonData,
                    hosts: hosts,
                    hostIndex: hostIndex + 1,
                    retryCount: retryCount,
                    completion: completion
                )
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    log("Push metric sent via \(root) (status=\(httpResponse.statusCode))")
                    completion()
                    return
                }
                log("Push metric non-2xx on \(root) (\(httpResponse.statusCode)), trying next host")
            }

            tryNextHost(
                apiKey: apiKey,
                jsonData: jsonData,
                hosts: hosts,
                hostIndex: hostIndex + 1,
                retryCount: retryCount,
                completion: completion
            )
        }
        task.resume()
    }

    private static func log(_ message: String) {
        os_log("[OpenCDP SDK - Push Extension] %@", message)
    }
}
