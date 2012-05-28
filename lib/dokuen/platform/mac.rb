module Dokuen
  module Platform
    class Mac

      def install_boot_script(dokuen_dir)
        File.open("/Library/LaunchDaemons/info.bugpslat.dokuen.plist", "w+") do |f|
          f.write(<<HERE)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>info.bugpslat.dokuen</string>
  <key>ProgramArguments</key>
  <array>
    <string>#{dokuen_dir}/bin/dokuen</string>
    <string>boot</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>#{dokuen_dir}</string>
</dict>
</plist>
HERE
        end
      end
    end
  end
end
