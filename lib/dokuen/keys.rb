class Dokuen::Keys
  attr_reader :config

  def initialize(config)
    @config = config
  end
  
  def list
    Dir[File.join(config.dokuen_dir, 'keys', '*.key')].map{|d| File.basename(d, '.key')}
  end
  
  def check_name(name)
    unless name =~ /\A[a-zA-Z0-9\-_@.]+\Z/
      raise "Invalid username: #{name}"
    end
  end
  
  def key_path(name)
    File.join(config.dokuen_dir, 'keys', "#{name}.key")
  end
  
  def create(name, data)
    check_name(name)
    data = data.strip
    File.open(key_path(name), "w") do |f|
      f.write(data)
    end
    write_authorized_keys
  end
  
  def remove(name)
    check_name(name)
    File.delete(key_path)
    write_authorized_keys
  end
  
  def write_authorized_keys
    authorized_keys = File.join(config.app_user_home, '.ssh', 'authorized_keys')
    File.open(authorized_keys, "w") do |f|
      list.each do |name|
        key = File.readlines(key_path(name)).first
        f.puts "command=\"#{config.dokuen_dir}/bin/dokuen-shell #{name}\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding #{key}"
      end
    end
    FileUtils.chmod(0600, authorized_keys)
  end
end