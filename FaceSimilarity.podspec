#
# Be sure to run `pod lib lint iOS_RLJSBridge.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FaceSimilarity'
  s.version          = '1.0.0'
  s.summary          = '检测面部及证件照片，判断是否为同一个人'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
通过调用ArcFace的类库，实时检测人脸和手持的证件照片是否一致，用于做实名判断的一个辅助
                       DESC

  s.homepage         = 'https://github.com/akring/FaceSimilarity'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '吕俊' => 'akring@163.com' }
  s.source           = { :git => 'https://github.com/akring/FaceSimilarity.git', :tag => "#{s.version}" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform              = :ios, '8.0'
  s.ios.deployment_target = '8.0'

  s.ios.source_files = 'ArcFace/ArcFace/**/*'

  s.ios.resource_bundles = {
    'FaceSimilarity' => ['ArcFace/ArcFace/**/*']
  }

  s.ios.public_header_files = 'ArcFace/ArcFace/**/*'
#   s.dependency 'KSCrash', '~> 1.15.8'
#   s.dependency 'UICKeyChainStore', '~> 2.1.1'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end