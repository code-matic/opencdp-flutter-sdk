import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// First screen of the test app. Captures everything the SDK needs to talk to
/// a CDP backend and identify the test user, then calls
/// [OpenCDPSDK.initialize] before handing control back to the host.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key, required this.onInitialized});

  /// Called once the SDK is initialized and the user is identified. Receives
  /// the resolved person id used for sync calls.
  final void Function(String personId) onInitialized;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  // Default points at a typical local data-gateway. Change for staging/prod.
  final _endpointController = TextEditingController(
    text:
        "https://cdp-data-gateway-749119130796.europe-west1.run.app/data-gateway",
  );
  final _apiKeyController =
      TextEditingController(text: 'apikey_1758285755732_0ehl3sye');
  final _personIdController =
      TextEditingController(text: 'in-app-message-test-user');
  final _pollSecondsController = TextEditingController(text: '15');

  bool _busy = false;

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _personIdController.dispose();
    _pollSecondsController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final personId = _personIdController.text.trim();
    final pollSeconds = int.tryParse(_pollSecondsController.text.trim()) ?? 15;

    try {
      await OpenCDPSDK.initialize(
        config: OpenCDPConfig(
          cdpApiKey: _apiKeyController.text.trim(),
          cdpEndpoint: _endpointController.text.trim(),
          debug: true,
          autoTrackScreens: false, // we drive the screen manually below
          trackApplicationLifecycleEvents: true,
          autoTrackDeviceAttributes: false,
          enableInAppMessages: true,
          inAppPollInterval: Duration(seconds: pollSeconds),
          inAppSyncLimit: 10,
        ),
      );

      // Identify the test user so backend can scope deliveries by person.
      await OpenCDPSDK.instance.identify(
        identifier: personId,
        properties: const {
          'source': 'in_app_test_app',
          'first_name': 'Yereka',
          'last_name': 'InAppTestUser',
          'email': 'yereka+inapptestuser@codematic.io'
        },
      );

      if (!mounted) return;
      widget.onInitialized(personId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize SDK: $e')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenCDP In-App Test')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'Configure the SDK',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Point this app at any data-gateway and identify a test user. '
                  'In-app messages queued for that user will start arriving '
                  'after the next poll.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: 'CDP endpoint (data-gateway base URL)',
                    helperText: 'e.g. http://localhost:3001/data-gateway',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Required';
                    if (!v.startsWith('http')) return 'Must start with http(s)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'CDP API key',
                  ),
                  obscureText: false,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personIdController,
                  decoration: const InputDecoration(
                    labelText: 'Test person id (will be passed to identify)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pollSecondsController,
                  decoration: const InputDecoration(
                    labelText: 'Poll interval (seconds)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final n = int.tryParse((value ?? '').trim());
                    if (n == null || n < 5) return 'Must be ≥ 5';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _initialize,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Initialize & continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
