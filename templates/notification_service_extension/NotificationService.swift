import UserNotifications
import OpenCdpPushExtension

/// Notification Service Extension for OpenCDP rich push images and delivery tracking.
///
/// Replace `YOUR_APP_GROUP` with the same App Group ID passed to [OpenCDPConfig.iOSAppGroup].
class NotificationService: UNNotificationServiceExtension {

    private let session = OpenCdpNotificationExtensionSession()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let appGroup = "YOUR_APP_GROUP"
        session.didReceive(request, appGroup: appGroup, contentHandler: contentHandler)
    }

    override func serviceExtensionTimeWillExpire() {
        session.serviceExtensionTimeWillExpire()
    }
}
