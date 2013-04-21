class Dokuen::Shell
  attr_reader :config, :args
  
  def initialize
    @key_id = ARGV.shift
    @origin_cmd = ENV['SSH_ORIGINAL_COMMAND']
    @config = Dokuen::Config.new(ENV['DOKUEN_CONF'])
  end
  
  def exec
    if @origin_cmd
      parse_cmd

      ENV['DOKUEN_ID'] = @key_id
      ENV['DOKUEN_DIR'] = config.dokuen_dir
      if git_cmds.include?(@git_cmd)
        if validate_access
          process_git_cmd
        end
      elsif @git_cmd == 'dokuen'
        process_dokuen_cmd
      else
        $stderr.puts 'Not allowed command'
      end
    else
      $stderr.puts "Welcome to Dokuen, #{@key_id || 'Anonymous'}!"
    end
  end
  protected
  
  def repos_path
    File.join(config.dokuen_dir, 'repos')
  end

  def parse_cmd
    @args = @origin_cmd.split(' ')
    @git_cmd = @args.shift
  end
  
  def app_name
    @app_name ||= begin 
      File.basename(args.first =~ /\A'(.*)'\Z/ ? $1 : args.first, '.git')
    end
  end

  def process_dokuen_cmd
    exec_cmd "bin/dokuen", *args
  end

  def git_cmds
    %w(git-upload-pack git-receive-pack git-upload-archive)
  end

  def process_git_cmd
    repo_full_path = File.join(repos_path, "#{app_name}.git")
    ENV['DOKUEN_REPO'] = repo_full_path
    ENV['DOKUEN_APP'] = app_name
    exec_cmd "#{@git_cmd} #{repo_full_path}"
  end

  def validate_access
    #api.allowed?(@git_cmd, @app_name, @key_id, '_any')
    true
  end

  def exec_cmd(*args)
    Kernel::exec *args
  end
end