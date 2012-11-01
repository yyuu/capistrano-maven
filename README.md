# capistrano-maven

a capistrano recipe to deploy Apache Maven based projects.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-maven'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-maven

## Usage

This recipes will try to do following things during Capistrano `deploy:setup` and `deploy` tasks.

1. Download and install Maven for current project
2. Prepare Maven's settings.xml for current project (optional)
3. Build Maven project remotely (default) or locally

To build you Maven projects during Capistrano `deploy` tasks, add following in you `config/deploy.rb`. By default, Maven build will run after the Capistrano's `deploy:finalize_update`.

    # in "config/deploy.rb"
    require 'capistrano-maven'
    set(:mvn_version, '3.0.4') # Maven version to build project

Following options are available to manage your Maven build.

 * `:mvn_version` - project Maven version
 * `:mvn_archive_url` - download URL for specified Maven version
 * `:mvn_compile_locally` - compile project on localhost. false by default.
 * `:mvn_goals` - Maven goals to execute. default is "clean package".
 * `:mvn_profiles` - Maven profiles to use.
 * `:mvn_skip_tests` - add `-Dmaven.test.skip=true` in Maven commands. false by default.
 * `:mvn_update_snapshots` - add `--update-snapshots` if Maven commands. false by default.
 * `:mvn_update_settings` - update `settings.xml` or not. false by default.
 * `:mvn_update_settings_locally` - udate `settings.xml` or not on local compilation. false by default.
 * `:mvn_settings` - list of your optional setting files for Maven. use `%w(settings.xml)` by default.
 * `:mvn_settings_local` - list of your optional setting files for Maven. use `%w(settings.xml)` by default.
 * `:mvn_settings_path` - the destination path of the optional `settings.xml` file. use `:release_path` by default.
 * `:mvn_settings_path_local` - the destination path of the optional `settings.xml` file. use `pwd` by default.
 * `:mvn_template_path` - specify ERB template path for settings.xml.
 * `:mvn_java_home` - optional `JAVA_HOME` settings for Maven commands.
 * `:mvn_java_home_local` - optional `JAVA_HOME` settings for Maven commands in localhost.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

- YAMASHITA Yuu (https://github.com/yyuu)
- Geisha Tokyo Entertainment Inc. (http://www.geishatokyo.com/)

## License

MIT
