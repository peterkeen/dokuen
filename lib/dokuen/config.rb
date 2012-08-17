require 'yaml'

class Dokuen::Config < Hash

  attr_reader :filename

  def initialize(filename=nil)
    recurse_hash = proc { |h,k| h[k] = Hash.new(&recurse_hash) }
    super(&recurse_hash)
    @filename = File.expand_path(filename) if filename
    read
  end

  def read
    return if @filename.nil?
    return unless File.exist?(@filename)
    self.merge!(YAML::load_file(@filename))
    return self
  end

  def write_file
    return if @filename.nil?
    File.open(@filename, "w+") do |f|
      f.write YAML::dump(self)
    end
  end

end
