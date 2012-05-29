require 'tmpdir'
require 'fileutils'
require 'time'

class Dokuen::Application

  attr_reader :name, :config

  def initialize(name, config)
    @name = name
    @config = config
  end

  def get_env(var)
    with_app_dir do
      env_path = File.join("env", var)
      if File.exists?(env_path)
        return File.read(env_path)
      else
        return nil
      end
    end
  end

  def set_env(var, val)
    with_app_dir do
      env_path = File.join("env", var)
      File.open(env_path, "w+") do |f|
        f.write(val)
      end
    end
  end

  def delete_env(var)
    with_app_dir do
      File.delete(File.join("env", var)) rescue nil
    end
  end

  def env
    vars = read_env_dir("#{config.dokuen_dir}/env")
    with_app_dir do
      vars.merge!(read_env_dir('env'))
      with_current_release do
        File.open(".env") do |f|
          f.lines.each do |line|
            key, val = line.split('=', 2)
            vars[key] = val
          end
        end
      end
    end
    vars
  end

  def create
    Dir.chdir(File.join(config.dokuen_dir, 'apps')) do
      if File.exists?(name)
        raise "Application #{name} exists!"
      end

      FileUtils.mkdir_p(name)
      with_app_dir do
        dirs = [
          'releases',
          'env',
          'logs',
          'build'
        ]
        FileUtils.mkdir_p(dirs)
      end
    end
  end

  def deploy(revision)
    git_dir = Dir.getwd

    with_app_dir do
      now = Time.now().utc().strftime("%Y%m%dT%H%M%S")
      release_dir = "releases/#{now}"
      clone_dir = clone(git_dir, revision)

      buildpack = get_env('BUILDPACK_URL')
      if buildpack
        buildpack = "-b #{buildpack}"
      else
        buildpack = ''
      end

      sys("mason build #{clone_dir} #{buildpack} -o #{release_dir} -c build")

      hook = get_env('DOKUEN_AFTER_BUILD')
      if hook
        sys("foreman run #{hook}")
      end

      if File.symlink?("previous")
        File.unlink("previous")
        File.symlink(File.readlink("current"), "previous")
      end

      if File.symlink?("current")
        File.unlink("current")
      end

      File.symlink(File.expand_path(release_dir), "current")
    end

    @ports = scale
    install_nginx_config
    if File.symlink?("previous")
      shutdown(File.readlink("previous"))
    end
  end

  def scale
    with_current_release do
      processes = running_processes
      running_count_by_name = {}
  
      processes.each do |proc, pidfile|
        proc_name = proc.split('.')[0]
        running_count_by_name[proc_name] ||= 0
        running_count_by_name[proc_name] += 1
      end
  
      desired_count_by_name = {}
      scale_spec = get_env('DOKUEN_SCALE')
      if scale_spec
        scale_spec.split(',').each do |spec|
          proc_name, count = spec.split('=')
          desired_count_by_name[proc_name] = count.to_i
        end
      end
  
      to_start = []
      to_stop = []
  
      desired_count_by_name.each do |proc_name, count|
        running = running_count_by_name[proc_name] || 0
        if running < count
          (count - running).times do |i|
            index = running + i + 1
            to_start << [proc_name, index]
          end
        elsif running > count
          (running - count).times do |i|
            index = count + i + 1
            to_stop << [proc_name, index]
          end
        end
      end
  
      running_count_by_name.each do |proc_name, count|
        if not desired_count_by_name.has_key?(proc_name)
          count.times do |i|
            to_stop << [proc_name, i]
          end
        end
      end
  
      ports = []
  
      to_start.each do |proc_name, index|
        port = Dokuen.reserve_port
        if proc_name == 'web'
          ports << port
        end
        Dokuen::Wrapper.new(Dir.getwd, self, proc_name, index, port).run!
      end
  
      to_stop.each do |proc_name, index|
        pid_file = processes["#{proc_name}.#{index}"]
        pid = File.read(pid_file).chomp.to_i rescue nil
        if pid
          Process.kill("TERM", pid)
        end
      end
      ports
    end
  end

  def shutdown(release)
    with_release_dir(release) do
      running_processes.each do |proc, pidfile|
        pid = File.read(pidfile).to_i rescue nil
        if pid
          Process.kill("TERM", pid)
        end
      end
    end
  end

  def install_nginx_config
    @ssl_on = get_env('USE_SSL') ? 'on' : 'off'
    @listen_port = get_env('USE_SSL') ? 443 : 80
    conf = Dokuen.template('nginx', binding)
    File.open(File.join(config.dokuen_dir, "nginx", "#{name}.#{config.base_domain_name}.conf"), "w+") do |f|
      f.write(conf)
    end

    sys("sudo #{config.bin_path}/dokuen_restart_nginx")
  end

private

  def clone(git_dir, revision)
    dir = Dir.mktmpdir
    Dir.chdir(dir) do 
      sys("git clone #{git_dir} .")
      sys("git checkout -q #{revision}")
    end
    dir
  end

  def sys(command)
    system(command) or raise "Error running command: #{command}"
  end

  def with_app_dir
    Dir.chdir(File.join(config.dokuen_dir, 'apps', name)) do
      yield
    end
  end

  def with_release_dir(release)
    Dir.chdir(release) do
      yield
    end
  end

  def with_current_release
    with_app_dir do
      if File.symlink?("current")
        with_release_dir(File.readlink("current")) do
          yield
        end
      end
    end
  end

  def running_processes
    procs = {}
    Dir.glob(".dokuenprocs/*.pid").map do |pidfile|
      proc_name = File.basename(pidfile).gsub('.pid', '')
      proc_name = proc_name.gsub("dokuen.#{name}.", '')
      procs[proc_name] = pidfile
    end
    procs
  end

  def read_env_dir(dir)
    vars = {}
    Dir.glob("#{dir}/*").each do |key|
      vars[File.basename(key)] = File.read(key)
    end
    vars
  end

end
