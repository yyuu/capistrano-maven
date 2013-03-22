# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-maven/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Yamashita Yuu"]
  gem.email         = ["yamashita@geishatokyo.com"]
  gem.description   = %q{a capistrano recipe to deploy Apache Maven based projects.}
  gem.summary       = %q{a capistrano recipe to deploy Apache Maven based projects.}
  gem.homepage      = "https://github.com/yyuu/capistrano-maven"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-maven"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::Maven::VERSION

  gem.add_dependency("capistrano")
  gem.add_dependency("capistrano-file-resources", "~> 0.1.0")
  gem.add_dependency("capistrano-file-transfer-ext", "~> 0.1.0")
  gem.add_development_dependency("capistrano-jdk-installer", "~> 0.1.0")
  gem.add_development_dependency("net-scp", "~> 1.0.4")
  gem.add_development_dependency("net-ssh", "~> 2.2.2")
  gem.add_development_dependency("vagrant", "~> 1.0.6")
end
