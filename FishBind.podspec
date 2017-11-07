Pod::Spec.new do |s|
  s.name         = "FishBind"
  s.version      = "0.2.0"
  s.summary      = "FishBind supports a simple way to bind messages between objects."
  s.description =  "Support binding properties, methods, block. Supports one-way binding & bidirectional binding."
  s.homepage     = "https://github.com/welcommand/FishBind"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "WELCommand" => "ios_programming@163.com" }
  s.ios.deployment_target = "7.0"
  s.osx.deployment_target = "10.9"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/welcommand/FishBind.git", :tag => s.version }
  s.source_files  = "FishBind/*"
  s.framework  = "Foundation"
  s.library   = "objc"
end
