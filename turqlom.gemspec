# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'turqlom/version'

Gem::Specification.new do |spec|
  spec.name          = "turqlom"
  spec.version       = Turqlom::VERSION
  spec.authors       = ["Adam Thorsen"]
  spec.email         = ["awt@fastmail.fm"]
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "jekyll"
  spec.add_runtime_dependency "s3_website"
  spec.add_runtime_dependency "jekyll-minibundle"
  spec.add_runtime_dependency "coderay"
  spec.add_runtime_dependency "rake"
  spec.add_runtime_dependency "trollop"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

end
