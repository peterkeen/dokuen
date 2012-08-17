require "thor"
require "thor/shell/basic"
require "thor/group"

class Dokuen::CLI < Thor

  include Thor::Actions

  class_option :config, :type => :string, :desc => "Config file"

  class Remote < Thor

    namespace :remote

    def initialize(*args)
      super(*args)
      @config = Dokuen::Config.new(options[:config] || "~/.dokuen")
    end

    desc "add NAME SPEC", "Add a remote named NAME with spec SPEC (ex: user@hostname:/path/to/dokuen)"
    def add(name, spec)
      @config[:remotes][name] = spec
      @config.write_file
      say "Added #{name} to #{@config.filename}"
    end

    desc "remove NAME", "Remote the named remote from dokuen config"
    def remove(name)
      if @config[:remotes][name].nil?
        raise Thor::Error.new("#{name} is not a known remote")
      end

      @config[:remotes].delete(name)
      @config.write_file
      say "Removed #{name} from #{@config.filename}"
    end

    desc "setup NAME", "Setup Dokuen on the named remote"
    def setup(name)
      if @config[:remotes][name].nil?
        raise Thor::Error.new("#{name} is not a known remote")
      end

      say "Setting up dokuen on #{name}"

      remote = Dokuen::Remote.new(@config[:remotes][name])
      remote.setup!
    end

    def self.banner(task, namespace = true, subcommand = false)
      "#{basename} #{task.formatted_usage(self, true, subcommand)}"
    end    

  end

  register(Remote, 'remote', 'remote <command>', 'Manipulate Dokuen remotes')

end

