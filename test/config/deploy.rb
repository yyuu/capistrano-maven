set :application, "capistrano-maven"
set :repository, File.expand_path("../project", File.dirname(__FILE__))
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
set(:mvn_tools_path_local, File.expand_path("tmp/mvn"))
set(:mvn_project_path) { release_path }
set(:mvn_project_path_local, repository)

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
# find_and_execute_task("mvn:setup_default_environment")
end

def uninstall_mvn!
  run("rm -rf #{mvn_path.dump}")
  run("rm -f #{mvn_archive_file.dump}")
  run_locally("rm -rf #{mvn_path_local.dump}")
  run("rm -f #{mvn_settings.map { |x| File.join(mvn_settings_path, x).dump }.join(" ")}") unless mvn_settings.empty?
  run_locally("rm -f #{mvn_settings_local.map { |x| File.join(mvn_settings_path_local, x).dump }.join(" ")}") unless mvn_settings_local.empty?
  run("rm -rf #{mvn_target_path.dump}")
  run_locally("rm -rf #{mvn_target_path_local.dump}")
  reset_mvn!
end

task(:test_all) {
  find_and_execute_task("test_default")
  find_and_execute_task("test_with_remote")
  find_and_execute_task("test_with_local")
}

on(:start) {
  run("rm -rf #{deploy_to.dump}")
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
    set(:mvn_setup_remotely, true)
    set(:mvn_setup_locally, true)
    set(:mvn_update_remotely, true)
    set(:mvn_update_locally, true)
    set(:mvn_template_path, File.join(File.dirname(__FILE__), "templates"))
    set(:mvn_settings, %w(settings.xml))
    find_and_execute_task("mvn:setup_default_environment")
    find_and_execute_task("deploy:setup")
    find_and_execute_task("deploy")
  }

  task(:teardown) {
    uninstall_mvn!
  }

  task(:test_run_mvn) {
    assert_file_exists(mvn_bin)
    assert_file_exists(File.join(mvn_settings_path, "settings.xml"))
    assert_command("#{mvn_cmd} --version")
  }

  task(:test_run_mvn_via_sudo) {
    assert_command("#{mvn_cmd} --version", :via => :sudo)
  }

  task(:test_run_mvn_without_path) {
    assert_command("mvn --version")
  }

  task(:test_run_mvn_via_run_locally) {
    assert_file_exists(mvn_bin_local, :via => :run_locally)
    assert_file_exists(File.join(mvn_settings_path_local, "settings.xml"), :via => :run_locally)
    assert_command("#{mvn_cmd_local} --version", :via => :run_locally)
  }

  task(:test_mvn_exec) {
    mvn.exec("--version")
  }

  task(:test_mvn_exec_locally) {
    mvn.exec_locally("--version")
  }

  task(:test_mvn_artifact) {
    assert_file_exists(File.join(mvn_project_path, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"))
  }

  task(:test_mvn_artifact_locally) {
    assert_file_exists(File.join(mvn_project_path_local, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"), :via => :run_locally)
  }
}

namespace(:test_with_remote) {
  task(:default) {
    methods.grep(/^test_/).each do |m|
      send(m)
    end
  }
  before "test_with_remote", "test_with_remote:setup"
  after "test_with_remote", "test_with_remote:teardown"

  task(:setup) {
    uninstall_mvn!
    set(:mvn_version, "3.0.5")
    set(:mvn_skip_tests, true)
    set(:mvn_setup_remotely, true)
    set(:mvn_setup_locally, false)
    set(:mvn_update_remotely, true)
    set(:mvn_update_locally, false)
    set(:mvn_template_path, File.join(File.dirname(__FILE__), "templates"))
    set(:mvn_settings, %w(settings.xml))
    find_and_execute_task("mvn:setup_default_environment")
    find_and_execute_task("deploy:setup")
    find_and_execute_task("deploy")
  }

  task(:teardown) {
    uninstall_mvn!
  }

  task(:test_run_mvn) {
    assert_file_exists(mvn_bin)
    assert_file_exists(File.join(mvn_settings_path, "settings.xml"))
    assert_command("#{mvn_cmd} --version")
  }

  task(:test_run_mvn_via_sudo) {
    assert_command("#{mvn_cmd} --version", :via => :sudo)
  }

  task(:test_run_mvn_without_path) {
    assert_command("mvn --version")
  }

  task(:test_run_mvn_via_run_locally) {
    assert_file_not_exists(mvn_bin_local, :via => :run_locally)
    assert_file_not_exists(File.join(mvn_settings_path_local, "settings.xml"), :via => :run_locally)
    assert_command_fails("#{mvn_cmd_local} --version", :via => :run_locally)
  }

  task(:test_mvn_exec) {
    mvn.exec("--version")
  }

# task(:test_mvn_exec_locally) {
#   mvn.exec_locally("--version")
# }

  task(:test_mvn_artifact) {
    assert_file_exists(File.join(mvn_project_path, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"))
  }

  task(:test_mvn_artifact_locally) {
    assert_file_not_exists(File.join(mvn_project_path_local, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"), :via => :run_locally)
  }
}

namespace(:test_with_local) {
  task(:default) {
    methods.grep(/^test_/).each do |m|
      send(m)
    end
  }
  before "test_with_local", "test_with_local:setup"
  after "test_with_local", "test_with_local:teardown"

  task(:setup) {
    uninstall_mvn!
    set(:mvn_version, "3.0.5")
    set(:mvn_skip_tests, true)
    set(:mvn_setup_remotely, false)
    set(:mvn_setup_locally, true)
    set(:mvn_update_remotely, false)
    set(:mvn_update_locally, true)
    set(:mvn_template_path, File.join(File.dirname(__FILE__), "templates"))
    set(:mvn_settings, %w(settings.xml))
    find_and_execute_task("mvn:setup_default_environment")
    find_and_execute_task("deploy:setup")
    find_and_execute_task("deploy")
  }

  task(:teardown) {
    uninstall_mvn!
  }

  task(:test_run_mvn) {
    assert_file_not_exists(mvn_bin)
    assert_file_not_exists(File.join(mvn_settings_path, "settings.xml"))
    assert_command_fails("#{mvn_cmd} --version")
  }

  task(:test_run_mvn_via_sudo) {
    assert_command_fails("#{mvn_cmd} --version", :via => :sudo)
  }

  task(:test_run_mvn_without_path) {
    assert_command_fails("mvn --version")
  }

  task(:test_run_mvn_via_run_locally) {
    assert_file_exists(mvn_bin_local, :via => :run_locally)
    assert_file_exists(File.join(mvn_settings_path_local, "settings.xml"), :via => :run_locally)
    assert_command("#{mvn_cmd_local} --version", :via => :run_locally)
  }

# task(:test_mvn_exec) {
#   mvn.exec("--version")
# }

  task(:test_mvn_exec_locally) {
    mvn.exec_locally("--version")
  }

  task(:test_mvn_artifact) {
    assert_file_exists(File.join(mvn_project_path, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"))
  }

  task(:test_mvn_artifact_locally) {
    assert_file_exists(File.join(mvn_project_path_local, "target", "capistrano-maven-0.0.1-SNAPSHOT.jar"), :via => :run_locally)
  }
}

# vim:set ft=ruby sw=2 ts=2 :
