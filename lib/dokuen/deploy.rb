require 'tmpdir'
require 'fileutils'
require 'time'
require 'erb'

module Dokuen
  class Deploy

    def initialize(app, rev, release_dir=nil)
      @app = app || app_name_from_env
      @rev = rev
      ENV['GIT_DIR'] = nil
      ENV['PATH'] = "/usr/local/bin:#{ENV['PATH']}"
      if release_dir
        @release_dir = release_dir
      end
    end

    def run
      read_app_env
      make_dirs
      clone
      build
      install_runner
      install_web_conf
    end

    def read_app_env
      Dokuen.read_env('_common')
      Dokuen.read_env(@app)
    end

    def make_dirs
      FileUtils.mkdir_p([
        env_dir,
        release_dir,
        cache_dir,
        nginx_dir
      ])
    end

    def clone
      Dokuen.sys("git clone #{git_dir} #{clone_dir}")
      Dir.chdir(clone_dir)
      Dokuen.sys("git checkout #{@rev}")
    end

    def build
      Dokuen.sys("mason build #{clone_dir} #{buildpack} -o #{release_dir} -c #{cache_dir}")
      Dokuen.sys("chmod -R a+r #{release_dir}")
      Dokuen.sys("find #{release_dir} -type d -exec chmod a+x {} \\;")
      Dokuen.set_env(@app, 'DOKUEN_RELEASE_DIR', release_dir)

      hook = ENV['DOKUEN_AFTER_BUILD']
      if not hook.nil?
        Dir.chdir release_dir do
          Dokuen.sys("foreman run #{hook}")
        end
      end
    end

    def buildpack
      if not ENV['BUILDPACK_URL'].nil?
        "-b #{ENV['BUILDPACK_URL']}"
      else
        ""
      end
    end

    def install_runner
      t = ERB.new(Dokuen::Template.launch_daemon)
      plist_path = File.join(release_dir, "dokuen.#{@app}.plist")
      File.open(plist_path, "w+") do |f|
        f.write(t.result(binding))
      end
      Dokuen.sys("sudo /usr/local/bin/dokuen_install_launchdaemon #{plist_path}")
    end

    def install_web_conf
      t = ERB.new(Dokuen::Template.nginx)
      File.open(File.join(nginx_dir, "#{@app}.#{base_domain}.conf"), "w+") do |f|
        f.write(t.result(binding))
      end
      Dokuen.sys("sudo /usr/local/bin/dokuen_restart_nginx")
    end

    def base_domain
      Dokuen::Config.instance.base_domain_name
    end

    def app_name_from_env
      File.basename(ENV['GL_REPO']).gsub(/\.git$/, '')
    end

    def env_dir
      Dokuen.dir("env", @app)
    end

    def clone_dir
      @clone_dir ||= Dir.mktmpdir
    end

    def git_dir
      @git_dir || Dir.getwd
    end

    def release_dir
      @now = Time.now().utc().strftime("%Y%m%dT%H%M%S")
      @release_dir ||= File.join(Dokuen.dir('release', @app), @now)
    end

    def cache_dir
      Dokuen.dir('build', @app)
    end

    def nginx_dir
      Dokuen.dir('nginx')
    end

    def server_port
      ENV['USE_SSL'] ? "443" : "80"
    end
    
    def ssl_on
      ENV['USE_SSL'] ? "on" : "off"
    end

  end
end

