// In OpenCdpPushExtensionHelper.swift

import Foundation
import UserNotifications

public class OpenCdpPushExtensionHelper {

    public static func didReceiveNotificationExtensionRequest(
        _ request: UNNotificationRequest,
        appGroup: String,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        log("Push notification received in extension")
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo

        guard let deliveryMessageId = userInfo["delivery_message_id"] as? String,
              let deliverySendContext = userInfo["delivery_send_context"] as? String else {
            log("Essential delivery tracking info missing from payload.")
            contentHandler(request.content)
            return
        }
        
        guard let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) else {
            log("API Key not found. Delivering original content.")
            contentHandler(request.content)
            return
        }

        let userId = readUserIdFromSharedStorage(appGroup: appGroup)
        let personIdFromPayload = userInfo["person_id"] as? String
        
        guard let personId = personIdFromPayload ?? userId else {
            log("Could not find person_id. Delivering original content.")
            contentHandler(request.content)
            return
        }
        
        let deliverySendContextId = userInfo["delivery_send_context_id"] as? String ?? ""
        
        reportPushStatus(
            deliveryMessageId: deliveryMessageId,
            personId: personId,
            deliverySendContext: deliverySendContext,
            deliverySendContextId: deliverySendContextId,
            status: "delivered",
            apiKey: apiKey
        ) {
            contentHandler(bestAttemptContent)
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
            "delivery_message_id": deliveryMessageId,
            "person_id": personId,
            "delivery_send_context": deliverySendContext,
            "delivery_send_context_id": deliverySendContextId,
            "status": status,
            "ts": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            log("Failed to serialize request body to JSON")
            completion()
            return
        }
        
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
            completion()
        }
        task.resume()
    }
    
    /// Debug Logger - Only logs in DEBUG mode
    private static func log(_ message: String) {
        #if DEBUG
        debugPrint("[OpenCDP SDK - Push Extension] \(message)")
        #else
        //do nothing in release mode
        #endif
    }
}