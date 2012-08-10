
require 'capistrano'
require 'uri'

module Capistrano
  module Maven
    def self.extended(configuration)
      configuration.load {
        namespace(:mvn) {
          _cset(:mvn_version, '3.0.4')
          _cset(:mvn_archive_url) {
            [
              "http://www.apache.org/dist//maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz",
              "http://ftp.kddilabs.jp/infosystems/apache//maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz",
              "http://ftp.riken.jp/net/apache//maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz",
              "http://ftp.jaist.ac.jp/pub/apache//maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz",
              "http://ftp.meisei-u.ac.jp/mirror/apache/dist//maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz",
            ].shuffle().first()
          }
          _cset(:mvn_archive_file) {
            File.join(shared_path, 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path))
          }
          _cset(:mvn_archive_file_local) {
            File.join(File.expand_path('.'), 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path))
          }
          _cset(:mvn_path) {
            File.join(shared_path, 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path, "-bin.tar.gz"))
          }
          _cset(:mvn_path_local) {
            File.join(File.expand_path('.'), 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path, "-bin.tar.gz"))
          }
          _cset(:mvn_bin) {
            File.join(mvn_path, 'bin', 'mvn')
          }
          _cset(:mvn_bin_local) {
            File.join(mvn_path_local, 'bin', 'mvn')
          }
          _cset(:mvn_cmd) {
            settings = "--settings=#{mvn_settings_path}/settings.xml" if mvn_update_settings
            if fetch(:mvn_java_home, nil)
              "env JAVA_HOME=#{mvn_java_home} #{mvn_bin} #{mvn_options.join(' ')} #{settings}"
            else
              "#{mvn_bin} #{mvn_options.join(' ')} #{settings}"
            end
          }
          _cset(:mvn_cmd_local) {
            settings = "--settings=#{mvn_settings_path_local}/settings.xml" if mvn_update_settings_locally
            if fetch(:mvn_java_home_local, nil)
              "env JAVA_HOME=#{mvn_java_home_local} #{mvn_bin_local} #{mvn_options_local.join(' ')} #{settings}"
            else
              "#{mvn_bin_local} #{mvn_options_local.join(' ')} #{settings}"
            end
          }
          _cset(:mvn_project_path) {
            release_path
          }
          _cset(:mvn_project_path_local) {
            Dir.pwd
          }
          _cset(:mvn_target_path) {
            File.join(mvn_project_path, 'target')
          }
          _cset(:mvn_target_path_local) {
            File.join(mvn_project_path_local, File.basename(mvn_target_path))
          }
          _cset(:mvn_template_path, File.join(File.dirname(__FILE__), 'templates'))
          _cset(:mvn_update_settings, false)
          _cset(:mvn_update_settings_locally, false)
          _cset(:mvn_settings_path) {
            mvn_project_path
          }
          _cset(:mvn_settings_path_local) {
            mvn_project_path_local
          }
          _cset(:mvn_settings, %w(settings.xml))
          _cset(:mvn_settings_local, %w(settings.xml))
          _cset(:mvn_cleanup_settings, [])
          _cset(:mvn_cleanup_settings_local, [])
          _cset(:mvn_compile_locally, false) # perform precompilation on localhost
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
            mvn_common_options + fetch(:mvn_extra_options, [])
          }
          _cset(:mvn_options_local) {
            mvn_common_options + fetch(:mvn_extra_options_local, [])
          }

          desc("Setup maven.")
          task(:setup, :roles => :app, :except => { :no_release => true }) {
            transaction {
              install
              update_settings if mvn_update_settings
              setup_locally if mvn_compile_locally
            }
          }
          after 'deploy:setup', 'mvn:setup'

          desc("Setup maven locally.")
          task(:setup_locally, :except => { :no_release => true }) {
            transaction {
              install_locally
              update_settings_locally if mvn_update_settings_locally
            }
          }

          task(:install, :roles => :app, :except => { :no_release => true }) {
            dirs = [ File.dirname(mvn_archive_file), File.dirname(mvn_path) ].uniq()
            run(<<-E)
              if ! test -x #{mvn_bin}; then
                mkdir -p #{dirs.join(' ')} &&
                ( test -f #{mvn_archive_file} || wget --no-verbose -O #{mvn_archive_file} #{mvn_archive_url} ) &&
                ( test -d #{mvn_path} || tar xf #{mvn_archive_file} -C #{File.dirname(mvn_path)} ) &&
                test -x #{mvn_bin};
              fi &&
              #{mvn_cmd} --version;
            E
          }

          task(:install_locally, :except => { :no_release => true }) { # TODO: make install and install_locally together
            dirs = [ File.dirname(mvn_archive_file_local), File.dirname(mvn_path_local) ].uniq()
            run_locally(<<-E)
              if ! test -x #{mvn_bin_local}; then
                mkdir -p #{dirs.join(' ')} &&
                ( test -f #{mvn_archive_file_local} || wget --no-verbose -O #{mvn_archive_file_local} #{mvn_archive_url} ) &&
                ( test -d #{mvn_path_local} || tar xf #{mvn_archive_file_local} -C #{File.dirname(mvn_path_local)} ) &&
                test -x #{mvn_bin_local};
              fi &&
              #{mvn_cmd_local} --version;
            E
          }

          task(:update_settings, :roles => :app, :except => { :no_release => true }) {
            tmp_files = []
            on_rollback {
              run("rm -f #{tmp_files.join(' ')}") unless tmp_files.empty?
            }
            mvn_settings.each { |file|
              tmp_files << tmp_file = File.join('/tmp', File.basename(file))
              src_file = File.join(mvn_template_path, file)
              dst_file = File.join(mvn_project_path, file)
              run(<<-E)
                ( test -d #{File.dirname(dst_file)} || mkdir -p #{File.dirname(dst_file)} ) &&
                ( test -f #{dst_file} && mv -f #{dst_file} #{dst_file}.orig; true );
              E
              if File.file?(src_file)
                put(File.read(src_file), tmp_file)
              elsif File.file?("#{src_file}.erb")
                put(ERB.new(File.read("#{src_file}.erb")).result(binding), tmp_file)
              else
                abort("mvn:update_settings: no such template found: #{src_file} or #{src_file}.erb")
              end
              run("diff #{dst_file} #{tmp_file} || mv -f #{tmp_file} #{dst_file}")
            }
            run("rm -f #{mvn_cleanup_settings.join(' ')}") unless mvn_cleanup_settings.empty?
          }

          task(:update_settings_locally, :except => { :no_release => true }) {
            mvn_settings_local.each { |file|
              src_file = File.join(mvn_template_path, file)
              dst_file = File.join(mvn_project_path_local, file)
              run_locally(<<-E)
                ( test -d #{File.dirname(dst_file)} || mkdir -p #{File.dirname(dst_file)} ) &&
                ( test -f #{dst_file} && mv -f #{dst_file} #{dst_file}.orig; true );
              E
              if File.file?(src_file)
                File.open(dst_file, 'w') { |fp|
                  fp.write(File.read(src_file))
                }
              elsif File.file?("#{src_file}.erb")
                File.open(dst_file, 'w') { |fp|
                  fp.write(ERB.new(File.read("#{src_file}.erb")).result(binding))
                }
              else
                abort("mvn:update_settings_locally: no such template: #{src_file} or #{src_file}.erb")
              end
            }
            run_locally("rm -f #{mvn_cleanup_settings_local.join(' ')}") unless mvn_cleanup_settings_local.empty?
          }

          desc("Update maven build.")
          task(:update, :roles => :app, :except => { :no_release => true }) {
            transaction {
              if mvn_compile_locally
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

          desc("Perform maven build.")
          task(:execute, :roles => :app, :except => { :no_release => true }) {
            on_rollback {
              run("cd #{mvn_project_path} && #{mvn_cmd} clean")
            }
            run("cd #{mvn_project_path} && #{mvn_cmd} #{mvn_goals.join(' ')}")
          }

          desc("Perform maven build locally.")
          task(:execute_locally, :roles => :app, :except => { :no_release => true }) {
            setup_locally
            on_rollback {
              run_locally("cd #{mvn_project_path_local} && #{mvn_cmd_local} clean")
            }
            cmd = "cd #{mvn_project_path_local} && #{mvn_cmd_local} #{mvn_goals.join(' ')}"
            logger.info(cmd)
            abort("execution failure") unless system(cmd)
          }

          task(:upload_locally, :roles => :app, :except => { :no_release => true }) {
            on_rollback {
              run("rm -rf #{mvn_target_path}")
            }
            run_locally("test -d #{mvn_target_path_local}")
            run("mkdir -p #{mvn_target_path}")
            find_servers_for_task(current_task).each { |server|
              run_locally("rsync -lrt --chmod=u+rwX,go+rX #{mvn_target_path_local}/ #{user}@#{server.host}:#{mvn_target_path}/")
            }
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
