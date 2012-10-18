
require 'capistrano'
require 'tempfile'
require 'uri'

module Capistrano
  module Maven
    def self.extended(configuration)
      configuration.load {
        namespace(:mvn) {
          _cset(:mvn_version, '3.0.4')
          _cset(:mvn_major_version) {
            mvn_version.split('.').first.to_i
          }
          _cset(:mvn_archive_url) {
            "http://www.apache.org/dist/maven/maven-#{mvn_major_version}/#{mvn_version}/binaries/apache-maven-#{mvn_version}-bin.tar.gz"
          }
          _cset(:mvn_archive_file) {
            File.join(shared_path, 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path))
          }
          _cset(:mvn_archive_file_local) {
            File.join(File.expand_path('.'), 'tools', 'mvn', File.basename(URI.parse(mvn_archive_url).path))
          }
          _cset(:mvn_checksum_url) {
            "#{mvn_archive_url}.md5"
          }
          _cset(:mvn_checksum_file) {
            File.join(shared_path, 'tools', 'mvn', File.basename(URI.parse(mvn_checksum_url).path))
          }
          _cset(:mvn_checksum_file_local) {
            File.join(File.expand_path('.'), 'tools', 'mvn', File.basename(URI.parse(mvn_checksum_url).path))
          }
          _cset(:mvn_checksum_cmd) {
            case File.extname(File.basename(URI.parse(mvn_checksum_url).path))
            when '.md5'  then 'md5sum'
            when '.sha1' then 'sha1sum'
            end
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

          def _validate_archive(archive_file, checksum_file)
            if cmd = fetch(:mvn_checksum_cmd, nil)
              "test `#{cmd} #{archive_file} | cut -d' ' -f1` = `cat #{checksum_file}`"
            else
              "true"
            end
          end

          def _install(options={})
            path = options.delete(:path)
            bin = options.delete(:bin)
            checksum_file = options.delete(:checksum_file)
            checksum_url = options.delete(:checksum_url)
            archive_file = options.delete(:archive_file)
            archive_url = options.delete(:archive_url)
            dirs = [ File.dirname(checksum_file), File.dirname(archive_file), File.dirname(path) ].uniq()
            execute = []
            execute << "mkdir -p #{dirs.join(' ')}"
            execute << (<<-EOS).gsub(/\s+/, ' ').strip
              if ! test -f #{archive_file}; then
                ( rm -f #{checksum_file}; wget --no-verbose -O #{checksum_file} #{checksum_url} ) &&
                wget --no-verbose -O #{archive_file} #{archive_url} &&
                #{_validate_archive(archive_file, checksum_file)} || ( rm -f #{archive_file}; false ) &&
                test -f #{archive_file};
              fi
            EOS
            execute << (<<-EOS).gsub(/\s+/, ' ').strip
              if ! test -x #{bin}; then
                ( test -d #{path} || tar xf #{archive_file} -C #{File.dirname(path)} ) &&
                test -x #{bin};
              fi
            EOS
            execute.join(' && ')
          end

          task(:install, :roles => :app, :except => { :no_release => true }) {
            run(_install(:path => mvn_path, :bin => mvn_bin,
                         :checksum_file => mvn_checksum_file, :checksum_url => mvn_checksum_url,
                         :archive_file => mvn_archive_file, :archive_url => mvn_archive_url))
            run("#{mvn_cmd} --version")
          }

          task(:install_locally, :except => { :no_release => true }) {
            run_locally(_install(:path => mvn_path_local, :bin => mvn_bin_local,
                                 :checksum_file => mvn_checksum_file_local, :checksum_url => mvn_checksum_url,
                                 :archive_file => mvn_archive_file_local, :archive_url => mvn_archive_url))
            run_locally("#{mvn_cmd_local} --version")
          }

          def template(file)
            if File.file?(file)
              File.read(file)
            elsif File.file?("#{file}.erb")
              ERB.new(File.read(file)).result(binding)
            else
              abort("No such template: #{file} or #{file}.erb")
            end
          end

          def _update_settings(files_map, options={})
            execute = []
            dirs = files_map.map { |src, dst| File.dirname(dst) }.uniq
            execute << "mkdir -p #{dirs.join(' ')}" unless dirs.empty?
            files_map.each do |src, dst|
              execute << "( diff -u #{dst} #{src} || mv -f #{src} #{dst} )"
              cleanup = options.fetch(:cleanup, [])
              execute << "rm -f #{cleanup.join(' ')}" unless cleanup.empty?
            end
            execute.join(' && ')
          end

          task(:update_settings, :roles => :app, :except => { :no_release => true }) {
            srcs = mvn_settings.map { |f| File.join(mvn_template_path, f) }
            tmps = mvn_settings.map { |f| t=Tempfile.new('mvn');s=t.path;t.close(true);s }
            dsts = mvn_settings.map { |f| File.join(mvn_settings_path, f) }
            begin
              srcs.zip(tmps).each do |src, tmp|
                put(template(src), tmp)
              end
              run(_update_settings(tmps.zip(dsts), :cleanup => mvn_cleanup_settings)) unless tmps.empty?
            ensure
              run("rm -f #{tmps.join(' ')}") unless tmps.empty?
            end
          }

          task(:update_settings_locally, :except => { :no_release => true }) {
            srcs = mvn_settings_local.map { |f| File.join(mvn_template_path, f) }
            tmps = mvn_settings.map { |f| t=Tempfile.new('mvn');s=t.path;t.close(true);s }
            dsts = mvn_settings_local.map { |f| File.join(mvn_settings_path_local, f) }
            begin
              srcs.zip(tmps).each do |src, tmp|
                File.open(tmp, 'wb') { |fp| fp.write(template(src)) }
              end
              run_locally(_update_settings(tmps.zip(dsts), :cleanup => mvn_cleanup_settings_local)) unless tmps.empty?
            ensure
              run_locally("rm -f #{tmps.join(' ')}") unless tmps.empty?
            end
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
            on_rollback {
              run_locally("cd #{mvn_project_path_local} && #{mvn_cmd_local} clean")
            }
            cmd = "cd #{mvn_project_path_local} && #{mvn_cmd_local} #{mvn_goals.join(' ')}"
            logger.info(cmd)
            abort("execution failure") unless system(cmd)
          }

          _cset(:mvn_tar, 'tar')
          _cset(:mvn_tar_local, 'tar')
          _cset(:mvn_target_archive) {
            "#{mvn_target_path}.tar.gz"
          }
          _cset(:mvn_target_archive_local) {
            "#{mvn_target_path_local}.tar.gz"
          }
          task(:upload_locally, :roles => :app, :except => { :no_release => true }) {
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
