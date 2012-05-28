require 'erb'

module Dokuen
  class Template

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
