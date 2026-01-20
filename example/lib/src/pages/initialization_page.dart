import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import '../services/log_service.dart';
import 'dashboard_page.dart';

class InitializationPage extends StatefulWidget {
  const InitializationPage({super.key});

  @override
  State<InitializationPage> createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController(text: 'demo-api-key');
  final _endpointController =
      TextEditingController(text: 'https://api.opencdp.com');

  // Config flags
  bool _debug = true;
  bool _autoTrackScreens = true;
  bool _trackLifecycle = true;
  bool _autoTrackDevice = true;

  Future<void> _initialize() async {
    if (!_formKey.currentState!.validate()) return;

    final config = OpenCDPConfig(
      cdpApiKey: _apiKeyController.text,
      cdpEndpoint:
          _endpointController.text.isNotEmpty ? _endpointController.text : null,
      debug: _debug,
      autoTrackScreens: _autoTrackScreens,
      trackApplicationLifecycleEvents: _trackLifecycle,
      autoTrackDeviceAttributes: _autoTrackDevice,
    );

    try {
      LogService.instance.log('Initializing SDK...', type: LogType.info);
      await OpenCDPSDK.initialize(config: config);
      LogService.instance
          .log('SDK Initialized successfully', type: LogType.success);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DashboardPage(),
            settings: const RouteSettings(name: 'DashboardPage'),
          ),
        );
      }
    } catch (e) {
      LogService.instance
          .log('Error initializing SDK: $e', type: LogType.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenCDP Configuration')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Configure SDK',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up your environment to start testing the SDK.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _apiKeyController,
              label: 'API Key',
              icon: Icons.vpn_key,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _endpointController,
              label: 'Endpoint URL (Optional)',
              icon: Icons.link,
            ),
            const SizedBox(height: 24),
            const Text('Features',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildSwitch(
                'Debug Mode', _debug, (v) => setState(() => _debug = v)),
            _buildSwitch('Auto Track Screens', _autoTrackScreens,
                (v) => setState(() => _autoTrackScreens = v)),
            _buildSwitch('Track Lifecycle', _trackLifecycle,
                (v) => setState(() => _trackLifecycle = v)),
            _buildSwitch('Auto Device Attributes', _autoTrackDevice,
                (v) => setState(() => _autoTrackDevice = v)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Initialize SDK & Launch'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
