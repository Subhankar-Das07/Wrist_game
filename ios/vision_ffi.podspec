Pod::Spec.new do |s|
  s.name             = 'vision_ffi'
  s.version          = '1.0.0'
  s.summary          = 'Native SIMD pre-processing engine for Pose Arena.'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'SDE' => 'sde@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = '../src/vision_ffi.cpp'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
