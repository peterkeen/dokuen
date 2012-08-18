require 'capistrano'
require 'fileutils'

class Dokuen::Remote

  attr_reader :user, :server_name, :path

  def initialize(spec)
    @remote_spec = spec

    @server_name, @path = spec.split(/:/, 2)
    @user, rest = @server_name.split(/@/, 2)

    @cap = Capistrano::Configuration.new
    @cap.logger.level = Capistrano::Logger::TRACE
    @cap.server(@server_name, :dokuen)
  end

  def prepare!
    mkdirs
    install_foreman
  end

  def run(*args)
    @cap.run(*args)
  end

  def sudo(*args)
    @cap.sudo(*args)
  end

  def mkdirs
    dirs = [
      'apps',
      'env',
      'nginx',
      'buildpacks',
    ]

    dirs.each do |dir|
      full_path = File.join(path, dir)
      sudo("mkdir -p #{full_path}")
      sudo("chown #{user} #{full_path}")
    end
  end

  def install_foreman
    sudo("apt-get -y install ruby1.9.1")
    sudo("gem install foreman -v 0.55.0")
  end

  def clone_buildpack(url)
    run("cd #{path}/buildpacks && git clone #{url}")
  end

  def remove_buildpack(name)
    run("rm -rf #{path}/buildpacks/#{name}")
  end

  def application_exists?(name)
    @cap.capture("([ -d #{path}/apps/#{name} ] && echo #{name}) || echo '' ") != ""
  end

  def create_user(name)
    sudo("useradd --home #{path}/apps/#{name} --shell /usr/bin/false #{name}")
  end

end
