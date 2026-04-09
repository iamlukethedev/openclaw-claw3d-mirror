#!/bin/sh
set -eu

# Run the gateway headlessly for Fly deployments.
# Claw3D talks to the gateway over Flycast, so the OpenClaw Control UI does not
# need to be exposed from this container.
#
# - controlUi.allowedOrigins: accept any origin so Flycast hostnames pass the
#   WebSocket origin check (the app is only reachable on the private network).
# - controlUi.dangerouslyDisableDeviceAuth: allow the Claw3D server-side proxy
#   to connect without device identity while preserving operator scopes.
# - trustedProxies: mark the Fly proxy (172.16.0.0/12) and 6PN (fdaa::/16) as
#   trusted so forwarded connections are treated as local.
node dist/index.js config set --batch-json '[
  {"path":"gateway.mode","value":"local"},
  {"path":"gateway.bind","value":"lan"},
  {"path":"gateway.controlUi.enabled","value":false},
  {"path":"gateway.controlUi.allowedOrigins","value":["*"]},
  {"path":"gateway.controlUi.dangerouslyDisableDeviceAuth","value":true},
  {"path":"gateway.trustedProxies","value":["172.16.0.0/12","fdaa::/16"]}
]' >/dev/null

node --input-type=module <<'EOF'
import fs from "node:fs";
import path from "node:path";

const stateDir = process.env.OPENCLAW_STATE_DIR?.trim() || "/home/node/.openclaw";
const agentDir = path.join(stateDir, "agents", "main", "agent");
const authStorePath = path.join(agentDir, "auth-profiles.json");

const ensureEnvBackedProfile = (profiles, profileId, provider, envVar) => {
  if (!process.env[envVar]?.trim()) {
    return;
  }
  profiles[profileId] = {
    type: "api_key",
    provider,
    keyRef: {
      source: "env",
      provider: "default",
      id: envVar,
    },
  };
};

fs.mkdirSync(agentDir, { recursive: true });

let store = { version: 1, profiles: {} };
try {
  const raw = fs.readFileSync(authStorePath, "utf8");
  const parsed = JSON.parse(raw);
  if (parsed && typeof parsed === "object" && typeof parsed.profiles === "object") {
    store = {
      version: 1,
      profiles: { ...parsed.profiles },
    };
  }
} catch {
  // Start from a clean auth store if one does not exist yet.
}

ensureEnvBackedProfile(store.profiles, "openai:default", "openai", "OPENAI_API_KEY");
ensureEnvBackedProfile(store.profiles, "openrouter:default", "openrouter", "OPENROUTER_API_KEY");
ensureEnvBackedProfile(store.profiles, "anthropic:default", "anthropic", "ANTHROPIC_API_KEY");

fs.writeFileSync(authStorePath, `${JSON.stringify(store, null, 2)}\n`, {
  encoding: "utf8",
  mode: 0o600,
});
EOF

exec node openclaw.mjs gateway --allow-unconfigured --port 3000 --bind lan
