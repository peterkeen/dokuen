$:.push File.expand_path("../lib", __FILE__)

require 'dokuen/version'

Gem::Specification.new do |s|
  s.name = 'dokuen'
  s.version = Dokuen::VERSION
  s.date = `date +%Y-%m-%d`

  s.summary = 'A Personal Application Platform for Macs'
  s.description = 'Like Heroku but Personal'

  s.author = 'Pete Keen'
  s.email = 'pete@bugsplat.info'

  s.require_paths = %w< lib >

  s.bindir        = 'bin'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.test_files = s.files.select {|path| path =~ /^test\/.*.rb/ }

  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
  s.add_development_dependency('rspec-mocks')

  s.add_dependency('thor')
  s.add_dependency('mason', ">= 0.1.0")
  s.add_dependency('foreman')

  
  s.homepage = 'https://github.com/peterkeen/dokuen'
end
