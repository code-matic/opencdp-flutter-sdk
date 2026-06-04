import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// Lets you fire arbitrary events into CDP from the test app.
///
/// Events flow through `OpenCDPSDK.instance.track(...)` → data-gateway, where
/// they can drive:
///   * Campaigns whose trigger node matches the event name (and conditions).
///   * Transactional sends bound to a specific event.
///   * Segment recomputation that broadcasts target later.
///
/// The screen is intentionally split into three sections:
///   1. Preset buttons for the most common events, pre-loaded with realistic
///      properties so you can fire them with one tap.
///   2. A custom event composer with a key/value property editor (values are
///      type-inferred: bool, number, JSON, otherwise string).
///   3. A live history of what was fired in this session, so it's obvious
///      which events have been emitted while you watch the backend / inbox.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // Most common event names + a sensible default property payload. Tweak
  // these to match whatever campaigns / transactionals you're testing.
  static final List<_EventPreset> _presets = [
    _EventPreset(
      name: 'signup',
      description: 'Account created',
      properties: {
        'plan': 'free',
        'source': 'mobile',
      },
    ),
    _EventPreset(
      name: 'login',
      description: 'User signed in',
      properties: {
        'method': 'email',
      },
    ),
    _EventPreset(
      name: 'view_product',
      description: 'Viewed a product',
      properties: {
        'product_id': 'sku_123',
        'name': 'Wireless headphones',
        'price': 199.99,
        'currency': 'USD',
      },
    ),
    _EventPreset(
      name: 'add_to_cart',
      description: 'Added item to cart',
      properties: {
        'product_id': 'sku_123',
        'quantity': 1,
        'price': 199.99,
        'currency': 'USD',
      },
    ),
    _EventPreset(
      name: 'purchase',
      description: 'Completed an order',
      properties: {
        'order_id': 'ord_${DateTime.now().millisecondsSinceEpoch}',
        'amount': 199.99,
        'currency': 'USD',
        'item_count': 1,
      },
    ),
    _EventPreset(
      name: 'subscription_renewed',
      description: 'Renewed paid plan',
      properties: {
        'plan': 'pro',
        'amount': 29.99,
        'currency': 'USD',
        'period': 'monthly',
      },
    ),
  ];

  final TextEditingController _customNameCtrl = TextEditingController();
  final List<_PropertyRow> _propertyRows = [_PropertyRow()];
  final List<_FiredEvent> _history = [];

  bool _sending = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    for (final row in _propertyRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _fire(String name, Map<String, dynamic> properties) async {
    if (name.trim().isEmpty) {
      _snack('Event name is required');
      return;
    }
    setState(() => _sending = true);
    try {
      await OpenCDPSDK.instance.track(
        eventName: name.trim(),
        properties: properties,
      );
      if (!mounted) return;
      setState(() {
        _history.insert(
          0,
          _FiredEvent(
            name: name.trim(),
            properties: Map<String, dynamic>.from(properties),
            firedAt: DateTime.now(),
          ),
        );
      });
      _snack('Tracked: $name');
    } catch (e) {
      _snack('Failed to track $name: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _firePreset(_EventPreset preset) async {
    // Re-compute time-sensitive defaults (e.g. order_id) on every tap.
    final props = Map<String, dynamic>.from(preset.properties);
    if (props['order_id'] is String &&
        (props['order_id'] as String).startsWith('ord_')) {
      props['order_id'] = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    }
    await _fire(preset.name, props);
  }

  Future<void> _fireCustom() async {
    final props = <String, dynamic>{};
    for (final row in _propertyRows) {
      final key = row.keyCtrl.text.trim();
      if (key.isEmpty) continue;
      props[key] = _coerce(row.valueCtrl.text);
    }
    await _fire(_customNameCtrl.text, props);
  }

  /// Attempts to interpret a raw text value into the most useful Dart type
  /// (bool → num → JSON → string). Keeps the property editor simple.
  static dynamic _coerce(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (v.toLowerCase() == 'true') return true;
    if (v.toLowerCase() == 'false') return false;
    final num? n = num.tryParse(v);
    if (n != null) return n;
    if ((v.startsWith('{') && v.endsWith('}')) ||
        (v.startsWith('[') && v.endsWith(']'))) {
      try {
        return jsonDecode(v);
      } catch (_) {
        // Fall through and treat as string.
      }
    }
    return v;
  }

  void _addPropertyRow() {
    setState(() => _propertyRows.add(_PropertyRow()));
  }

  void _removePropertyRow(int index) {
    setState(() {
      _propertyRows.removeAt(index).dispose();
      if (_propertyRows.isEmpty) _propertyRows.add(_PropertyRow());
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Trigger events', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Use these to drive campaigns, transactionals and segment updates '
          'on the backend.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _PresetGrid(
          presets: _presets,
          disabled: _sending,
          onFire: _firePreset,
        ),
        const SizedBox(height: 24),
        Text('Custom event', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _customNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Event name',
            hintText: 'e.g. abandoned_cart',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
        ),
        const SizedBox(height: 12),
        Text('Properties', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Values are auto-typed: true/false → bool, numbers → number, '
          '{…}/[…] → JSON, otherwise string.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ...List.generate(_propertyRows.length, (i) {
          final row = _propertyRows[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: row.keyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: row.valueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removePropertyRow(i),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addPropertyRow,
            icon: const Icon(Icons.add),
            label: const Text('Add property'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _sending ? null : _fireCustom,
          icon: const Icon(Icons.send),
          label: const Text('Track event'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('History', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: () => setState(_history.clear),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No events tracked yet in this session.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          )
        else
          ..._history.map((e) => _HistoryTile(event: e)),
      ],
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.presets,
    required this.disabled,
    required this.onFire,
  });

  final List<_EventPreset> presets;
  final bool disabled;
  final ValueChanged<_EventPreset> onFire;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: presets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (_, i) {
            final preset = presets[i];
            return OutlinedButton(
              onPressed: disabled ? null : () => onFire(preset),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.centerLeft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    preset.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});

  final _FiredEvent event;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.firedAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = event.firedAt.second.toString().padLeft(2, '0');
    final pretty =
        const JsonEncoder.withIndent('  ').convert(event.properties);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text('$hh:$mm:$ss',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    )),
              ],
            ),
            if (event.properties.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  pretty,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventPreset {
  _EventPreset({
    required this.name,
    required this.description,
    required this.properties,
  });

  final String name;
  final String description;
  final Map<String, dynamic> properties;
}

class _PropertyRow {
  _PropertyRow();

  final TextEditingController keyCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _FiredEvent {
  _FiredEvent({
    required this.name,
    required this.properties,
    required this.firedAt,
  });

  final String name;
  final Map<String, dynamic> properties;
  final DateTime firedAt;
}
