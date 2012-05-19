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
      read_env(app)
      filename = "/Library/LaunchDaemons/dokuen.#{app}.plist"
      Dokuen.sys("sudo dokuen restart_path #{filename}")
    end

    desc "restart_path [PATH]", "Restart a path", :hide => true
    def restart_path(path)
      raise "Must be run as root" unless Process.uid == 0
      read_env(app)
      if File.exists? path
        Dokuen.sys("launchctl unload -wF #{path}")
        Dokuen.sys("launchctl load -wF #{path}")
      end
    end

    desc "start_app [APP]", "Start an app", :hide => true
    def start_app(app="")
      read_env(app)
      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        base_port = ENV['PORT'].to_i - 200
        scale = ENV['DOKUEN_SCALE'].nil? ? "" : "-c #{ENV['DOKUEN_SCALE']}"
        Dokuen.sys("foreman start #{scale} -p #{base_port}")
      end
    end

    desc "scale [APP] [SCALE_SPEC]", "Scale an app to the given spec"
    def scale(app="", scale_spec="")
      raise "app required" if app == ""
      raise "scale spec required" if scale_spec == ""
      read_env(app)
      Dokuen.set_env(app, 'DOKUEN_SCALE', scale_spec)
      restart_app(app)
      puts "Scaled to #{scale_spec}"
    end

    desc "deploy [APP] [REV]", "Force a fresh deploy of an app", :hide => true
    def deploy(app="", rev="")
      read_env(app)
      Dokuen::Deploy.new(app, rev).run
    end

    desc "restart_nginx", "Restart Nginx", :hide => true
    def restart_nginx
      raise "Must be run as root" unless Process.uid == 0
      read_env(app)
      Dokuen.sys("/usr/local/sbin/nginx -s reload")
    end

    desc "install_launchdaemon [PATH]", "Install a launch daemon", :hide => true
    def install_launchdaemon(path)
      raise "Must be run as root" unless Process.uid == 0
      read_env(app)
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
      read_env(app)

      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        Dokuen.sys("foreman run #{command}")
      end
    end

    desc "config [APP] [set/delete]", "Add or remove config variables"
    method_option :vars, :aliases => '-V', :desc => "Variables to set or remove", :type => :array
    def config(app="", subcommand="")
      case subcommand
      when "set"
        set_vars(app)
      when "delete"
        delete_vars(app)
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
      end

      def delete_vars(app)
        vars = options[:vars]

        vars.each do |var|
          Dokuen.rm_env(app, var)
        end
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
    end
  end
end
