/// Enum representing different types of metric events for push notifications
enum MetricEvent {
  /// Notification was delivered to the device
  delivered,

  /// Notification was opened by the user
  opened,

  /// Notification was converted (user took action)
  converted,

  /// Notification failed to deliver
  failed
}
