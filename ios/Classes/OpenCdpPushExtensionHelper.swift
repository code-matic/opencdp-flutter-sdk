import Foundation
import UserNotifications

public class OpenCdpPushExtensionHelper {

    public static func didReceiveNotificationExtensionRequest(_ request: UNNotificationRequest, appGroup: String) {
        log("Push notification received in extension")
        let userInfo = request.content.userInfo

        // 1. Extract your unique delivery ID from the push payload.
        if let deliveryMessageId = userInfo["delivery_message_id"] as? String,
           let deliverySendContext = userInfo["delivery_send_context"] as? String {
            
            // 2. Read the API Key from the shared storage
            if let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) {
                // Get user ID if available
                let userId = readUserIdFromSharedStorage(appGroup: appGroup)
                
                // Use the person_id from the payload if available, or fall back to stored user ID
                let personId = userInfo["person_id"] as? String ?? userId
                
                // If we have a personId (either from payload or storage), proceed
                if let personId = personId {
                    // Optional send context ID from the payload
                    let deliverySendContextId = userInfo["delivery_send_context_id"] as? String ?? ""
                    
                    // 3. Make the API call to report the "delivered" event.
                    reportPushStatus(
                        deliveryMessageId: deliveryMessageId,
                        personId: personId,
                        deliverySendContext: deliverySendContext,
                        deliverySendContextId: deliverySendContextId,
                        status: "delivered",
                        apiKey: apiKey
                    )
                } else {
                    log("Could not find person_id in payload or shared storage.")
                }
            } else {
                log("API Key not found in shared storage.")
            }
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
        apiKey: String
    ) {
        guard let url = URL(string: "https://api.opencdp.io/gateway/data-gateway/v1/message/delivery/push") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        // Get current timestamp in ISO8601 format with UTC timezone
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = dateFormatter.string(from: Date())
        
        let body: [String: Any] = [
            "delivery_message_id": deliveryMessageId,
            "person_id": personId,
            "delivery_send_context": deliverySendContext,
            "delivery_send_context_id": deliverySendContextId,
            "status": status,
            "ts": timestamp
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    log("Failed to report push status: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        log("Push \(status) event reported successfully")
                    } else {
                        log("Failed to report push status. Status code: \(httpResponse.statusCode)")
                    }
                }
            }
            task.resume()
        } else {
            log("Failed to serialize request body to JSON")
        }
    }

    /// Debug Logger - Only logs in DEBUG mode
    private static func log(_ message: String) {
        #if DEBUG
        debugPrint("[OpenCDP SDK - Push Extension] \(message)")
        #else
        // In release mode, only log error messages
        if message.contains("Failed") || message.contains("Invalid") || message.contains("Could not") {
            print("[OpenCDP SDK] \(message)")
        }
        #endif
    }
}
