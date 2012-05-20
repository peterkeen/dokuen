require 'rubygems'
require 'thor'
require 'fileutils'

module Dokuen
  class Cli < Thor
    desc "setup", "Set up relevant things. Needs to be run as sudo."
    def setup
      raise "Must be run as root" unless Process.uid == 0
    end

    desc "create [APP]", "Create a new application."
    def create(app="")
      raise "app name required" if app.nil? || app == ""
      read_env(app)
      FileUtils.mkdir_p(Dokuen.dir("env", app))
      FileUtils.mkdir_p(Dokuen.dir("release", app))
      FileUtils.mkdir_p(Dokuen.dir("build", app))
      puts "Created new application named #{app}"
      puts "Git remote: #{Dokuen.base_clone_url}:apps/#{app}.git"
    end

    desc "restart_app [APP]", "Restart an existing app"
    def restart_app(app="")
      check_app(app)
      read_env(app)
      deploy = Dokuen::Deploy.new(app, '', ENV['DOKUEN_RELEASE_DIR'])
      deploy.install_launch_daemon
      deploy.install_nginx_conf
      puts "App restarted"
    end

    desc "start_app [APP]", "Start an app", :hide => true
    def start_app(app="")
      check_app(app)
      read_env(app)
      ENV['PATH'] = "/usr/local/bin:#{ENV['PATH']}"
      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        base_port = ENV['PORT'].to_i - 200
        scale = ENV['DOKUEN_SCALE'].nil? ? "" : "-c #{ENV['DOKUEN_SCALE']}"
        Dokuen.sys("foreman start #{scale} -p #{base_port}")
      end
    end

    desc "scale [APP] [SCALE_SPEC]", "Scale an app to the given spec"
    def scale(app="", scale_spec="")
      check_app(app)
      raise "scale spec required" if scale_spec == ""
      read_env(app)
      Dokuen.set_env(app, 'DOKUEN_SCALE', scale_spec)
      restart_app(app)
      puts "Scaled to #{scale_spec}"
    end

    desc "deploy [APP] [REV]", "Deploy an app for a given revision. Run within git pre-receive.", :hide => true
    def deploy(app="", rev="")
      check_app(app)
      read_env(app)
      Dokuen::Deploy.new(app, rev).run
      puts "App #{app} deployed"
    end

    desc "restart_nginx", "Restart Nginx", :hide => true
    def restart_nginx
      raise "Must be run as root" unless Process.uid == 0
      Dokuen.sys("/usr/local/sbin/nginx -s reload")
    end

    desc "install_launchdaemon [PATH]", "Install a launch daemon", :hide => true
    def install_launchdaemon(path)
      raise "Must be run as root" unless Process.uid == 0
      basename = File.basename(path)
      destpath = "/Library/LaunchDaemons/#{basename}"

      if File.exists?(destpath)
        Dokuen.sys("launchctl unload -wF #{destpath}")
      end

      Dokuen.sys("cp #{path} #{destpath}")
      Dokuen.sys("launchctl load -wF #{destpath}")
    end

    desc "run_command [APP] [COMMAND]", "Run a command in the given app's environment"
    def run_command(app="", command="")
      check_app(app)
      read_env(app)

      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        Dokuen.sys("foreman run #{command}")
      end
    end

    desc "config [APP] [set/delete]", "Add or remove config variables"
    method_option :vars, :aliases => '-V', :desc => "Variables to set or remove", :type => :array
    def config(app="", subcommand="")
      check_app(app)
      case subcommand
      when "set"
        set_vars(app)
        restart_app(app)
      when "delete"
        delete_vars(app)
        restart_app(app)
      else
        show_vars(app)
      end
    end

    no_tasks do

      def set_vars(app)
        vars = options[:vars]
        vars.each do |var|
          key, val = var.split(/\=/)
          Dokuen.set_env(app, key, val)
        end
        puts "Vars set"
      end

      def delete_vars(app)
        vars = options[:vars]

        vars.each do |var|
          Dokuen.rm_env(app, var)
        end
        puts "Vars removed"
      end

      def show_vars(app)
        read_env(app)
        ENV.each do |key, val|
          puts "#{key}=#{val}"
        end
      end

      def read_env(app)
        Dokuen.read_env("_common")
        Dokuen.read_env(app)
      end

      def check_app(app)
        Dokuen.app_exists?(app) or raise "App '#{app}' does not exist!"
      end
    end
  end
end
