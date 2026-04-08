#!/bin/sh
set -eu

# Run the gateway headlessly for Fly deployments.
# Claw3D talks to the gateway over Flycast, so the OpenClaw Control UI does not
# need to be exposed from this container.
#
# - controlUi.allowedOrigins: accept any origin so Flycast hostnames pass the
#   WebSocket origin check (the app is only reachable on the private network).
# - trustedProxies: mark the Fly proxy (172.16.0.0/12) and 6PN (fdaa::/16) as
#   trusted so forwarded connections are treated as local.
node dist/index.js config set --batch-json '[
  {"path":"gateway.mode","value":"local"},
  {"path":"gateway.bind","value":"lan"},
  {"path":"gateway.controlUi.enabled","value":false},
  {"path":"gateway.controlUi.allowedOrigins","value":["*"]},
  {"path":"gateway.trustedProxies","value":["172.16.0.0/12","fdaa::/16"]}
]' >/dev/null

exec node openclaw.mjs gateway --allow-unconfigured --port 3000 --bind lan
