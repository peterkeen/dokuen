require 'rubygems'
require 'thor'
require 'fileutils'
require 'yaml'

module Dokuen
  class Cli < Thor
    include Thor::Actions

    class_option :application, :alias => '-A', :desc => "Name of the application to manipulate"
    
    desc "setup", "Set up relevant things. Needs to be run as sudo."
    method_option :gituser, :desc => "Username of git user", :default => 'git'
    method_option :gitgroup, :desc => "Group of git user", :default => 'staff'
    method_option :appuser, :desc => "Username of app user", :default => 'dokuen'
    method_option :gitolite, :desc => "Path to gitolite directory", :default => 'GITUSER_HOME/gitolite'
    def setup
      raise "Must be run as root" unless Process.uid == 0

      current_script = File.expand_path($0)
      current_bin_path = File.dirname(current_script)

      dirs = [
        './env',
        './env/_common',
        './log',
        './ports',
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
        'app_user'         => options[:appuser],
        'min_port'         => 5000,
        'max_port'         => 6000
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

Run "sudo visudo" and add the following lines:

User_Alias	APPUSERS = #{options[:app_user]}

git	ALL=(APPUSERS) NOPASSWD: #{File.expand_path('./bin/dokuen-wrapper')}
git ALL=NOPASSWD: #{current_bin_path}/dokuen_restart_nginx

HERE

    end

    desc "boot", "Boot up current applications", :hide => true
    def boot
      portfiles = Dir.glob("#{Dokuen.dir('ports')}/*")
      File.delete(*portfiles)
      Dir.glob("#{Dokuen.dir('env')}/*") do |dir|
        next if File.basename(dir) == "_common"
        app = Dokuen::Application.current(File.basename(dir))
        app.clean!
        app.scale!
      end
    end

    desc "create", "Create a new application."
    def create
      app = options[:application]
      raise "app name required" if app.nil? || app == ""

      Dokuen::Application.new(app).create!

      puts "Created new application named #{app}"
      puts "Git remote: #{Dokuen.base_clone_url}:apps/#{app}.git"
    end

    desc "scale", "Scale an app to the given spec"
    method_option :scale, :desc => "Scale spec", :default => ''
    def scale
      scale_spec = options[:scale]
      app = options[:application]
      raise "scale spec required" if scale_spec.nil?
      application = Dokuen::Application.current(app)
      application.check_exists
      application.set_env(["DOKUEN_SCALE=#{scale_spec}"])
      application.read_env
      application.scale!
      puts "Scaled to #{scale_spec}"
    end

    desc "deploy [REV]", "Deploy an app for a given revision. Run within git pre-receive.", :hide => true
    def deploy(rev="")
      app = options[:application]
      Dokuen::Deploy.new(app, rev).run
      puts "App #{app} deployed"
    end

    desc "run_command", "Run a command in the given app's environment"
    method_option :command, :aliases => '-C', :desc => "Command to run"
    def run_command
      app = options[:application]
      application = Dokuen::Application.current(app)
      application.check_exists

      Dir.chdir(ENV['DOKUEN_RELEASE_DIR']) do
        Dokuen.sys("foreman run #{options[:command]}")
      end
    end

    desc "config [set/delete]", "Add or remove config variables"
    method_option :vars, :aliases => '-V', :desc => "Variables to set or remove", :type => :array
    def config(subcommand="")
      app = options[:application]
      check_app(app)
      application = Dokuen::Application.current(app)
      vars = options[:vars]
      case subcommand
      when "set"
        application.set_env(vars)
        application.restart!
      when "delete"
        application.delete_env(vars)
        application.restart!
      else
        show_vars(app)
      end
    end

    desc "install_buildpack [URL]", "Add a buildpack to the mason config"
    def install_buildpack(url="")
      raise "URL required" unless url != ""
      Dokuen.read_env('_common')
      Dokuen.sys("mason buildpacks:install #{url}")
    end

    desc "remove_buildpack [NAME]", "Remove a buildpack from the mason config"
    def remove_buildpack(name)
      raise "Name required" unless name != ""
      Dokuen.read_env('_common')
      Dokuen.sys("mason buildpacks:uninstall #{name}")
    end

    desc "buildpacks", "List the available buildpacks"
    def buildpacks
      Dokuen.read_env('_common')
      Dokuen.sys("mason buildpacks")
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
        Dokuen::Application.current(app)
        ENV.each do |key, val|
          puts "#{key}=#{val}"
        end
      end

    end
  end
end
