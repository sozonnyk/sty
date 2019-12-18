# coding: utf-8
lib = File.expand_path("../lib/", __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name = 'sty'
  s.version = '0.0.4'
  s.description = "Command line tools"
  s.authors = ["Andrew Sozonnyk"]
  s.email = ''
  s.homepage = 'https://github.com/sozonnyk/sty'
  s.license = 'MIT'
  s.require_paths = %w(lib)
  s.required_ruby_version = ">= 2.0.0"
  s.required_rubygems_version = ">= 1.3.5"
  s.summary = s.description

  s.files = %w(.document sty.gemspec) + Dir["*.md", "bin/*", "lib/**/*.rb", "*.yaml"]
  s.extensions = ['ext/install/Rakefile']

  s.add_development_dependency "bundler", ">= 1.0", "< 3"

  s.add_runtime_dependency 'thor', '~> 0.20'
  s.add_runtime_dependency 'aws-sdk-core', '~> 3'
  s.add_runtime_dependency 'aws-sdk-ec2', '~> 1'
  s.add_runtime_dependency 'aws-sdk-ssm', '~> 1'
  s.add_runtime_dependency 'aws-sdk-iam', '~> 1'

  s.add_runtime_dependency 'ruby-dbus', '~> 0'
  s.add_runtime_dependency 'ruby-keychain', '~> 0'
  s.add_runtime_dependency 'os', '~> 0'
end