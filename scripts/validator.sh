#!/usr/bin/env bash
# /**
#  * Smart Doc — Validator
#  * Responsibility:
#  *   - Perform early validation of environment, secrets, and basic tooling.
#  *   - Fail fast only on critical requirements (API key). Soft-skip on optional pieces when appropriate.
#  * Invariants (keep in future iterations):
#  *   - Do not write or mutate repository files.
#  *   - Keep logs concise with emojis.
#  * Inputs: SMART_DOC_API_TOKEN or OPENAI_API_KEY, INPUT_PROMPT_TEMPLATE, INPUT_DOCS_FOLDER.
#  */
set -euo pipefail

log() { echo "🧪 [validator] $*"; }
warn() { echo "::warning::⚠️ $*"; }
err() { echo "::error::❌ $*"; }

INPUT_DOCS_FOLDER=${INPUT_DOCS_FOLDER:-docs}
INPUT_PROMPT_TEMPLATE=${INPUT_PROMPT_TEMPLATE:-}

# Auth mapping consistency check mirroring entrypoint behavior
if [[ -n "${OPENAI_API_KEY:-}" && -n "${INPUT_SMART_DOC_API_TOKEN:-}" && "${OPENAI_API_KEY}" != "${INPUT_SMART_DOC_API_TOKEN}" ]]; then
  err "Both OPENAI_API_KEY and SMART_DOC_API_TOKEN are defined with different values. Define ONLY SMART_DOC_API_TOKEN."
  exit 1
fi

if [[ -n "${INPUT_SMART_DOC_API_TOKEN:-}" ]]; then
  export OPENAI_API_KEY="${INPUT_SMART_DOC_API_TOKEN}"
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  err "SMART_DOC_API_TOKEN is required (mapped to OPENAI_API_KEY)."
  exit 1
fi

# Tooling
need_cmd() { command -v "$1" >/dev/null 2>&1 || { warn "Missing optional dependency: $1"; return 1; }; }
need_cmd git >/dev/null 2>&1 || true
need_cmd jq >/dev/null 2>&1 || true
need_cmd curl >/dev/null 2>&1 || true
need_cmd gh >/dev/null 2>&1 || true

# Template
if [[ -n "$INPUT_PROMPT_TEMPLATE" && ! -f "$INPUT_PROMPT_TEMPLATE" ]]; then
  warn "INPUT_PROMPT_TEMPLATE not found: $INPUT_PROMPT_TEMPLATE"
fi

# Keep validator side-effects minimal; scaffolding is now orchestrated by entrypoint via scripts/cold-start-scaffold.sh
mkdir -p "$INPUT_DOCS_FOLDER"

# Jira MCP auto-configuration
# If JIRA_EMAIL, JIRA_API_TOKEN, and JIRA_DOMAIN are all set (non-empty),
# write ~/.codex/config.toml with the Jira MCP server configuration.
if [[ -n "${JIRA_EMAIL:-}" && -n "${JIRA_API_TOKEN:-}" && -n "${JIRA_DOMAIN:-}" ]]; then
  CODEX_HOME="${HOME}/.codex"
  mkdir -p "${CODEX_HOME}"
  cat > "${CODEX_HOME}/config.toml" <<EOF
[mcp_servers.jira]
command = "node"
args = ["/path/to/jira-server/build/index.js"]
env = { "JIRA_EMAIL" = "${JIRA_EMAIL}", "JIRA_API_TOKEN" = "${JIRA_API_TOKEN}", "JIRA_DOMAIN" = "${JIRA_DOMAIN}" }
EOF
  log "⚙️ Jira MCP configured at ${CODEX_HOME}/config.toml"
fi

exit 0
