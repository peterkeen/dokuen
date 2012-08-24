require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe Dokuen::Shell do

  before do
    @tmpdir = construct_dokuen_dir
  end

  describe "basic permissions" do

    before do
      @shell = Dokuen::Shell.new(@tmpdir, 'command foo.git', 'user')
    end
  
    it "should initialize" do
      @shell.command.should eq "command foo.git"
      @shell.basedir.should eq @tmpdir
      @shell.user.should eq "user"
      @shell.commandv.should eq ['command', 'foo.git']
      @shell.application.should eq 'foo'
    end
  
    it "should check superuser" do
      @shell.is_superuser.should eq false
  
      File.open("#{@tmpdir}/superusers", "w+") do |f|
        f.write('user')
      end
  
      @shell.is_superuser.should eq true
    end
  
    it "should check owner" do
      @shell.is_owner.should eq false
  
      File.open("#{@tmpdir}/perms/foo", "w+") do |f|
        f.write(YAML.dump({'owner' => 'user'}))
      end

      @shell.load_perms
      @shell.is_owner.should eq true
    end
  
    it "should check shared_with" do
      @shell.is_shared_with.should eq false
  
      File.open("#{@tmpdir}/perms/foo", "w+") do |f|
        f.write(YAML.dump({'shared_with' => ['user']}))
      end

      @shell.load_perms
      @shell.is_shared_with.should eq true
    end
  
    it "should check superuser for is_authorized_user" do
      @shell.is_authorized_user.should eq false
  
      File.open("#{@tmpdir}/superusers", "w+") do |f|
        f.write('user')
      end

      @shell.load_perms
      @shell.is_authorized_user.should eq true
    end
  
    it "should check owner for is_authorized_user" do
      @shell.is_authorized_user.should eq false
  
      File.open("#{@tmpdir}/perms/foo", "w+") do |f|
        f.write(YAML.dump({'owner' => 'user'}))
      end

      @shell.load_perms
      @shell.is_authorized_user.should eq true
    end
  
    it "should check shared_with for is_authorized_user" do
      @shell.is_authorized_user.should eq false
  
      File.open("#{@tmpdir}/perms/foo", "w+") do |f|
        f.write(YAML.dump({'shared_with' => ['user']}))
      end

      @shell.load_perms
      @shell.is_authorized_user.should eq true
    end
  end

  describe "check commands" do

    before do
      File.open("#{@tmpdir}/superusers", "w+") do |f|
        f.write("superuser")
      end

      File.open("#{@tmpdir}/perms/foo", "w+") do |f|
        f.write(YAML.dump({'owner' => 'owner', 'shared_with' => ['shared_with']}))
      end
    end

    it "should check permissions" do
      Dokuen::Shell.new(@tmpdir, 'command foo.git', 'superuser').check_permissions.should eq true
      Dokuen::Shell.new(@tmpdir, 'command foo.git', 'owner').check_permissions.should eq true
      Dokuen::Shell.new(@tmpdir, 'command foo.git', 'shared_with').check_permissions.should eq true
      
      lambda { Dokuen::Shell.new(@tmpdir, 'command foo.git', 'notuser').check_permissions }.should raise_error(Dokuen::ExitCode)
    end

    it "should check superuser command for addkey" do
      Dokuen::Shell.new(@tmpdir, 'addkey owner', 'superuser').check_superuser_command.should eq true
      lambda { Dokuen::Shell.new(@tmpdir, 'addkey owner', 'owner').check_superuser_command }.should raise_error(Dokuen::ExitCode)
    end

    it "should check superuser command for removekey" do
      Dokuen::Shell.new(@tmpdir, 'removekey owner', 'superuser').check_superuser_command.should eq true
      lambda { Dokuen::Shell.new(@tmpdir, 'removekey owner', 'owner').check_superuser_command }.should raise_error(Dokuen::ExitCode)
    end

    it "should check owner command for grant" do
      Dokuen::Shell.new(@tmpdir, 'grant shared_with --application=foo', 'superuser').check_owner_command.should eq true
      Dokuen::Shell.new(@tmpdir, 'grant shared_with --application=foo', 'owner').check_owner_command.should eq true

      lambda { Dokuen::Shell.new(@tmpdir, 'grant shared_with --application=foo', 'shared_with').check_owner_command }.should raise_error(Dokuen::ExitCode)
    end

    it "should check owner command for revoke" do
      Dokuen::Shell.new(@tmpdir, 'revoke shared_with --application=foo', 'superuser').check_owner_command.should eq true
      Dokuen::Shell.new(@tmpdir, 'revoke shared_with --application=foo', 'owner').check_owner_command.should eq true

      lambda { Dokuen::Shell.new(@tmpdir, 'revoke shared_with --application=foo', 'shared_with').check_owner_command }.should raise_error(Dokuen::ExitCode)
    end

    it "should actually run a git command" do
      shell = Dokuen::Shell.new(@tmpdir, 'git-receive-pack foo.git', 'owner')
      shell.stub(:run_command)
      shell.should_receive(:run_command).with("git-receive-pack '#{@tmpdir}/repos/foo.git'")
      shell.run()
    end

    it "should actually run a dokuen command" do
      shell = Dokuen::Shell.new(@tmpdir, 'config_set SOMEVAR=someval --application=foo', 'owner')
      shell.stub(:run_command)
      shell.should_receive(:run_command).with("#{@tmpdir}/bin/dokuen config_set SOMEVAR=someval --application=foo")
      shell.run()
    end

  end

end
