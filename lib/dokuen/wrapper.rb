require 'foreman'
require 'foreman/procfile'
require 'foreman/process'

class Dokuen::Wrapper

  attr_reader :release_dir, :app, :proc, :index, :port

  def initialize(release_dir, app, proc, index, port)
    @release_dir = release_dir,
    @app = app,
    @proc = proc
    @index = index
    @port = port
  end

  def run!
    return if daemonize! == nil
    load_env
    loop do
      run_loop
    end
  end

  def procname
    "dokuen.#{app.env}.#{proc}.#{index}"
  end

  def procdir
    File.join(release_dir, '.dokuen')
  end

  def pidfile
    File.join(procdir, "#{procname}.pid")
  end

  def outfile
    File.join(procdir, "#{procname}.out")
  end

  def errfile
    File.join(procdir, "#{procname}.err")
  end

  def daemonize!
    pidfile = File.join(release_dir, '.dokuenprocs', "#{procname}.pid")
    raise "Process already running!" if File.exists?(pidfile)

    return unless do_fork.nil?
    write_pidfile
    set_procname
    redirect
  end

  def redirect
    $stdin.reopen("/dev/null")
    $stdout.sync = $stderr.sync = true
    $stdout.reopen(File.new(outfile, "a"))
    $stderr.reopen(File.new(errfile, "a"))
  end

  def write_pidfile
    File.open(pidfile, "w+") do |f|
      f.write(Process.pid)
    end
  end

  def set_procname
    $0 = procname
  end

  def do_fork
    raise 'first fork failed' if (pid = fork) == -1
    return unless pid.nil?
    Process.setsid
    raise 'second fork failed' if (pid = fork) == -1
    exit unless pid.nil?
  end

  def load_env
    app.env.each do |key, val|
      ENV[key] = val
    end
  end

  def run_loop
    reader, writer = (IO.method(:pipe).arity == 0 ? IO.pipe : IO.pipe("BINARY"))
    process = Foreman::Process.new(entry, index.to_i, port.to_i)
    log_file = File.open(Dokuen.dir('logs', procname), 'a')

    Signal.trap("USR2") do
      process.kill("TERM")
    end

    Signal.trap("TERM") do
      process.kill("TERM")
      File.delete(File.join(Dokuen.dir('ports'), port)) rescue nil
      exit! 0
    end

    process.run(writer, release_dir, {})
    thread = Thread.new do
      loop do
        data = reader.gets
        next unless data
        ps, message = data.split(",", 2)
        log_file.puts("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}][#{ps}] #{message}")
        log_file.flush
      end
    end
    Process.wait(process.pid)
    thread.exit
    reader.close
    writer.close
  end

end
