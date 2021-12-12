- Implement the .dev/bump-versions.sh and bin/hbase-health-check.sh scripts;
- Setting up a tiny log rotation together with logging to console, so we can see
  logs via both the UI and through the docker API;
- Use supervisord to properly manage the processes inside? Might take care of
  logging as well, and we could have a HTTP interface to restart processes instead of SSH;
- Container do TestContainers;
