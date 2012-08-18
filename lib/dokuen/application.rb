require 'foreman/procfile'
require 'tempfile'

class Dokuen::Application

  attr_reader :name, :remote

  def initialize(remote, name)
    @remote = remote
    @name = name
  end

  def run(*args)
    remote.run(*args)
  end

  def sudo(*args)
    remote.sudo(*args)
  end

  def create!
    return if remote.application_exists?(name)

    remote.create_user(name)
    dirs = [
      'releases',
      'env',
      'logs',
      'build'
    ]
    dirs.each do |dir|
      sudo("mkdir -p #{remote.path}/apps/#{name}/#{dir}")
    end
    sudo("chown -R #{name}.#{name} #{remote.path}/apps/#{name}")
  end

  def destroy!
    return unless remote.application_exists?(name)

    sudo("rm -rf #{remote.path}/apps/#{name}")
    sudo("userdel #{name}")
  end

  def push_code
    puts "Creating release directory"
    now = DateTime.now.new_offset(0).strftime("%Y%m%dT%H%M%S")
    release_path = "#{remote.path}/apps/#{name}/releases/#{now}"
    sudo("mkdir #{release_path}", :as => name)
    puts "Pushing code"
    command = "tar --exclude=.git -c -z -f - . | ssh #{remote.server_name} sudo -u #{name} tar -C #{release_path} -x -z -f -"
    remote.trace(command)
    unless system(command)
      raise Thor::Error.new("Problem running command #{command}")
    end
    return release_path
  end

  def build(app_type, buildpack, release_path)
    remote.stream("#{remote.path}/buildpacks/#{buildpack}/bin/compile #{release_path} #{remote.path}/apps/#{name}/build", :as => name, :via => :sudo)
    release_info = YAML::load(remote.capture("#{remote.path}/buildpacks/#{buildpack}/bin/release #{release_path}"), :as => name, :via => :sudo)
    put_env(release_info, release_path)
    put_procfile(release_info, release_path)
  end

  def put_env(release_info, release_path)
    vars = [].tap { |a|
      release_info['config_vars'].each do |k, v|
        a << "#{k}=#{v}"
      end
    }.join("\n") + "\n"
    remote.put_as(vars, "#{release_path}/.env", name)
  end

  def put_procfile(release_info, release_path)
    proc_path = "#{release_path}/Procfile"
    remote.log("Generating Procfile")
    existing_procfile = remote.get(proc_path)

    proc = Foreman::Procfile.new
    existing_entries = {}

    if existing_procfile.strip != ""
      remote.indent("Existing Procfile found, merging default types in")
    
      f = Tempfile.new('Procfile')
      f.write(existing_procfile)
      f.flush

      proc = Foreman::Procfile.new(f.path)

      f.close
      f.unlink

      proc.entries { |p| existing_entries[p.name] = 1 }
    end

    release_info["default_process_types"].each do |k,v|
      next if existing_entries[k]
      proc[k] = v
    end

    remote.put_as(proc.to_s, proc_path, name)

  end

  def push!
    release_path = push_code
    app_type, buildpack = remote.detect_buildpack(release_path)
    remote.log("Detected #{app_type} app")
    build(app_type, buildpack, release_path)
    release_path
  end

end
