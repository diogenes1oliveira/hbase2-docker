- Implement the .dev/bump-versions.sh and bin/hbase-health-check.sh scripts;
- Use supervisord to properly manage the processes inside? Might take care of
  logging as well, and we could have a HTTP interface to restart processes instead of SSH;
- Container do TestContainers;
- Verify stopping process in hbase-run-foreground.sh, seems too abrupt?
- Using GitHub actions;
