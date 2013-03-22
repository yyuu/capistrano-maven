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

    # config/deploy.rb
    require "capistrano-maven"
    set(:mvn_version, "3.0.5") # Maven version to build project

Following options are available to manage your Maven build.

 * `:mvn_version` - The project Maven version.
 * `:mvn_archive_url` - The download URL for specified Maven version.
 * `:mvn_setup_remotely` - Setup `mvn` on remote servers. As same value as `:mvn_update_remotely` by default.
 * `:mvn_setup_locally` - Setup `mvn` on local server. Asa same value as `:mvn_update_locally` by default.
 * `:mvn_update_remotely` - Run `mvn` on remote servers. `true` by default.
 * `:mvn_update_locally` - Run `mvn` on local server. `false` by default.
 * `:mvn_goals` - Maven goals to execute. Run `clean package` by default.
 * `:mvn_settings` - List of your optional setting files for Maven.
 * `:mvn_settings_local` - List of your optional setting files for Maven.
 * `:mvn_template_path` - The local path where the templates of setting files are in. By default, searches from `config/templates`.
 * `:mvn_java_home` - Optional `JAVA_HOME` settings for Maven commands.
 * `:mvn_java_home_local` - Optional `JAVA_HOME` settings for Maven commands in localhost.
 * `:mvn_profiles` - Maven profiles to use.
 * `:mvn_skip_tests` - Add `-Dmaven.test.skip=true` in Maven commands. `false` by default.
 * `:mvn_update_snapshots` - Add `-U` if Maven commands. `false` by default.
 * `:mvn_release_build` - Skip building on SNAPSHOT version. `false` by default.

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
