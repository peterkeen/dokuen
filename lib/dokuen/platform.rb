module Dokuen
  module Platform
    def self.detect
      if File.executable?('/usr/bin/lsb_release')
        cmd = '/usr/bin/lsb_release -i -s'
      elsif File.executable?('/usr/bin/uname')
        cmd = '/usr/bin/uname -s'
      else
        return :mac
      end
      case `#{cmd}`.strip
      when 'Darwin'
        return :mac
      when 'Ubuntu'
        return :ubuntu
      else
        return :mac
      end
    end

    def self.boot_script(platform)
      case platform.to_sym
      when :mac
        return "/Library/LaunchDaemons/dokuen.plist", "mac_launchdaemon"
      when :ubuntu
        return "/etc/init/dokuen", "ubuntu_upstart"
      else
        raise "Unknow platform: #{platform}"
      end
    end
  end
end
      
