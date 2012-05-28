module Dokuen
  module Platform
    class Ubuntu
      def install_boot_script(dokuen_dir)
        File.open("/etc/init/dokuen", "w+") do |f|
          f.write(<<HERE)
start on startup

task 

exec #{dokuen_dir}/dokuen boot

HERE
      end
    end
  end
end
