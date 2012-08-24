require 'yaml'

class Dokuen::Permissions

  def self.create(basedir, application)
    perms = self.new(basedir, application)
    perms['owner'] = user
    perms['shared_with'] = []
    perms.write
  end
  
  def initialize(basedir, application)
    @basedir = basedir
    @application = application
    @perms = {}
    if File.exists?(path)
      File.open(path) do |f|
        @perms = YAML.load(f.read)
      end
    end
  end

  def [](key)
    @perms[key]
  end

  def []=(key, val)
    @perms[key] = val
  end

  def path
    File.join(@basedir, 'perms', @application)
  end

  def write
    File.open(path, "w+") do |f|
      f.write(YAML.dump(@perms))
    end
  end

end
