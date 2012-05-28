require 'dokuen/platform/mac'

module Dokuen
  class Platform
    def self.install_boot_script(dokuen_dir, platform)
      case platform
      when 'mac'
        Dokuen::Platform::Mac.new.install_boot_script(dokuen_dir)
      else
        raise "Unknown platform: #{platform}"
      end
    end
  end
end
