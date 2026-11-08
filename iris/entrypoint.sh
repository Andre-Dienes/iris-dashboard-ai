#!/bin/bash
# Starts IRIS and, in the background, runs the Copilot startup (MCP tools + sales simulator).
(
  for i in $(seq 1 90); do
    bash -c "cat < /dev/null > /dev/tcp/localhost/1972" 2>/dev/null && break
    sleep 2
  done
  sleep 5
  printf 'zn "COPILOT"\ndo ##class(Copilot.Setup.Installer).Startup()\nhalt\n' > /tmp/copilot-startup.script
  /usr/irissys/bin/irissession IRIS < /tmp/copilot-startup.script > /tmp/copilot-startup.log 2>&1
  cat /tmp/copilot-startup.log
) &
# Optional license key: first *.key in ./keys (mounted at /external/keys),
# same as `-k /external/keys/iris-container-x64.key` in the official docker run command.
KEY="$(ls /external/keys/*.key 2>/dev/null | head -1)"
if [ -n "$KEY" ]; then
  echo "Using license key: $KEY"
  exec /iris-main -k "$KEY" "$@"
fi
exec /iris-main "$@"
