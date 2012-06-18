$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rspec'
require 'dokuen'
require 'tmpdir'
require 'fileutils'

def construct_dokuen_dir
  tmpdir = Dir.mktmpdir
  dirs = [
    'apps',
    'env',
    'perms',
    'keys',
    'ports',
    'nginx',
    'bin'
  ]

  dirs.each do |dir|
    FileUtils.mkdir_p(File.join(tmpdir, dir))
  end

  tmpdir
end

