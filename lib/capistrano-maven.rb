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
          _cset(:mvn_bin) { File.join(mvn_path, "bin", "mvn") }
          _cset(:mvn_bin_local) { File.join(mvn_path_local, "bin", "mvn") }
          _cset(:mvn_cmd) {
            if fetch(:mvn_java_home, nil)
              "env JAVA_HOME=#{mvn_java_home} #{mvn_bin} #{mvn_options.join(' ')}"
            else
              "#{mvn_bin} #{mvn_options.join(' ')}"
            end
          }
          _cset(:mvn_cmd_local) {
            if fetch(:mvn_java_home_local, nil)
              "env JAVA_HOME=#{mvn_java_home_local} #{mvn_bin_local} #{mvn_options_local.join(' ')}"
            else
              "#{mvn_bin_local} #{mvn_options_local.join(' ')}"
            end
          }
          _cset(:mvn_project_path) { release_path }
          _cset(:mvn_project_path_local) { File.expand_path(".") }
          _cset(:mvn_target_path) { File.join(mvn_project_path, "target") }
          _cset(:mvn_target_path_local) { File.join(mvn_project_path_local, "target") }
          _cset(:mvn_template_path) { File.expand_path("config/templates") }
          _cset(:mvn_goals, %w(clean package))
          _cset(:mvn_common_options) {
            options = []
            options << "-P#{mvn_profiles.join(',')}" unless fetch(:mvn_profiles, []).empty?
            options << "-Dmaven.test.skip=true" if fetch(:mvn_skip_tests, false)
            options << "-U" if fetch(:mvn_update_snapshots, false)
            options << "-B"
            options
          }
          _cset(:mvn_options) {
            options = mvn_common_options + fetch(:mvn_extra_options, [])
            if mvn_update_settings
              settings = File.join(mvn_settings_path, mvn_settings.first)
              options << "--settings=#{settings}"
            end
            options
          }
          _cset(:mvn_options_local) {
            options = mvn_common_options + fetch(:mvn_extra_options_local, [])
            if mvn_update_settings_locally
              settings = File.join(mvn_settings_path_local, mvn_settings_local.first)
              options << "--settings=#{settings}"
            end
            options
          }

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

          _cset(:mvn_update_settings) { not(mvn_settings.empty?) }
          _cset(:mvn_update_settings_locally) { not(mvn_settings_local.empty?) }
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

          desc("Update maven build.")
          task(:update, :except => { :no_release => true }) {
            transaction {
              if mvn_update_locally
                update_locally
              else
                execute
              end
            }
          }
          after 'deploy:finalize_update', 'mvn:update'

          desc("Update maven build locally.")
          task(:update_locally, :except => { :no_release => true }) {
            transaction {
              execute_locally
              upload_locally
            }
          }

          def _mvn(cmd, path, goals=[])
            "cd #{path.dump} && #{cmd} #{goals.map { |s| s.dump }.join(' ')}"
          end

          def _mvn_parse_version(s)
            # FIXME: is there any better way to get project version?
            s.split(/(?:\r?\n)+/).reject { |line| /^\[[A-Z]+\]/ =~ line }.last
          end

          _cset(:mvn_release_build, false)
          _cset(:mvn_snapshot_pattern, /-SNAPSHOT$/i)
          _cset(:mvn_project_version) {
            _mvn_parse_version(capture(_mvn(mvn_cmd, mvn_project_path, %w(-Dexpression=project.version help:evaluate))))
          }
          _cset(:mvn_project_version_local) {
            _mvn_parse_version(run_locally(_mvn(mvn_cmd_local, mvn_project_path_local, %w(-Dexpression=project.version help:evaluate))))
          }

          def _validate_project_version(version_key)
            if mvn_release_build
              version = fetch(version_key)
              if mvn_snapshot_pattern === version
                abort("Skip to build project since \`#{version}' is a SNAPSHOT version.")
              end
            end
          end

          desc("Perform maven build.")
          task(:execute, :except => { :no_release => true }) {
            on_rollback {
              run(_mvn(mvn_cmd, mvn_project_path, %w(clean)))
            }
            _validate_project_version(:mvn_project_version)
            run(_mvn(mvn_cmd, mvn_project_path, mvn_goals))
          }

          desc("Perform maven build locally.")
          task(:execute_locally, :except => { :no_release => true }) {
            on_rollback {
              run_locally(_mvn(mvn_cmd_local, mvn_project_path_local, %w(clean)))
            }
            _validate_project_version(:mvn_project_version_local)
            cmdline = _mvn(mvn_cmd_local, mvn_project_path_local, mvn_goals)
            logger.info(cmdline)
            abort("execution failure") unless system(cmdline)
          }

          _cset(:mvn_tar, 'tar')
          _cset(:mvn_tar_local, 'tar')
          _cset(:mvn_target_archive) {
            "#{mvn_target_path}.tar.gz"
          }
          _cset(:mvn_target_archive_local) {
            "#{mvn_target_path_local}.tar.gz"
          }
          task(:upload_locally, :except => { :no_release => true }) {
            on_rollback {
              run("rm -rf #{mvn_target_path} #{mvn_target_archive}")
            }
            begin
              run_locally("cd #{File.dirname(mvn_target_path_local)} && #{mvn_tar_local} chzf #{mvn_target_archive_local} #{File.basename(mvn_target_path_local)}")
              upload(mvn_target_archive_local, mvn_target_archive)
              run("cd #{File.dirname(mvn_target_path)} && #{mvn_tar} xzf #{mvn_target_archive} && rm -f #{mvn_target_archive}")
            ensure
              run_locally("rm -f #{mvn_target_archive_local}")
            end
          }
        }
      }
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Maven)
end

# vim:set ft=ruby :
