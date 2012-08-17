require 'capistrano'

class Dokuen::Remote
  def initialize(spec)
    @remote_spec = spec

    @server_name, @path = spec.split(/:/, 2)
    
    @cap = Capistrano::Configuration.new
    @cap.logger.level = Capistrano::Logger::TRACE
    @cap.server(@server_name, :dokuen)
  end

  def setup!
    @cap.run("hostname")
  end
end
