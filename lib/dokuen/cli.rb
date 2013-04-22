require "thor"
require "thor/shell/basic"
require "yaml"

class Dokuen::CLI < Thor

  include Thor::Actions

  def initialize(*args)
    super(*args)

    if not options[:config].nil?
      raise Thor::Error, "Config option not allowed over ssh" if ENV['SSH_ORIGINAL_COMMAND']
      @config = Dokuen::Config.new(options[:config])
    elsif !ENV['DOKUEN_CONF'].nil?
      @config = Dokuen::Config.new(ENV['DOKUEN_CONF'])
    end
  end

  class_option :application, :type => :string, :desc => "Application name"
  class_option :config, :type => :string, :desc => "Configuration file"
  class_option :debug, :type => :boolean, :desc => "Show backtraces"

  desc "setup DIR", "set up dokuen in the given directory"
  method_option :appuser, :desc => "Username of app user", :default => 'dokuen'
  method_option :appgroup, :desc => "Group of app user", :default => 'staff'
  method_option :platform, :desc => "Which platform to install. Can be 'mac', 'ubuntu', or 'centos'"
  def setup(dir)
    @current_script = File.expand_path($0)
    @current_bin_path = File.dirname(@current_script)

    Dir.chdir(dir) do
      setup_dirs
      setup_ssh
      setup_bin
      write_config
      install_boot_script
      puts Dokuen.template('instructions', binding)
    end
  end
  
  desc "adduser", "adds a new user"
  def adduser(user, key=STDIN.read)
    Dokuen::Keys.new(@config).create(user, key)
  end

  desc "removeuser", "deletes existing user"
  def removeuser(user)
    Dokuen::Keys.new(@config).remove(user)
  end

  desc "create", "create application"
  def create
    Dokuen::Application.new(options[:application], @config).create
    puts "git remote add dokuen #{@config.app_user}@#{@config.git_server}:#{options[:application]}.git"
  end

  desc "deploy", "deploy application", :hide => true
  method_option :rev, :desc => "Revision to deploy"
  def deploy
    ENV['GIT_DIR'] = nil
    ENV['PATH'] = "#{@config.bin_path}:#{ENV['PATH']}"
    ENV.each do |k,v|
      puts "#{k}=#{v}"
    end
    Dokuen::Application.new(options[:application], @config).deploy(options[:rev])
  end

  desc "scale SCALE_SPEC", "scale to the given spec"
  def scale(spec)
    app = Dokuen::Application.new(options[:application], @config)
    app.set_env('DOKUEN_SCALE', spec)
    app.scale
  end

  desc "config", "show the config for the given app"
  def config
    app = Dokuen::Application.new(options[:application], @config)
    app.env.each do |key, val|
      puts "#{key}=#{val}"
    end
  end

  desc "config_set VARS", "set some config variables"
  def config_set(*vars)
    app = Dokuen::Application.new(options[:application], @config)
    vars.each do |var|
      key, val = var.chomp.split('=', 2)
      app.set_env(key, val)
    end
    app.restart
  end

  desc "restart", "restart all instances of the application"
  def restart
    app = Dokuen::Application.new(options[:application], @config)
    app.restart
  end

  desc "config_delete VARS", "delete some config variables"
  def config_delete(*vars)
    app = Dokuen::Application.new(options[:application], @config)
    vars.each do |var|
      app.delete_env(var)
    end
    app.restart
  end

  desc "boot", "Scale all of the current applications", :hide => true
  def boot
    Dir.glob("#{@config.dokuen_dir}/apps/*") do |appdir|
      next if File.basename(appdir)[0] == '.'
      app = Dokuen::Application.new(File.basename(appdir), @config)
      app.clean
      app.scale
    end
  end

  desc "shutdown", "Shut down all applications", :hide => true
  def shutdown
    Dir.glob("#{@config.dokuen_dir}/apps/*") do |appdir|
      next if File.basename(appdir)[0] == '.'
      app = Dokuen::Application.new(File.basename(appdir), @config)
      app.shutdown
    end
  end

  desc "install_buildpack URL", "Add a buildpack to the mason config"
  def install_buildpack(url)
    system("#{@config.bin_path}/mason buildpacks:install #{url}")
  end

  desc "remove_buildpack NAME", "Remove a buildpack from the mason config"
  def remove_buildpack(name)
    system("#{@config.bin_path}/mason buildpacks:uninstall #{name}")
  end

  desc "buildpacks", "List the available buildpacks"
  def buildpacks
    system("#{@config.bin_path}/mason buildpacks")
  end

  desc "run_command COMMAND", "Run a command in the current release"
  def run_command(*args)
    app = Dokuen::Application.new(options[:application], @config)
    app.run_command(args)
  end

private

  def setup_dirs
    dirs = [
      'apps',
      'env',
      'ports',
      'nginx',
      'bin',
      'keys',
      'repos'
    ]

    dirs.each do |dir|
      empty_directory(File.join(Dir.getwd, dir))
    end

    FileUtils.chown(options[:appuser], options[:appgroup], dirs)
    FileUtils.chmod(0777, ['apps', 'ports', 'nginx'])
  end
  
  def setup_ssh
    ssh_dir = File.expand_path("~#{options[:appuser]}/.ssh")
    empty_directory(ssh_dir)
    FileUtils.chown(options[:appuser], options[:appgroup], ssh_dir)
    FileUtils.chmod(0700, ssh_dir)
  end

  def setup_bin
    @script_path = File.expand_path("bin/dokuen")
    @shell_script_path = File.expand_path("bin/dokuen-shell")
    @deploy_script_path = File.expand_path("bin/dokuen-deploy")
    write_template(@script_path, "bin_command", 0755)
    write_template(@shell_script_path, "shell_command", 0755)
    write_template(@deploy_script_path, "deploy_command", 0755)
  end

  def write_config
    config = {
      'base_domain_name' => 'dokuen',
      'git_server'       => `hostname`.chomp,
      'app_user'         => options[:appuser],
      'min_port'         => 5000,
      'max_port'         => 6000,
      'app_user_home'    => File.expand_path("~#{options[:appuser]}"),
      'bin_path'         => @current_bin_path,
      'dokuen_dir'       => File.expand_path('.')
    }

    File.open("./dokuen.conf", 'w+') do |f|
      YAML.dump(config, f)
    end
    
  end

  def write_template(filename, template, mode=0644)
    t = Dokuen.template(template, binding)
    create_file(filename, t)
    File.chmod(mode, filename)
  end

  def install_boot_script
    platform = options[:platform] || Dokuen::Platform.detect
    filename, template_name = Dokuen::Platform.boot_script(platform)
    write_template(filename, template_name)
  end
end
