require "capistrano-maven/version"
require "capistrano"
require "capistrano/configuration/actions/file_transfer_ext"
require "capistrano/configuration/resources/file_resources"
require "uri"

module Capistrano
  module Maven
    def self.extended(configuration)
      configuration.load {
        namespace(:mvn) {
          _cset(:mvn_version, "3.0.5")
          _cset(:mvn_major_version) { mvn_version.split(".").first.to_i }
          _cset(:mvn_archive_url) {
            "http://www.apache.org/dist/maven/maven-#{mvn_major_version}/#{mvn_version}/binaries/apache-maven-#{mvn_version}-bin.tar.gz"
          }
          _cset(:mvn_tools_path) { File.join(shared_path, "tools", "mvn") }
          _cset(:mvn_tools_path_local) { File.expand_path("tools/mvn") }
          _cset(:mvn_archive_path) { mvn_tools_path }
          _cset(:mvn_archive_path_local) { mvn_tools_path_local }
          _cset(:mvn_archive_file) { File.join(mvn_archive_path, File.basename(URI.parse(mvn_archive_url).path)) }
          _cset(:mvn_archive_file_local) { File.join(mvn_archive_path_local, File.basename(URI.parse(mvn_archive_url).path)) }
          _cset(:mvn_path) { File.join(mvn_tools_path, File.basename(URI.parse(mvn_archive_url).path, "-bin.tar.gz")) }
          _cset(:mvn_path_local) { File.join(mvn_tools_path_local, File.basename(URI.parse(mvn_archive_url).path, "-bin.tar.gz")) }
          _cset(:mvn_bin_path) { File.join(mvn_path, "bin") }
          _cset(:mvn_bin_path_local) { File.join(mvn_path_local, "bin") }
          _cset(:mvn_bin) { File.join(mvn_bin_path, "mvn") }
          _cset(:mvn_bin_local) { File.join(mvn_bin_path_local, "mvn") }
          _cset(:mvn_project_path) { release_path }
          _cset(:mvn_project_path_local) { File.expand_path(".") }
          _cset(:mvn_template_path) { File.expand_path("config/templates") }

          ## Maven environment
          _cset(:mvn_common_environment, {})
          _cset(:mvn_default_environment) {
            environment = mvn_common_environment.dup
            environment["JAVA_HOME"] = fetch(:mvn_java_home) if exists?(:mvn_java_home)
            if exists?(:mvn_java_options)
              environment["MAVEN_OPTS"] = [ fetch(:mvn_java_options, []) ].flatten.join(":")
            end
            environment["PATH"] = [ mvn_bin_path, "$PATH" ].join(":") if mvn_setup_remotely
            environment
          }
          _cset(:mvn_default_environment_local) {
            environment = mvn_common_environment.dup
            environment["JAVA_HOME"] = fetch(:mvn_java_home_local) if exists?(:mvn_java_home_local)
            if exists?(:mvn_java_options_local)
              environment["MAVEN_OPTS"] = [ fetch(:mvn_java_options_local, []) ].flatten.join(":")
            end
            environment["PATH"] = [ mvn_bin_path_local, "$PATH" ].join(":") if mvn_setup_locally
            environment
          }
          _cset(:mvn_environment) { mvn_default_environment.merge(fetch(:mvn_extra_environment, {})) }
          _cset(:mvn_environment_local) { mvn_default_environment_local.merge(fetch(:mvn_extra_environment_local, {})) }
          def _command(cmdline, options={})
            environment = options.fetch(:env, {})
            if environment.empty?
              cmdline
            else
              env = (["env"] + environment.map { |k, v| "#{k}=#{v.dump}" }).join(" ")
              "#{env} #{cmdline}"
            end
          end
          def command(cmdline, options={})
            _command(cmdline, :env => mvn_environment.merge(options.fetch(:env, {})))
          end
          def command_local(cmdline, options={})
            _command(cmdline, :env => mvn_environment_local.merge(options.fetch(:env, {})))
          end
          _cset(:mvn_cmd) { command("#{mvn_bin.dump} #{mvn_options.map { |x| x.dump }.join(" ")}") }
          _cset(:mvn_cmd_local) { command_local("#{mvn_bin_local.dump} #{mvn_options_local.map { |x| x.dump }.join(" ")}") }
          _cset(:mvn_goals, %w(clean package))
          _cset(:mvn_common_options) {
            options = []
            options << "-P#{mvn_profiles.join(",")}" unless fetch(:mvn_profiles, []).empty?
            options << "-Dmaven.test.skip=true" if fetch(:mvn_skip_tests, false)
            options << "-U" if fetch(:mvn_update_snapshots, false)
            options << "-B"
            options
          }
          _cset(:mvn_default_options) {
            options = mvn_common_options.dup
            options += mvn_settings.map { |s| "--settings=#{File.join(mvn_settings_path, s).dump}" } if mvn_update_settings
            options
          }
          _cset(:mvn_default_options_local) {
            options = mvn_common_options.dup
            options += mvn_settings_local.map { |s| "--settings=#{File.join(mvn_settings_path_local, s).dump}" } if mvn_update_settings_locally
            options
          }
          _cset(:mvn_options) { mvn_default_options + fetch(:mvn_extra_options, []) }
          _cset(:mvn_options_local) { mvn_default_options_local + fetch(:mvn_extra_options_local, []) }

          _cset(:mvn_setup_remotely) { mvn_update_remotely }
          _cset(:mvn_setup_locally) { mvn_update_locally }
          _cset(:mvn_update_remotely) { not(mvn_update_locally) }
          _cset(:mvn_update_locally) { # perform update on localhost
            if exists?(:mvn_compile_locally)
              logger.info(":mvn_compile_locally has been deprecated. use :mvn_update_locally instead.")
              fetch(:mvn_compile_locally, false)
            else
              false
            end
          }

          if top.namespaces.key?(:multistage)
            after "multistage:ensure", "mvn:setup_default_environment"
          else
            on :start do
              if top.namespaces.key?(:multistage)
                after "multistage:ensure", "mvn:setup_default_environment"
              else
                setup_default_environment
              end
            end
          end

          _cset(:mvn_environment_join_keys, %w(DYLD_LIBRARY_PATH LD_LIBRARY_PATH MANPATH PATH))
          def _merge_environment(x, y)
            x.merge(y) { |key, x_val, y_val|
              if mvn_environment_join_keys.include?(key)
                [ y_val, x_val ].join(":")
              else
                y_val
              end
            }
          end

          task(:setup_default_environment, :except => { :no_release => true }) {
            if fetch(:mvn_setup_default_environment, true)
              set(:default_environment, _merge_environment(default_environment, mvn_environment))
            end
          }

          def _invoke_command(cmdline, options={})
            if options[:via] == :run_locally
              run_locally(cmdline)
            else
              invoke_command(cmdline, options)
            end
          end

          def _download(uri, filename, options={})
            options = fetch(:mvn_download_options, {}).merge(options)
            if FileTest.exist?(filename)
              logger.info("Found downloaded archive: #{filename}")
            else
              dirs = [ File.dirname(filename) ]
              execute = []
              execute << "mkdir -p #{dirs.uniq.map { |x| x.dump }.join(" ")}"
              execute << "wget --no-verbose -O #{filename.dump} #{uri.dump}"
              _invoke_command(execute.join(" && "), options)
            end
          end

          def _upload(filename, remote_filename, options={})
            _invoke_command("mkdir -p #{File.dirname(remote_filename).dump}", options)
            transfer_if_modified(:up, filename, remote_filename, fetch(:mvn_upload_options, {}).merge(options))
          end

          def _install(filename, destination, options={})
            execute = []
            execute << "mkdir -p #{File.dirname(destination).dump}"
            execute << "tar xf #{filename.dump} -C #{File.dirname(destination).dump}"
            _invoke_command(execute.join(" && "), options)
          end

          def _installed?(destination, options={})
            mvn = File.join(destination, "bin", "mvn")
            cmdline = "test -d #{destination.dump} && test -x #{mvn.dump}"
            _invoke_command(cmdline, options)
            true
          rescue
            false
          end

          ## setup
          desc("Setup maven.")
          task(:setup, :except => { :no_release => true }) {
            transaction {
              setup_remotely if mvn_setup_remotely
              setup_locally if mvn_setup_locally
            }
          }
          after "deploy:setup", "mvn:setup"

          task(:setup_remotely, :except => { :no_release => true }) {
            _download(mvn_archive_url, mvn_archive_file_local, :via => :run_locally)
            _upload(mvn_archive_file_local, mvn_archive_file)
            unless _installed?(mvn_path)
              _install(mvn_archive_file, mvn_path)
              _installed?(mvn_path)
            end
            update_settings if mvn_update_settings
          }

          desc("Setup maven locally.")
          task(:setup_locally, :except => { :no_release => true }) {
            _download(mvn_archive_url, mvn_archive_file_local, :via => :run_locally)
            unless _installed?(mvn_path_local, :via => :run_locally)
              _install(mvn_archive_file_local, mvn_path_local, :via => :run_locally)
              _installed?(mvn_path_local, :via => :run_locally)
            end
            update_settings_locally if mvn_update_settings_locally
          }

          _cset(:mvn_update_settings) { mvn_setup_remotely and not(mvn_settings.empty?) }
          _cset(:mvn_update_settings_locally) { mvn_setup_locally and not(mvn_settings_local.empty?) }
          _cset(:mvn_settings_path) { mvn_tools_path }
          _cset(:mvn_settings_path_local) { mvn_tools_path_local }
          _cset(:mvn_settings, [])
          _cset(:mvn_settings_local) { mvn_settings }
          task(:update_settings, :except => { :no_release => true }) {
            mvn_settings.each do |file|
              safe_put(template(file, :path => mvn_template_path), File.join(mvn_settings_path, file))
            end
          }

          task(:update_settings_locally, :except => { :no_release => true }) {
            mvn_settings_local.each do |file|
              File.write(File.join(mvn_settings_path_local, file), template(file, :path => mvn_template_path))
            end
          }

          ## update
          desc("Update maven build.")
          task(:update, :except => { :no_release => true }) {
            transaction {
              update_remotely if mvn_update_remotely
              update_locally if mvn_update_locally
            }
          }
          _cset(:mvn_update_hook_type, :after)
          _cset(:mvn_update_hook, "deploy:finalize_update")
          on(:start) do
            [ mvn_update_hook ].flatten.each do |hook|
              send(mvn_update_hook_type, hook, "mvn:update") if hook
            end
          end

          task(:update_remotely, :except => { :no_release => true }) {
            execute_remotely
          }

          desc("Update maven build locally.")
          task(:update_locally, :except => { :no_release => true }) {
            execute_locally
            upload_locally
          }

          def _parse_project_version(s)
            # FIXME: is there any better way to get project version?
            s.split(/(?:\r?\n)+/).reject { |line| /^\[[A-Z]+\]/ =~ line }.last
          end

          _cset(:mvn_project_version) {
            _parse_project_version(mvn.exec(%w(-Dexpression=project.version help:evaluate), :via => :capture))
          }
          _cset(:mvn_project_version_local) {
            _parse_project_version(mvn.exec_locally(%w(-Dexpression=project.version help:evaluate), :via => :capture_locally))
          }
          _cset(:mvn_snapshot_pattern, /-SNAPSHOT$/i)
          def _validate_project_version(key)
            if fetch(:mvn_release_build, false)
              version = fetch(key)
              abort("Skip to build project since \`#{version}' is a SNAPSHOT version.") if mvn_snapshot_pattern === version
            end
          end

          desc("Perform maven build.")
          task(:execute, :except => { :no_release => true }) {
            execute_remotely
          }
          task(:execute_remotely, :except => { :no_release => true }) {
            on_rollback do
              mvn.exec("clean")
            end
            _validate_project_version(:mvn_project_version)
            mvn.exec(mvn_goals)
          }

          desc("Perform maven build locally.")
          task(:execute_locally, :except => { :no_release => true }) {
            on_rollback do
              mvn.exec_locally("clean")
            end
            _validate_project_version(:mvn_project_version_local)
            mvn.exec_locally(mvn_goals)
          }

          _cset(:mvn_target_path) { File.join(mvn_project_path, "target") }
          _cset(:mvn_target_path_local) { File.join(mvn_project_path_local, "target") }
          task(:upload_locally, :except => { :no_release => true }) {
            on_rollback do
              run("rm -rf #{mvn_target_path.dump}")
            end
            filename = "#{mvn_target_path_local}.tar.gz"
            remote_filename = "#{mvn_target_path}.tar.gz"
            begin
              run_locally("cd #{File.dirname(mvn_target_path_local).dump} && tar chzf #{filename.dump} #{File.basename(mvn_target_path_local).dump}")
              run("mkdir -p #{File.dirname(mvn_target_path).dump}")
              top.upload(filename, remote_filename)
              run("cd #{File.dirname(mvn_target_path).dump} && tar xzf #{remote_filename}")
            ensure
              run("rm -f #{remote_filename.dump}") rescue nil
              run_locally("rm -f #{filename.dump}") rescue nil
            end
          }

          def _exec_command(args=[], options={})
            args = [ args ].flatten
            mvn = options.fetch(:mvn, "mvn")
            execute = []
            execute << "cd #{options[:path].dump}" if options.key?(:path)
            execute << "#{mvn} #{args.map { |x| x.dump }.join(" ")}"
            execute.join(" && ")
          end

          ## public methods
          def exec(args=[], options={})
            cmdline = _exec_command(args, { :path => mvn_project_path, :mvn => mvn_cmd, :via => :run }.merge(options))
            _invoke_command(cmdline, options)
          end

          def exec_locally(args=[], options={})
            via = options.delete(:via)
            cmdline = _exec_command(args, { :path => mvn_project_path_local, :mvn => mvn_cmd_local, :via => :run_locally }.merge(options))
            if via == :capture_locally
              _invoke_command(cmdline, options.merge(:via => :run_locally))
            else
              logger.trace("executing locally: #{cmdline.dump}")
              elapsed = Benchmark.realtime do
                system(cmdline)
              end
              if $?.to_i > 0 # $? is command exit code (posix style)
                raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
              end
              logger.trace "command finished in #{(elapsed * 1000).round}ms"
            end
          end
        }
      }
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Maven)
end

# vim:set ft=ruby :
