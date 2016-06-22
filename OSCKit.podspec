Pod::Spec.new do |s|
  s.name = 'OSCKit'
  s.version = '0.3.5'
  s.summary = 'OSC protocol implementation.'
  s.homepage = 'https://github.com/256dpi/OSCKit'
  s.license = 'MIT'
  s.author = { "Joël Gähwiler" => "joel.gaehwiler@gmail.com" }
  s.source = { git: 'https://github.com/256dpi/OSCKit.git', tag: s.version }

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.requires_arc = true

  s.source_files = 'OSCKit/**/*.{h,m,mm,cpp}'
  s.public_header_files = 'OSCKit/*.h'
  s.libraries = 'c++', 'stdc++'

  s.dependency 'CocoaAsyncSocket'
  #s.dependency 'CocoaAsyncSocket', :git => 'https://github.com/grivescorbett/CocoaAsyncSocket.git', :commit => '8b70db371d224344d21def74b7919b86c5933d1a'
end

# How to publish
# git tag '0.3.0'
# git push --tags
# pod trunk push OSCKit.podspec
