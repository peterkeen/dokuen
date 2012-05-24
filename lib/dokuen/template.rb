require 'erb'

module Dokuen
  class Template

    def self.launch_daemon
      <<HERE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>KeepAlive</key>
  <true/>
  <key>Label</key>
  <string>dokuen.<%= @app %></string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/dokuen</string>
    <string>start_app</string>
    <string><%= @app %></string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>UserName</key>
  <string><%= ENV['GL_USER'] %></string>
  <key>WorkingDirectory</key>
  <string>/usr/local/var/dokuen</string>
  <key>StandardOutPath</key>
  <string>/usr/local/var/dokuen/log/<%= @app %>.log</string>
  <key>StandardErrorPath</key>
  <string>/usr/local/var/dokuen/log/<%= @app %>.log</string>
</dict>
</plist>
HERE
    end

    def self.nginx
      <<HERE
server {
  server_name <%= @app %>.<%= base_domain %>;
  listen <%= server_port %>;
  ssl <%= ssl_on %>;
  location / {
    proxy_pass http://localhost:<%= ENV['PORT'] %>/;
  }
}
HERE
    end

  end
end
