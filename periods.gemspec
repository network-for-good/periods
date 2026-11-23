# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "periods/version"

Gem::Specification.new do |spec|
  spec.name          = "periods"
  spec.version       = Periods::VERSION
  spec.authors       = ["Thomas Hoen"]
  spec.email         = ["tom.hoen@networkforgood.com"]

  spec.summary       = %q{Provides calculations for recurring payments}
  spec.description   = %q{The periods gem provides calculations on the number of and date due for payment installments related to recurring billing and pledges}
  spec.homepage      = "https://github.com/network-for-good/periods"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org: it is published to the network-for-good GitHub Packages
  # registry by .github/workflows/publish-gem.yml.
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/network-for-good"
  # Links published packages to this repo so they inherit its permissions (and the workflow's
  # GITHUB_TOKEN can publish them).
  spec.metadata["github_repo"] = "ssh://github.com/network-for-good/periods"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 7.2"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "timecop"

end
