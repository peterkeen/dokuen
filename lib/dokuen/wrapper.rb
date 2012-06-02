require 'foreman'
require 'foreman/procfile'
require 'foreman/process'

class Dokuen::Wrapper

  attr_reader :release_dir, :app, :proc, :index, :portfile

  def initialize(app, proc, index, portfile)
    @release_dir = Dir.getwd
    @app = app
    @proc = proc
    @index = index
    @portfile = portfile
  end

  def run!
    return if daemonize! == nil
    loop do
      run_loop
    end
  end

  def procname
    "dokuen.#{app.name}.#{proc}.#{index}"
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

  def port
    File.basename(portfile).to_i
  end

  def daemonize!
    pf = File.join(pidfile)
    raise "Process already running!" if File.exists?(pf)

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
      f.write(YAML.dump({'pid' => Process.pid, 'port' => port}))
    end
  end

  def set_procname
    $0 = procname
  end

  def do_fork
    raise 'first fork failed' if (pid = fork) == -1
    exit unless pid.nil?
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
    load_env
    reader, writer = (IO.method(:pipe).arity == 0 ? IO.pipe : IO.pipe("BINARY"))
    procfile = Foreman::Procfile.new("Procfile")
    entry = procfile[proc]
    process = Foreman::Process.new(entry, index.to_i, port.to_i)
    log_path = "../../logs/#{procname}"
    log_file = File.open(log_path, 'a')

    Signal.trap("USR2") do
      process.kill("TERM")
    end

    Signal.trap("TERM") do
      if not process.kill(9)
        raise "Failed to kill process #{process.pid}"
      end
      File.delete(pidfile)
      File.delete("../../../../ports/#{port}")
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
