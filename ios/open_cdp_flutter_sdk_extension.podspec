Pod::Spec.new do |s|
  s.name             = 'open_cdp_flutter_sdk_extension'
  s.version          = '0.0.1'
  s.summary          = 'Open CDP notification service extension helper.'
  s.description      = <<-DESC
  Pure native helper used from iOS notification service extensions. Contains no Flutter dependency.
  DESC
  s.homepage         = 'http://opencdp.io'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Codematic Technology Services' => 'developers@codematic.io' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '11.0'
  s.swift_version    = '5.0'

  # Expose a nice Swift-style module name so clients can:
  #   import OpenCdpFlutterSdkExtension
  s.module_name      = 'OpenCdpFlutterSdkExtension'

  # Only include the helper used by notification service extensions.
  # NOTE: Do NOT include OpenCdpSdkPlugin.swift here, and do NOT depend on Flutter.
  s.source_files     = 'Classes/OpenCdpPushExtensionHelper.swift'
end


