module Dokuen::Actions

  def initialize(*args)
    super(*args)
    @config = Dokuen::Config.new(options[:config] || "~/.dokuen")
  end

  def verify_remote(remote, create_remote=true)
    if @config[:remotes][remote].nil?
      raise Thor::Error.new("#{remote} is not a known remote")
    end
    @remote = Dokuen::Remote.new(@config[:remotes][remote], options[:verbose]) if create_remote
  end

  def verify_application(name)
    raise Thor::Error.new "Application #{name} does not exist" unless @remote.application_exists?(name)
    @app = Dokuen::Application.new(@remote, name)
  end
  
end
