#!/usr/bin/env bash
# /**
#  * Smart Doc — Entrypoint Orchestrator
#  * Responsibility:
#  *   - Orchestrate the Smart Doc pipeline in CI/local runs.
#  *   - Delegate to scripts: validator → diff-detector → prompt-builder → doc-updater → publisher.
#  * Invariants (keep in future iterations):
#  *   - No diff resolution or prompt assembly inline; always use scripts.
#  *   - Keep logs concise with emojis.
#  */
set -euo pipefail

log() { echo "📝 [smart-doc] $*"; }
warn() { echo "::warning::⚠️ $*"; }
err() { echo "::error::❌ $*"; }

INPUT_DOCS_FOLDER=${INPUT_DOCS_FOLDER:-docs}

## Git identity for commits (publisher handles PR push)
git config --global user.name "GitHub Action" || true
git config --global user.email "action@github.com" || true

# Ensure docs folder exists
mkdir -p "$INPUT_DOCS_FOLDER"

## 1) Validate environment and inputs
bash "${GITHUB_ACTION_PATH:-.}/scripts/validator.sh"

## 1b) Cold start scaffolding (early, idempotent)
bash "${GITHUB_ACTION_PATH:-.}/scripts/cold-start-scaffold.sh" || true

## 2) Detect diffs (writes tmp/changed_files.txt and tmp/patch.diff)
bash "${GITHUB_ACTION_PATH:-.}/scripts/diff-detector.sh"

## Early exit unless full-repo mode is requested for cold start
INPUT_FORCE_FULL_REPO=${INPUT_FORCE_FULL_REPO:-false}
INPUT_FULL_REPO_WHEN_MISSING_DOCS=${INPUT_FULL_REPO_WHEN_MISSING_DOCS:-true}

docs_empty=true
if [[ -d "$INPUT_DOCS_FOLDER" ]]; then
  if find "$INPUT_DOCS_FOLDER" -type f -not -name '.*' -maxdepth 2 | read -r _; then
    docs_empty=false
  fi
fi

full_repo_mode=false
shopt -s nocasematch
if [[ "$INPUT_FORCE_FULL_REPO" == "true" ]]; then
  full_repo_mode=true
elif [[ "$INPUT_FULL_REPO_WHEN_MISSING_DOCS" == "true" && "$docs_empty" == true ]]; then
  full_repo_mode=true
fi
shopt -u nocasematch

# Always continue to prompt/doc-updater. If there are no diffs and not in full-repo mode,
# doc-updater will likely result in no changes; in full-repo cold start, it will scaffold.
if [[ ! -s tmp/changed_files.txt && "$full_repo_mode" != true ]]; then
  warn "No changed files detected; proceeding (may result in no-op)."
fi

## 3) Build prompt → tmp/prompt.md
PROMPT_FILE=$(mktemp)
BUILDER_PATH="${GITHUB_ACTION_PATH:-.}/scripts/prompt-builder.sh"
[[ -f "$BUILDER_PATH" ]] || BUILDER_PATH="./scripts/prompt-builder.sh"
bash "$BUILDER_PATH" > "$PROMPT_FILE"

## 4) Update docs via Codex write mode (sets tmp/have_changes.flag)
PROMPT_FILE="$PROMPT_FILE" bash "${GITHUB_ACTION_PATH:-.}/scripts/doc-updater.sh"

## 5) Publish PR if changes and event is push
bash "${GITHUB_ACTION_PATH:-.}/scripts/publisher.sh"

## 6) Post PR comment (on pull_request events)
if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
  bash "${GITHUB_ACTION_PATH:-.}/scripts/post-pr-comment.sh"
fi

log "Smart Doc completed (publish handled by publisher.sh)."
