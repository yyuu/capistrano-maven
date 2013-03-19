set :application, "capistrano-maven"
set :repository,  "."
set :deploy_to do
  File.join("/home", user, application)
end
set :deploy_via, :copy
set :scm, :none
set :use_sudo, false
set :user, "vagrant"
set :password, "vagrant"
set :ssh_options, {:user_known_hosts_file => "/dev/null"}

## java ##
require "capistrano-jdk-installer"
set(:java_version_name, "7u15")
set(:java_oracle_username) { ENV["JAVA_ORACLE_USERNAME"] || abort("java_oracle_username was not set") }
set(:java_oracle_password) { ENV["JAVA_ORACLE_PASSWORD"] || abort("java_oracle_password was not set") }
set(:java_tools_path_local) { File.expand_path("tmp/java") }
set(:java_accept_license, true)
set(:java_license_title, "Oracle Binary Code License Agreement for Java SE")
set(:java_setup_remotely, true)
set(:java_setup_locally, true)

## mvn ##
#set(:mvn_path_local, File.expand_path("tmp/mvn"))

role :web, "192.168.33.10"
role :app, "192.168.33.10"
role :db,  "192.168.33.10", :primary => true

$LOAD_PATH.push(File.expand_path("../../lib", File.dirname(__FILE__)))
require "capistrano-maven"

def _invoke_command(cmdline, options={})
  if options[:via] == :run_locally
    run_locally(cmdline)
  else
    invoke_command(cmdline, options)
  end
end

def assert_file_exists(file, options={})
  begin
    _invoke_command("test -f #{file.dump}", options)
  rescue
    logger.debug("assert_file_exists(#{file}) failed.")
    _invoke_command("ls #{File.dirname(file).dump}", options)
    raise
  end
end

def assert_file_not_exists(file, options={})
  begin
    _invoke_command("test \! -f #{file.dump}", options)
  rescue
    logger.debug("assert_file_not_exists(#{file}) failed.")
    _invoke_command("ls #{File.dirname(file).dump}", options)
    raise
  end
end

def assert_command(cmdline, options={})
  begin
    _invoke_command(cmdline, options)
  rescue
    logger.debug("assert_command(#{cmdline}) failed.")
    raise
  end
end

def assert_command_fails(cmdline, options={})
  failed = false
  begin
    _invoke_command(cmdline, options)
  rescue
    logger.debug("assert_command_fails(#{cmdline}) failed.")
    failed = true
  ensure
    abort unless failed
  end
end

def reset_mvn!
  variables.each_key do |key|
    reset!(key) if /^mvn_/ =~ key
  end
end

def uninstall_mvn!
  run("rm -rf #{mvn_path.dump}")
  run_locally("rm -rf #{mvn_path_local.dump}")
end

task(:test_all) {
  find_and_execute_task("test_default")
}

namespace(:test_default) {
  task(:default) {
    methods.grep(/^test_/).each do |m|
      send(m)
    end
  }
  before "test_default", "test_default:setup"
  after "test_default", "test_default:teardown"

  task(:setup) {
    uninstall_mvn!
    set(:mvn_version, "3.0.5")
    set(:mvn_skip_tests, true)
    set(:mvn_compile_locally, true)
#   set(:mvn_update_settings, true)
#   set(:mvn_update_settings_locally, true)
    find_and_execute_task("deploy:setup")
  }

  task(:teardown) {
    reset_mvn!
    uninstall_mvn!
  }

  task(:test_run_mvn) {
    assert_file_exists(mvn_bin)
    assert_command("#{mvn_cmd} --version")
  }

  task(:test_run_mvn_via_run_locally) {
    assert_file_exists(mvn_bin_local, :via => :run_locally)
    assert_command("#{mvn_cmd_local} --version", :via => :run_locally)
  }
}

# vim:set ft=ruby sw=2 ts=2 :
