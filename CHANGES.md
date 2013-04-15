v0.1.0 (Yamashita, Yuu)

* Update default Maven version (3.0.4 -> 3.0.5)
* Download Maven archive just once, not as many as target hosts.
* Setup `PATH`, `MAVEN_OPTS` and `JAVA_HOME` in `:default_environment`.
* Rename some of options:
  * `:mvn_compile_locally` -> `:mvn_update_locally`
* Changed default value of `:mvn_settings`. Now it is empty by default. You need to specify the filename explicitly.
* Add convenience methods such like `mvn.exec()`.

v0.1.1 (Yamashita, Yuu)

* Set up `:default_environment` after the loading of the recipes, not after the task start up.

v0.1.2 (Yamashita, Yuu)

* Skip setting up `:default_environment` if the installation is not requested.
* Fix a stupid bug in `mvn.exec_locally()`.
