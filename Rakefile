$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "dokuen/version"
require 'rake'

def sys(cmd)
  system(cmd) or raise "Error running #{cmd}"
end

task :spec do
  sys "rspec specs/*spec.rb"
end

task :build => :spec do
  sys "gem build dokuen.gemspec"
end
 
task :release => :build do
  sys "git tag -a -m 'tag version #{Dokuen::VERSION}' v#{Dokuen::VERSION}"
  sys "git push origin master --tags"
  sys "git push github master --tags"
  sys "gem push dokuen-#{Dokuen::VERSION}.gem"
end

