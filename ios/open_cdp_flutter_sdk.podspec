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

  # Correctly specify source files and explicitly expose public headers
  s.source_files = 'Classes/**/*.{h,m,swift}'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # NOTE: The explicit 'module_name' has been removed. 
  # This allows CocoaPods to correctly infer the name from 's.name', avoiding casing conflicts.

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
