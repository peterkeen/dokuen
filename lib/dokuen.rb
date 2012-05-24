require 'dokuen/cli'
require 'dokuen/deploy'
require 'dokuen/config'

module Dokuen
  def self.dir(name, app=nil)
    parts = [File.dirname(File.expand_path($0)), '..', name]

    if not app.nil?
      parts << app
    end
      
    File.join(parts)
  end

  def self.sys(command)
    system(command) or raise "Error running #{command}"
  end

  def self.read_env(name)
    env_dir = Dokuen.dir('env', name)
    Dir.glob("#{env_dir}/*") do |var|
      var_name = File.basename(var)
      ENV[var_name] = File.open(var).read().chomp()
    end
  end

  def self.set_env(name, key, value)
    env_dir = Dokuen.dir('env', name)
    File.open(File.join(env_dir, key), "w+") do |f|
      f.write value
    end
  end

  def self.rm_env(name, key)
    env_dir = Dokuen.dir('env', name)
    File.delete(File.join(env_dir, key))
  end

  def self.base_clone_url
    "#{Dokuen::Config.instance.git_user}@#{Dokuen::Config.instance.git_server}"
  end

  def self.app_exists?(name)
    File.exists?(Dokuen.dir('env', name))
  end
end
