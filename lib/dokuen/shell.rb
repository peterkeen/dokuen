require 'shellwords'

class Dokuen::ExitCode < StandardError

  attr_reader :code, :message
  
  def initialize(code, message)
    @code = code
    @message = message
  end

end

class Dokuen::Shell

  attr_reader :command, :commandv, :user, :application, :basedir

  def initialize(basedir, command, user)
    @basedir = basedir
    @command = command
    @user = user
    @commandv = Shellwords.split(command)
    @application = determine_appname
  end

  def determine_appname
    if match = command.match(/--application=(\w+)/)
      return match[1]
    elsif match = command.match(/(\w+)\.git/)
      return match[1]
    else
      raise Dokuen::ExitCode.new(1, "Could not determine appname from #{command}")
    end
  end

  def _check_permissions_file(filename, user)
    if File.exists?(filename)
      lines = File.read(filename).split("\n")
      return lines.include?(user)
    end
  end

  def check_permissions
    if _check_permissions_file("#{basedir}/superusers", user)
      return
    end
    if ! _check_permissions_file("#{basedir}/perms/#{application}", user)
      raise Dokuen::ExitCode.new(2, "User #{user} not permitted for app #{application}")
    else
      if commandV[0] != "create"
        raise Dokuen::ExitCode.new(3, "App #{application} does not exist")
      end
    end
  end

  def run_git_command
    repo = "#{basedir}/repos/#{commandV[1]}"
    system("#{commandV[0]} '#{repo}'")
    raise Dokuen::ExitCode.new($?.exitstatus, '')
  end

  def run_dokuen_subcommand
    system("#{basedir}/bin/dokuen #{command}", :in => $stdin, :out => $stdout, :err => $stderr)
    raise Dokuen::ExitCode.new($?.exitstatus, '')
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
end
