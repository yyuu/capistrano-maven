require "capistrano-maven/version"
require "capistrano"
require "uri"

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
          _cset(:mvn_settings_path) { mvn_project_path }
          _cset(:mvn_settings_path_local) { mvn_project_path_local }
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
              ERB.new(File.read("#{file}.erb")).result(binding)
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
            tmps = mvn_settings.map { |f| capture("t=$(mktemp /tmp/capistrano-maven.XXXXXXXXXX);rm -f $t;echo $t").chomp }
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
            tmps = mvn_settings.map { |f| `t=$(mktemp /tmp/capistrano-maven.XXXXXXXXXX);rm -f $t;echo $t`.chomp }
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
          task(:execute, :roles => :app, :except => { :no_release => true }) {
            on_rollback {
              run(_mvn(mvn_cmd, mvn_project_path, %w(clean)))
            }
            _validate_project_version(:mvn_project_version)
            run(_mvn(mvn_cmd, mvn_project_path, mvn_goals))
          }

          desc("Perform maven build locally.")
          task(:execute_locally, :roles => :app, :except => { :no_release => true }) {
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
