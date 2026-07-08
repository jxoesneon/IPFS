#!/usr/bin/env bash
# Healthcheck for the dart_ipfs service inside the container.
# Uses bash /dev/tcp so no external tools (curl/wget) are required.

exec 3<> /dev/tcp/localhost/8080 || exit 1
printf 'GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3
head -1 <&3 | grep -q "200 OK"
