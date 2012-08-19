require 'capistrano'
require 'fileutils'

class Dokuen::Remote

  attr_reader :user, :server_name, :path

  def initialize(spec, verbose=false)
    @remote_spec = spec
    @verbose = verbose

    @server_name, @path = spec.split(/:/, 2)
    @user, rest = @server_name.split(/@/, 2)

    @cap = Capistrano::Configuration.new
    if @verbose
      @cap.logger.level = Capistrano::Logger::TRACE
    end
    @cap.server(@server_name, :dokuen)
  end

  def prepare!
    mkdirs
    install_foreman
    install_curl
  end

  def run(*args)
    @cap.run(*args)
  end

  def sudo(*args)
    @cap.sudo(*args)
  end

  def stream(command, options={})
    @cap.invoke_command(command, options.merge(:eof => true)) do |ch, stream, out|
      print out if stream == :out
      print "[err :: #{ch[:server]}] #{out}" if stream == :err
    end
  end

  def capture(*args)
    @cap.capture(*args)
  end

  def trace(*args)
    @cap.logger.trace(*args) if @verbose
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
    sudo("apt-get -y install ruby1.9.1 ruby1.9.1-dev")
    sudo("gem install foreman -v 0.55.0")
  end

  def install_curl
    sudo("apt-get -y install curl")
  end

  def clone_buildpack(url)
    run("cd #{path}/buildpacks && git clone #{url}")
  end

  def remove_buildpack(name)
    run("rm -rf #{path}/buildpacks/#{name}")
  end

  def detect_buildpack(release)
    count = capture("ls #{path}/buildpacks | wc -l").to_i
    raise Thor::Error.new("No buildpacks defined. Add some using `dokuen buildpack add`.") if count == 0
    output = capture("for b in `ls #{path}/buildpacks`; do #{path}/buildpacks/$b/bin/detect #{release} && echo $b && exit 0; done; echo").strip.split("\n")
    output.select { |l| l != "no" }
  end

  def application_exists?(name)
    capture("([ -d #{path}/apps/#{name} ] && echo #{name}) || echo '' ").strip != ""
  end

  def create_user(name)
    sudo("useradd --home #{path}/apps/#{name} #{name}")
  end

  def put_as(data, path, user, perms="0644")
    tmp = capture("mktemp").strip
    @cap.put(data, tmp)
    sudo("install -o #{user} -g #{user} -m #{perms} #{tmp} #{path}")
  end

  def get(path)
    val = capture("test -f #{path} && cat #{path}; echo")
    val.strip == '' ? nil : val
  end

  def log(msg)
    puts "-----> #{msg}"
  end

  def indent(msg)
    puts "       #{msg}"
  end

  def start_service(name)
    sudo("/usr/sbin/service #{name} restart || /usr/sbin/service #{name} start")
  end

  def foreman_export(release_path, concurrency, name, port)
    stream("bash -c 'cd #{release_path} && foreman export -p #{port} -c #{concurrency} -a #{name} -l #{path}/apps/#{name}/logs upstart /etc/init'", :via => :sudo)
  end

end
