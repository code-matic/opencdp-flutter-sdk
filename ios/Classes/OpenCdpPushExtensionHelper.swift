import Foundation
import UserNotifications

public class OpenCdpPushExtensionHelper {

    public static func didReceiveNotificationExtensionRequest(_ request: UNNotificationRequest, appGroup: String) {
        let userInfo = request.content.userInfo

        // 1. Extract your unique delivery ID from the push payload.
        if let messageId = userInfo["message_id"] as? String,
           let sendContext = userInfo["send_context"] as? String {
            
            // 2. Read the API Key from the shared storage
            if let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) {
                // Get user ID if available
                let userId = readUserIdFromSharedStorage(appGroup: appGroup)
                
                // Use the person_id from the payload if available, or fall back to stored user ID
                let personId = userInfo["person_id"] as? String ?? userId
                
                // If we have a personId (either from payload or storage), proceed
                if let personId = personId {
                    // Optional send context ID from the payload
                    let sendContextId = userInfo["send_context_id"] as? String ?? ""
                    
                    // 3. Make the API call to report the "delivered" event.
                    reportPushStatus(
                        messageId: messageId, 
                        personId: personId, 
                        sendContext: sendContext,
                        sendContextId: sendContextId,
                        status: "delivered",
                        apiKey: apiKey
                    )
                } else {
                    print("Could not find person_id in payload or shared storage.")
                }
            } else {
                print("API Key not found in shared storage.")
            }
        }
    }

    private static func readApiKeyFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_api_key")
        }
        print("Could not read API Key: Invalid App Group ID provided.")
        return nil
    }
    
    private static func readUserIdFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_user_id")
        }
        print("Could not read User ID: Invalid App Group ID provided.")
        return nil
    }

    private static func reportPushStatus(
        messageId: String,
        personId: String,
        sendContext: String,
        sendContextId: String,
        status: String,
        apiKey: String
    ) {
        guard let url = URL(string: "https://api.opencdp.io/gateway/data-gateway/v1/message/delivery/push") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Get current timestamp in ISO8601 format with UTC timezone
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = dateFormatter.string(from: Date())
        
        let body: [String: Any] = [
            "message_id": messageId,
            "person_id": personId,
            "send_context": sendContext,
            "send_context_id": sendContextId,
            "status": status,
            "ts": timestamp
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to report push status: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("Push \(status) event reported successfully.")
                } else {
                    print("Failed to report push status. Status code: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
    }
}
