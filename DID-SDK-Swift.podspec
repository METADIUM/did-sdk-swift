#
# Be sure to run `pod lib lint DID-SDK-Swift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DID-SDK-Swift'
  s.version          = '1.0.1'
  s.summary          = 'DID Create, Delete'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/METADIUM/did-sdk-swift.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jinsik' => 'jshan@coinplug.com' }
  s.source           = { :git => 'https://github.com/METADIUM/did-sdk-swift.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '11.3'

  s.source_files = 'DID-SDK-Swift/Classes/**/*'
  
  # s.resource_bundles = {
  #   'DID-SDK-Swift' => ['DID-SDK-Swift/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'web3iOS', '~> 1.2.0'
  s.dependency 'JOSESwift'
  s.dependency 'VerifiableSwift'
end
