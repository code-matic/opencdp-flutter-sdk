import Foundation
import UserNotifications
import os.log

public class OpenCdpPushExtensionHelper {

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
                log("Failed to report push status: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                log("Push status response: \(httpResponse.statusCode)")
            }
            completion()
        }
        task.resume()
    }

   private static let logger = Logger(subsystem: "com.aella.pushExtension", category: "OpenCDP")

   private static func log(_ message: String) {
    logger.debug("\(message)")
   }


    
    // private static func log(_ message: String) {
    //     #if DEBUG
    //     debugPrint("[OpenCDP SDK - Push Extension] \(message)")
    //     #endif
    // }





}
