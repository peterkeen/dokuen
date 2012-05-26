require 'fileutils'

module Dokuen
  class Application

    attr_reader :name, :release

    def initialize(name, release)
      @name = name
      @release = release
    end

    def exists?
      Dokuen.app_exists(name)
    end

    def create!
      if exists?
        raise "App #{name} already exists"
      end
      
      FileUtils.mkdir_p(Dokuen.dir("env", name))
      FileUtils.mkdir_p(Dokuen.dir("release", name))
      FileUtils.mkdir_p(Dokuen.dir("build", name))
      FileUtils.mkdir_p(Dokuen.dir("logs", name))
    end

    def scale!
      processes = running_processes
      running_count_by_name = {}

      processes.each do |proc, pidfile|
        proc_name = proc.split('.')[0]
        count_by_name[proc_name] ||= 0
        count_by_name[proc_name] += 1
      end

      desired_count_by_name = {}
      ENV['DOKUEN_SCALE'].split(',').each do |spec|
        proc_name, count = spec.split('=')
        desired_count_by_name[proc_name] ||= 0
        desired_count_by_name[proc_name] += 1
      end

      to_start = []
      to_stop = []

      desired_count_by_name.each do |proc_name, count|
        running = running_count_by_name[proc_name]
        if running < count
          (count - running).times do |i|
            index = running + i + 1
            to_start << [proc_name, index]
          end
        elsif running > count
          (running - count).times do |i|
            index = count + i + 1
            to_stop << [proc_name, index]
          end
        end
      end

      running_count_by_name.each do |proc_name, count|
        if not desired_count_by_name.has_key?(proc_name)
          count.times do |i|
            to_stop << [proc_name, i]
          end
        end
      end

      to_start.each do |proc_name, index|
        port = Dokuen.reserve_port
        Dokuen.sys("#{Dokuen.bin_dir}/dokuen-wrapper #{name} #{proc_name} #{index} #{port}")
      end

      to_stop.each do |proc_name, index|
        pid_file = processes["#{proc_name}.#{index}"]
        pid = File.read(pid_file).chomp.to_i rescue nil
        if pid
          Process.kill("TERM", pid)
        end
      end
    end

    def shutdown!
      running_processes.each do |proc, pidfile|
        pid = File.read(pid_file).chomp.to_i rescue nil
        if pid
          Process.kill("TERM", pid)
        end
      end
    end

    def running_processes
      procs = {}
      Dir.glob("#{release}/.dokuenprocs/*.pid").map do |pidfile|
        proc_name = File.basename(pidfile).gsub('.pid', '')
        proc_name = proc_name.gsub("dokuen.#{name}.", '')
        procs[proc_name] = pidfile
      end
    end

    def set_env(vars)
      vars.each do |var|
        key, val = var.split(/\=/)
        Dokuen.set_env(name, key, val)
      end
    end

    def delete_env(vars)
      vars.each do |var|
        Dokuen.rm_env(name, var)
      end
    end

    def read_env
      Dokuen.read_env("_common")
      Dokuen.read_env(app)
    end

    def self.current(app)
      Dokuen.read_env("_common")
      Dokuen.read_env(app)      
      self.new(app, ENV['DOKUEN_RELEASE_DIR'])
    end

  end
end
