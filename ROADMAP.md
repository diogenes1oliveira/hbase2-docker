- Complete the .dev/bump-versions.sh and hbase-health-check.sh script;
- Setting up a tiny log rotation together with logging to console, so we can see
  logs via both the UI and through the docker API;
- Using a hbase:hadoop user inside Docker as well;
- Use supervisord to properly manage the processes inside? Might take care of
  logging as well, and we could have a HTTP interface to restart processes instead of SSH;
- Container do TestContainers;
- Loading a .env file;
- docker-entrypont init.d
