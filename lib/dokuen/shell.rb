require 'shellwords'

class Dokuen::ExitCode < StandardError

  attr_reader :code, :message
  
  def initialize(code, message)
    @code = code
    @message = message
  end

end

class Dokuen::Shell

  attr_reader :command, :commandv, :user, :application, :basedir, :perms

  def initialize(basedir, command, user)
    @basedir = basedir
    @command = command
    @user = user
    @commandv = Shellwords.split(command)
    @application = determine_appname
    load_perms
  end

  def determine_appname
    noapp_commands = %w{addkey removekey}
    if match = command.match(/--application=(\w+)/)
      return match[1]
    elsif match = command.match(/(\w+)\.git/)
      return match[1]
    elsif noapp_commands.include?(commandv[0])
      return nil
    else
      raise Dokuen::ExitCode.new(1, "Could not determine appname from #{command}")
    end
  end

  def is_superuser
    filename = "#{basedir}/superusers"
    if File.exists?(filename)
      lines = File.read(filename).split("\n")
      return lines.include?(user)
    end
    return false
  end

  def is_owner
    return user == perms['owner']
  end

  def is_shared_with
    return (perms['shared_with'] || []).include?(user)
  end

  def is_authorized_user
    return is_superuser || is_owner || is_shared_with
  end

  def check_permissions
    if is_authorized_user
      return true
    end
    raise Dokuen::ExitCode.new(2, "User #{user} not permitted for app #{application}")
  end

  def check_superuser_command
    superuser_commands = %w{addkey removekey}
    if superuser_commands.include?(commandv[0]) && ! is_superuser
      raise Dokuen::ExitCode.new(3, "#{commandv[0]} is restricted to superusers")
    end
    return true
  end

  def check_owner_command
    owner_commands = %{grant revoke}
    if owner_commands.include?(commandv[0]) && ! (is_superuser || is_owner)
      raise Dokuen::ExitCode.new(3, "#{commandv[0]} is restricted to owners")
    end
    return true
  end

  def run_command(command)
    system(command, :in => $stdin, :out => $stdout, :err => $stderr)
    raise Dokuen::ExitCode.new($?.exitstatus, '')
  end
    
  def run_git_command
    repo = "#{basedir}/repos/#{commandv[1]}"
    run_command("#{commandv[0]} '#{repo}'")
  end

  def run_dokuen_subcommand
    check_superuser_command
    check_owner_command

    run_command("#{basedir}/bin/dokuen #{command}")
  end

  def run

    if command.nil?
      $stderr.puts "Shell access rejected"
      exit(1)
    end

    check_permissions

    case commandv[0]
    when "git-receive-pack"
      run_git_command
    when "git-upload-pack"
      run_git_command
    else
      run_dokuen_subcommand
    end
  end

  def load_perms
    if @application
      @perms = Dokuen::Permissions.new(@basedir, @application)
    end
  end
end
