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

        // 1. Extract your unique delivery ID from the push payload.
        guard let deliveryMessageId = userInfo["delivery_message_id"] as? String,
              let deliverySendContext = userInfo["delivery_send_context"] as? String else {
            // If essential info is missing, deliver original content immediately
            log("Essential delivery tracking info missing from payload.")
            contentHandler(request.content)
            return
        }
        
        // 2. Read the API Key from the shared storage
        guard let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) else {
            log("API Key not found. Delivering original content.")
            contentHandler(request.content)
            return
        }

        let userId = readUserIdFromSharedStorage(appGroup: appGroup)
        let personIdFromPayload = userInfo["person_id"] as? String
        
        // If we have a personId (either from payload or storage), proceed
        guard let personId = personIdFromPayload ?? userId else {
            log("Could not find person_id. Delivering original content.")
            contentHandler(request.content)
            return
        }
        
        // Optional send context ID
        let deliverySendContextId = userInfo["delivery_send_context_id"] as? String ?? ""
        
        // 3. Make the API call and pass the contentHandler to it
        reportPushStatus(
            deliveryMessageId: deliveryMessageId,
            personId: personId,
            deliverySendContext: deliverySendContext,
            deliverySendContextId: deliverySendContextId,
            status: "delivered",
            apiKey: apiKey
        ) {
            // This completion block is now called after the network request.
            // Now it's safe to deliver the notification.
            contentHandler(bestAttemptContent)
        }
    }

    // ... (readApiKeyFromSharedStorage and readUserIdFromSharedStorage remain the same) ...

    private static func reportPushStatus(
        deliveryMessageId: String,
        personId: String,
        deliverySendContext: String,
        deliverySendContextId: String,
        status: String,
        apiKey: String,
        completion: @escaping () -> Void // <-- Add a completion handler
    ) {
        guard let url = URL(string: "https://api.opencdp.io/gateway/data-gateway/v1/message/delivery/push") else {
            log("Invalid URL for reporting push status")
            completion() // <-- Call completion on failure
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
            completion() // <-- Call completion on failure
            return
        }
        
        request.httpBody = jsonData
            
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // This block runs when the network call is finished
            if let error = error {
                log("Failed to report push status: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    log("Push \(status) event reported successfully")
                } else {
                    log("Failed to report push status. Status code: \(httpResponse.statusCode)")
                }
            }
            completion() // <-- IMPORTANT: Call completion here, regardless of success or failure
        }
        task.resume()
    }
    
    // ... (log function remains the same) ...
}