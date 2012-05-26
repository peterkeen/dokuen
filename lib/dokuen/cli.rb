require 'rubygems'
require 'thor'
require 'fileutils'
require 'yaml'

module Dokuen
  class Cli < Thor
    include Thor::Actions
    
    desc "setup", "Set up relevant things. Needs to be run as sudo."
    method_option :gituser, :desc => "Username of git user", :default => 'git'
    method_option :gitgroup, :desc => "Group of git user", :default => 'staff'
    method_option :gitolite, :desc => "Path to gitolite directory", :default => 'GITUSER_HOME/gitolite'
    def setup
      raise "Must be run as root" unless Process.uid == 0

      current_script = File.expand_path($0)
      current_bin_path = File.dirname(current_script)

      dirs = [
        './env',
        './env/_common',
        './log',
        './nginx',
        './build',
        './release',
        './bin'
      ]
      dirs.each do |dir|
        empty_directory(dir)
      end
      FileUtils.chown(options[:gituser], options[:gitgroup], dirs)
      githome = File.expand_path("~#{options[:gituser]}")
      gitolite = options[:gitolite].gsub('GITUSER_HOME', githome)
      File.symlink(current_script, File.expand_path("bin/dokuen"))

      create_file("#{gitolite}/src/commands/dokuen", <<HERE)
#!/bin/bash

#{File.expand_path("./bin/dokuen")} $@
HERE

      hook_path = "#{githome}/.gitolite/hooks/common/pre-receive"
      create_file(hook_path, <<'HERE')
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
      File.chmod(0755, hook_path)

      config = {
        'base_domain_name' => 'dokuen',
        'git_server'       => `hostname`.chomp,
        'git_user'         => options[:gituser],
      }

      File.open("./dokuen.conf", 'w+') do |f|
        YAML.dump(config, f)
      end

      say(<<HERE)

==== IMPORTANT INSTRUCTIONS ====

In your .gitolite.rc file, in the COMMANDS section, add the following:

    'dokuen' => 1

In your gitolite.conf file, add the following:

repo apps/[a-zA-Z0-9].*
    C = @all
    RW+ = CREATOR
    config hooks.pre = "#{File.expand_path('./bin/dokuen')} deploy"

In your nginx.conf, add the following to your http section:

include "#{File.expand_path('nginx')}/*.conf";

Run "sudo visudo" and add the following line:

git	ALL=NOPASSWD: #{current_bin_path}/dokuen_install_launchdaemon, #{current_bin_path}/dokuen_restart_nginx

HERE

    end

    desc "create [APP]", "Create a new application."
    def create(app="")
      raise "app name required" if app.nil? || app == ""

      Dokuen::Application.new(app).create!

      puts "Created new application named #{app}"
      puts "Git remote: #{Dokuen.base_clone_url}:apps/#{app}.git"
    end

    desc "scale [APP] [SCALE_SPEC]", "Scale an app to the given spec"
    def scale(app="", scale_spec="")
      check_app(app)
      raise "scale spec required" if scale_spec == ""
      application = Dokuen::Application.current(app)
      application.set_env(["DOKUEN_SCALE=#{scale_spec}"])
      application.scale!
      puts "Scaled to #{scale_spec}"
    end

    desc "deploy [APP] [REV]", "Deploy an app for a given revision. Run within git pre-receive.", :hide => true
    def deploy(app="", rev="")
      check_app(app)
      read_env(app)
      Dokuen::Deploy.new(app, rev).run
      puts "App #{app} deployed"
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
        Dokuen::Application.current(app).set_env(vars)
        puts "Vars set"
      end

      def delete_vars(app)
        vars = options[:vars]
        Dokuen::Application.current(app).delete_env(vars)
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
      
      def check_not_app(app)
        not Dokuen.app_exists?(app) or raise "App '#{app}' does not exist!"
      end

    end
  end
end
