require "thor"
require "thor/shell/basic"
require "yaml"

class Dokuen::CLI < Thor

  include Thor::Actions

  def initialize(*args)
    super(*args)

    if not options[:config].nil?
      @config = Dokuen::Config.new(options[:config])
    end
  end

  class_option :application, :type => :string, :desc => "Application name"
  class_option :config, :type => :string, :desc => "Configuration file"
  class_option :debug, :type => :boolean, :desc => "Show backtraces"

  desc "setup DIR", "set up dokuen in the given directory"
  method_option :gituser, :desc => "Username of git user", :default => 'git'
  method_option :gitgroup, :desc => "Group of git user", :default => 'staff'
  method_option :appuser, :desc => "Username of app user", :default => 'dokuen'
  method_option :gitolite, :desc => "Path to gitolite directory", :default => 'GITUSER_HOME/gitolite'
  method_option :platform, :desc => "Which platform to install. Can be 'mac', 'ubuntu', or 'centos'"
  def setup(dir)

    @current_script = File.expand_path($0)
    @current_bin_path = File.dirname(@current_script)

    Dir.chdir(dir) do
      setup_dirs
      setup_bin
      setup_gitolite
      write_config
      install_boot_script
      puts Dokuen.template('instructions', binding)
    end
  end

  desc "create", "create application"
  def create
    Dokuen::Application.new(options[:application], @config).create
    puts "git remote add dokuen #{@config.git_user}@#{@config.git_server}:apps/#{options[:application]}.git"
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
      'bin'
    ]

    dirs.each do |dir|
      empty_directory(File.join(Dir.getwd, dir))
    end

    FileUtils.chown(options[:gituser], options[:gitgroup], dirs)
    FileUtils.chmod(0777, ['apps', 'ports', 'nginx'])
  end

  def setup_bin
    @script_path = File.expand_path("bin/dokuen")
    @deploy_script_path = File.expand_path("bin/dokuen-deploy")
    write_template(@script_path, "bin_command", 0755)
    write_template(@deploy_script_path, "deploy_command", 0755)
  end

  def setup_gitolite
    githome = File.expand_path("~#{options[:gituser]}")
    gitolite = options[:gitolite].gsub('GITUSER_HOME', githome)

    write_template("#{gitolite}/src/commands/dokuen", 'gitolite_command', 0755)
    write_template("#{githome}/.gitolite/hooks/common/pre-receive", 'pre_receive_hook', 0755)
  end

  def write_config
    config = {
      'base_domain_name' => 'dokuen',
      'git_server'       => `hostname`.chomp,
      'git_user'         => options[:gituser],
      'app_user'         => options[:appuser],
      'min_port'         => 5000,
      'max_port'         => 6000,
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
