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
      puts "Creating new application named #{app}"
    end

    desc "restart [APP]", "Restart an existing app"
    def restart(app="")
    end

    desc "scale [APP] [SCALE_SPEC]", "Scale an existing app up or down"
    def scale(app="", scale_spec="")
    end

    desc "deploy [APP]", "Force a fresh deploy of an app"
    def deploy(app="")
    end

    desc "restart_nginx", "Restart Nginx"
    def restart_nginx
      raise "Must be run as root" unless Process.uid == 0
    end

    desc "install_launchdaemon [APP] [RELEASE_PATH]", "Install a launch daemon"
    def install_launchdaemon(app="", release_path="")
      raise "Must be run as root" unless Process.uid == 0
    end

    desc "run_command [APP] [COMMAND]", "Run a command in the given app's environment"
    def run_command(app="", command="")
    end
    
  end
end
