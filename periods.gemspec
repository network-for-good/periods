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
  spec.homepage      = "https://github/networkforgood/periods"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 6.0"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "timecop"

end
