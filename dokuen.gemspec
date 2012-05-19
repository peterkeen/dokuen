Gem::Specification.new do |s|
  s.name = 'dokuen'
  s.version = '0.0.1'
  s.date = '2012-05-19'

  s.summary = 'A Personal Application Platform for Macs'
  s.description = 'Like Heroku but Personal'

  s.author = 'Pete Keen'
  s.email = 'pete@bugsplat.info'

  s.require_paths = %w< lib >

  s.files = Dir['lib/**/*.rb'] +
    Dir['test/*.rb'] +
    %w< dokuen.gemspec README.md >

  s.test_files = s.files.select {|path| path =~ /^test\/.*.rb/ }

  s.add_development_dependency('rake')
  s.add_dependency('thor')
  

  s.homepage = 'https://github.com/peterkeen/dokuen'
end