/// Enum representing different types of metric events for push notifications
enum MetricEvent {
  /// Notification was delivered to the device
  delivered,

  /// Notification was opened by the user
  opened,

  /// User tapped a notification action button (reports `action_clicked` + optional `action_id`)
  actionClicked,

  /// Notification was converted (user took action)
  converted,

  /// Notification failed to deliver
  failed
}
