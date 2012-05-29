module Dokuen
  module Platform

    def self.boot_script(platform)
      case platform
      when 'mac'
        return "/Library/LaunchDaemons/dokuen.plist", "mac_launchdaemon"
      when 'ubuntu'
        return "/etc/init/dokuen", "ubuntu_upstart"
      else
        raise "Unknow platform: #{platform}"
      end
    end
  end
end
      
