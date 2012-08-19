require "thor"
require "thor/shell/basic"
require "thor/group"

class Dokuen::CLI < Thor

  include Thor::Actions
  include Dokuen::Actions

  class_option :config, :type => :string, :desc => "Config file"
  class_option :verbose, :type => :boolean, :desc => "Verbose logging"

  class SubCommand < Thor

    include Dokuen::Actions

    no_tasks do
      def self.banner(task, namespace = true, subcommand = false)
        "#{basename} #{task.formatted_usage(self, true, subcommand)}"
      end
    end

  end

  class Remote < SubCommand

    namespace :remote

    desc "add NAME SPEC", "Add a remote named NAME with spec SPEC (ex: user@hostname:/path/to/dokuen)"
    def add(name, spec)
      @config[:remotes][name] = spec
      @config.write_file
      say "Added #{name} to #{@config.filename}"
    end

    desc "remove NAME", "Remote the named remote from dokuen config"
    def remove(name)
      verify_remote(name, false)

      @config[:remotes].delete(name)
      @config.write_file
      say "Removed #{name} from #{@config.filename}"
    end

    desc "prepare NAME", "Setup Dokuen on the named remote"
    def prepare(name)
      verify_remote(name)

      say "Preparing #{name} for dokuen"

      @remote.prepare!
    end

  end

  class Buildpack < SubCommand
    namespace :buildpack

    desc "add REMOTE URL", "Add a buildpack to the standard set"
    def add(remote, url)
      verify_remote(remote)

      say "Cloning buildpack from #{url} onto #{remote}"

      @remote.clone_buildpack(url)
    end

    desc "remove REMOTE NAME", "Remove buildpack from remote"
    def remove(remote, name)
      verify_remote(remote)

      say "Removing buildpack #{name} from remote #{remote}"

      @remote.remove_buildpack(name)
    end

  end

  desc "create REMOTE NAME PORT", "Create an application with base port PORT"
  def create(remote, name, port)
    verify_remote(remote)

    say "Creating application #{name} on #{remote}"

    if @remote.application_exists? name
      raise Thor::Error.new "Application #{name} already exists on remote #{remote}"
    end
    app = Dokuen::Application.new(@remote, name)
    app.create!(port)
  end

  desc "destroy REMOTE NAME", "Destroy an application"
  def destroy(remote, name)
    say "Destroying application #{name} on #{remote}"
    verify_remote(remote)
    verify_application(name)

    say "THIS IS PERMANENT"
    say "Type '#{name}' at the prompt below to confirm"

    confirm = ask "Confirm: "
    raise Thor::Error.new("Confirmation invalid!") unless confirm == name

    @app.destroy!

    say "#{name} destroyed"
  end

  desc "push REMOTE NAME", "Push a new release"
  def push(remote, name)
    say "Pushing a new release of #{name} to #{remote}"
    verify_remote(remote)
    verify_application(name)

    release = @app.push!
    say "Created release #{release}"
  end

  desc "scale REMOTE NAME VALUE", "Scale to VALUE concurrency"
  def scale(remote, name, value)
    say "Scaling #{name} on #{remote} to #{value}"
    verify_remote(remote)
    verify_application(name)
    @app.concurrency = value
  end

  register(Remote, 'remote', 'remote <command>', 'Manipulate Dokuen remotes')
  register(Buildpack, 'buildpack', 'buildpack <command>', 'Manipulate Dokuen buildpacks')

end
