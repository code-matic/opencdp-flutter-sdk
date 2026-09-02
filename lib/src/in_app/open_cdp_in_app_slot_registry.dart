import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_manager.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

/// Shared state for [OpenCDPInAppInlineSlot] / [OpenCDPInAppInboxSlot].
///
/// Provided by [OpenCDPInAppHost] via [OpenCDPInAppSlotScope].
class OpenCDPInAppSlotRegistry extends ChangeNotifier {
  InAppMessage? _inlineMessage;
  String? _inlineTargetSlotId;
  final List<InAppMessage> _inboxMessages = [];
  final Set<String> _impressedDeliveryIds = {};

  /// Wired by [OpenCDPInAppHost] so slots can track without importing the
  /// public SDK barrel (avoids circular imports).
  Future<void> Function(InAppMessage message)? trackImpression;
  Future<void> Function(InAppMessage message, String actionId)? trackClick;
  Future<void> Function(InAppMessage message, InAppDismissReason reason)?
      trackDismiss;

  InAppMessage? get inlineMessage => _inlineMessage;
  String? get inlineTargetSlotId => _inlineTargetSlotId;
  List<InAppMessage> get inboxMessages => List.unmodifiable(_inboxMessages);

  /// Whether [slotId] should show the current inline message.
  ///
  /// - No message → false
  /// - [inlineTargetSlotId] null → every slot (place one per screen)
  /// - Otherwise → only the slot whose [slotId] matches
  bool matchesInlineSlot(String? slotId) {
    if (_inlineMessage == null) return false;
    if (_inlineTargetSlotId == null || _inlineTargetSlotId!.isEmpty) {
      return true;
    }
    return slotId == _inlineTargetSlotId;
  }

  InAppMessage? inlineForSlot(String? slotId) {
    if (!matchesInlineSlot(slotId)) return null;
    return _inlineMessage;
  }

  void setInline(InAppMessage message, {String? targetSlotId}) {
    _inlineMessage = message;
    _inlineTargetSlotId = targetSlotId;
    notifyListeners();
  }

  void clearInline() {
    if (_inlineMessage == null && _inlineTargetSlotId == null) return;
    _inlineMessage = null;
    _inlineTargetSlotId = null;
    notifyListeners();
  }

  void addInbox(InAppMessage message) {
    if (_inboxMessages.any((m) => m.deliveryId == message.deliveryId)) {
      return;
    }
    _inboxMessages.add(message);
    notifyListeners();
  }

  void removeInbox(String deliveryId) {
    final before = _inboxMessages.length;
    _inboxMessages.removeWhere((m) => m.deliveryId == deliveryId);
    if (_inboxMessages.length != before) notifyListeners();
  }

  void clearInbox() {
    if (_inboxMessages.isEmpty) return;
    _inboxMessages.clear();
    notifyListeners();
  }

  /// Returns true the first time [deliveryId] is marked impressed.
  bool markImpressed(String deliveryId) {
    if (deliveryId.isEmpty) return false;
    return _impressedDeliveryIds.add(deliveryId);
  }
}

/// Makes [OpenCDPInAppSlotRegistry] available to descendant slots.
class OpenCDPInAppSlotScope extends InheritedNotifier<OpenCDPInAppSlotRegistry> {
  const OpenCDPInAppSlotScope({
    super.key,
    required OpenCDPInAppSlotRegistry registry,
    required super.child,
  }) : super(notifier: registry);

  static OpenCDPInAppSlotRegistry? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OpenCDPInAppSlotScope>()
        ?.notifier;
  }

  static OpenCDPInAppSlotRegistry of(BuildContext context) {
    final registry = maybeOf(context);
    assert(
      registry != null,
      'OpenCDPInAppInlineSlot/InboxSlot requires an ancestor OpenCDPInAppHost',
    );
    return registry!;
  }
}
