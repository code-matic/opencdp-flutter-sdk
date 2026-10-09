Pod::Spec.new do |s|
  s.name             = 'open_cdp_flutter_sdk'
  s.version          = '0.0.2'
  s.summary          = 'Native iOS components for Open CDP SDK.'
  s.description      = <<-DESC
  This pod provides the native helper functions for push notification tracking in Open CDP SDK.
                     DESC
  s.homepage         = 'http://opencdp.io'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Codematic Technology Services' => 'developers@codematic.io' }
  s.source           = { :path => '.' }

  # Sources live in the Swift Package Manager layout so CocoaPods and SwiftPM build the same files.
  # The push extension helper stays in this pod for apps that still import it via open_cdp_flutter_sdk.
  s.source_files = 'open_cdp_flutter_sdk/Sources/**/*.swift'
  s.resource_bundles = {'open_cdp_flutter_sdk_privacy' => ['open_cdp_flutter_sdk/Sources/open_cdp_flutter_sdk/PrivacyInfo.xcprivacy']}

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # NOTE: The explicit 'module_name' has been removed. 
  # This allows CocoaPods to correctly infer the name from 's.name', avoiding casing conflicts.

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
