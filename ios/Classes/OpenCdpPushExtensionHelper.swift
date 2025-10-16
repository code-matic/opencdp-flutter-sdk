import Foundation
import UserNotifications

public class OpenCdpPushExtensionHelper {

    public static func didReceiveNotificationExtensionRequest(_ request: UNNotificationRequest, appGroup: String) {
        let userInfo = request.content.userInfo

        // 1. Extract your unique delivery ID from the push payload.
        if let deliveryId = userInfo["open_cdp_delivery_id"] as? String {
            // 2. Read the API Key from the shared storage using the provided App Group ID.
            if let apiKey = readApiKeyFromSharedStorage(appGroup: appGroup) {
                // 3. Make the API call to your backend to report the "delivered" event.
                reportPushDelivered(deliveryId: deliveryId, apiKey: apiKey)
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

    private static func reportPushDelivered(deliveryId: String, apiKey: String) {
        guard let url = URL(string: "https://simple-push.onrender.com/api/notifications/metrics") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "event": "delivered",
            "notification_id": deliveryId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to report push delivered: \(error.localizedDescription)")
            } else {
                print("Push delivered event reported successfully.")
            }
        }
        task.resume()
    }
}
