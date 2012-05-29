require "yaml"

class Dokuen::Config
  def initialize(path)
    @path = path
    @config = {}
    read_config
  end

  def read_config
    @config = YAML.load(File.read(@path))
  end

  def method_missing(m, *args, &block)
    str_meth = m.to_s
    if @config.has_key? str_meth
      @config[str_meth]
    else
      super
    end
  end
end

