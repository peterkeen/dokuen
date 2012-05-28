require 'dokuen/platform/mac'
require 'dokuen/platform/ubuntu'

module Dokuen
  module Platform
    def self.install_boot_script(dokuen_dir, platform)
      case platform
      when 'mac'
        Dokuen::Platform::Mac.new.install_boot_script(dokuen_dir)
      when 'ubuntu'
        Dokuen::Platform::Ubuntu.new.install_boot_script(dokuen_dir)
      else
        raise "Unknown platform: #{platform}"
      end
    end
  end
end
