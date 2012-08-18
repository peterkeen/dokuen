require "erb"

module Dokuen
  def self.template(name, bind)
    path = File.expand_path("../../data/templates/#{name}.erb", __FILE__)
    if File.exists?(path)
      t = ERB.new(File.read(path))
      t.result(bind)
    else
      raise "Unknown template: #{name}"
    end
  end

end

require "dokuen/config"
require "dokuen/remote"
require "dokuen/application"
require "dokuen/cli"

