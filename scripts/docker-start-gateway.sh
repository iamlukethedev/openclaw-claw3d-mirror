#!/bin/sh
set -eu

# Run the gateway headlessly for Fly deployments.
# Claw3D talks to the gateway over Flycast, so the OpenClaw Control UI does not
# need to be exposed from this container.
node dist/index.js config set --batch-json '[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"lan"},{"path":"gateway.controlUi.enabled","value":false}]' >/dev/null

exec node openclaw.mjs gateway --allow-unconfigured --port 3000 --bind lan
