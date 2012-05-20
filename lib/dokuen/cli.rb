require 'rubygems'
require 'thor'
require 'fileutils'

module Dokuen
  class Cli < Thor
    include Thor::Actions
    
    desc "setup", "Set up relevant things. Needs to be run as sudo."
    def setup
      raise "Must be run as root" unless Process.uid == 0
      git_username = ask("What is your git username (usually git)?")
      gitolite_src = ask("What is the path to your gitolite clone?")
      say("Installing gitolite command")
      create_file "#{gitolite_src}/src/commands/dokuen", <<HERE
#!/bin/sh
/usr/local/bin/dokuen $@
HERE
      File.chmod(0755, "#{gitolite_src}/src/commands/dokuen")
      say("Installing gitolite hook")
      hook_path = "/Users/#{git_username}/.gitolite/hooks/common/pre-receive"
      create_file(hook_path, <<'HERE'
#!/usr/bin/env ruby
hook = `git config hooks.pre`.chomp

rev = nil

STDIN.each do |line|
  parts = line.split(/\s/)
  next if parts[2] != "refs/heads/master"
  rev = parts[1]
end

if hook != ""
  name = File.basename(ENV['GL_REPO'])
  cmd = "#{hook} #{name} #{rev}"
  system(cmd) or raise "Error running pre-hook: #{cmd} returned #{$?}"
end
HERE
      )
      File.chmod(0755, hook_path)
      say("Creating directories")
      dirs = [
        '/usr/local/var/dokuen/env',
        '/usr/local/var/dokuen/env/_common',
        '/usr/local/var/dokuen/log',
        '/usr/local/var/dokuen/nginx',
        '/usr/local/var/dokuen/build',
        '/usr/local/var/dokuen/releases',
      ]
      FileUtils.mkdir_p(dirs, :mode => 0775)
      FileUtils.chown(git_username, 'staff', dirs)

      if yes?("Do you want to set up DNS?")
        basename = ask("What is your DNS base domain? For example, if have a wildcard CNAME for *.example.com, this would be example.com.")
        create_file("/usr/local/var/dokuen/env/_common/BASE_DOMAIN", basename)
      end
      git_hostname = `hostname`.chomp
      if no?("Is #{git_hostname} the correct hostname for git remotes?")
        git_hostname = ask("What hostname should we use instead?")
      end
      create_file("/usr/local/var/dokuen/env/_common/DOKUEN_GIT_SERVER", git_hostname)
      create_file("/usr/local/var/dokuen/env/_common/DOKUEN_GIT_USER", git_username)

      say(<<HERE

==== IMPORTANT INSTRUCTIONS ====

In your .gitolite.rc file, in the COMMANDS section, add the following:

    'dokuen' => 1

In your gitolite.conf file, add the following:

repo apps/[a-zA-Z0-9].*
    C = @all
    RW+ = CREATOR
    config hooks.pre = "/usr/local/bin/dokuen deploy"

In your nginx.conf, add the following to your http section:

include "/usr/local/var/dokuen/nginx/*.conf";

Run "sudo visudo" and add the following line:

git	ALL=NOPASSWD: /usr/local/bin/dokuen

HERE
          )

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

    desc "run_command [APP]", "Run a command in the given app's environment"
    method_option :command, :aliases => '-C', :desc => "Command to run"
    def run_command(app="")
      check_app(app)
      read_env(app)

      ENV['PATH'] = "/usr/local/bin:#{ENV['PATH']}"
      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        Dokuen.sys("foreman run #{options[:command]}")
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

    desc "install_buildpack [URL]", "Add a buildpack to the mason config"
    def install_buildpack(url="")
      raise "URL required" unless url != ""
      Dokuen.sys("/usr/local/bin/mason buildpacks:install #{url}")
    end

    desc "remove_buildpack [NAME]", "Remove a buildpack from the mason config"
    def remove_buildpack(name)
      raise "Name required" unless name != ""
      Dokuen.sys("/usr/local/bin/mason buildpacks:uninstall #{name}")
    end

    desc "buildpacks", "List the available buildpacks"
    def buildpacks
      Dokuen.sys("/usr/local/bin/mason buildpacks")
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
