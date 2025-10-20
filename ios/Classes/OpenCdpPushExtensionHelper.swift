import Foundation
import UserNotifications
import os.log // Use the older os.log for backward compatibility

public class OpenCdpPushExtensionHelper {
    
    // 1. Create a static OSLog object for categorization. This is backward compatible.
    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.opencdp.sdk", category: "PushExtension")

    public static func didReceiveNotificationExtensionRequest(
        _ request: UNNotificationRequest,
        appGroup: String,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        log("Push notification received in extension")
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo

        // ✅ Check required payload keys
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
        
        // 📡 Report push status
        reportPushStatus(
            deliveryMessageId: deliveryMessageId,
            personId: personId,
            deliverySendContext: deliverySendContext,
            deliverySendContextId: deliverySendContextId,
            status: "delivered",
            apiKey: apiKey
        ) {
            // ✅ Modify content here if needed
            // bestAttemptContent.title = "New Title"
            completion(bestAttemptContent)
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

    private static func reportPushStatus(
        deliveryMessageId: String,
        personId: String,
        deliverySendContext: String,
        deliverySendContextId: String,
        status: String,
        apiKey: String,
        completion: @escaping () -> Void
    ) {
        guard let url = URL(string: "https://api.opencdp.io/gateway/data-gateway/v1/message/delivery/push") else {
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

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
        
        request.httpBody = jsonData
            
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                // Use os_log directly for errors, marking the description as public.
                os_log("Failed to report push status: %{public}@", log: Self.osLog, type: .error, error.localizedDescription)
            } else if let httpResponse = response as? HTTPURLResponse {
                // For integers, use the %d format specifier. It's not redacted by default.
                os_log("Push status response: %d", log: Self.osLog, type: .info, httpResponse.statusCode)
            }
            completion()
        }
        task.resume()
    }

    // 2. Update the log function to use the older os_log API with public formatting.
    private static func log(_ message: String) {
        os_log("[OpenCDP SDK] %{public}@", log: Self.osLog, type: .info, message)
    }
}

