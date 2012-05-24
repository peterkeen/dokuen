require 'yaml'
require 'singleton'

module Dokuen
  class Config
    include Singleton

    def initialize
      fname = determine_config_file_name
      if File.exists?(fname)
        @config = YAML.load_file(fname)
      else
        @config = {}
      end
    end

    def determine_config_file_name
      File.dirname(File.expand_path($0)) + '/../dokuen.conf'
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
end
