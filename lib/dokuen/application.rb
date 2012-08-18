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

end
