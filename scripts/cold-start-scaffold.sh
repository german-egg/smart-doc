#!/usr/bin/env bash
# Smart Doc — Cold Start Scaffolder
# Responsibility:
#  - Create an initial documentation set under docs/ when running in cold start.
#  - Idempotent: only writes when docs/ is effectively empty (no non-hidden files).
# Inputs via env:
#  - INPUT_DOCS_FOLDER (default: docs)
#  - INPUT_FORCE_FULL_REPO (true|false)
#  - INPUT_FULL_REPO_WHEN_MISSING_DOCS (true|false)
set -euo pipefail

log() { echo "🌱 [scaffold] $*"; }

INPUT_DOCS_FOLDER=${INPUT_DOCS_FOLDER:-docs}
INPUT_FORCE_FULL_REPO=${INPUT_FORCE_FULL_REPO:-false}
INPUT_FULL_REPO_WHEN_MISSING_DOCS=${INPUT_FULL_REPO_WHEN_MISSING_DOCS:-true}

mkdir -p "$INPUT_DOCS_FOLDER"

docs_empty=true
if find "$INPUT_DOCS_FOLDER" -type f -not -name '.*' -maxdepth 2 | read -r _; then
  docs_empty=false
fi

should_scaffold=false
shopt -s nocasematch
if [[ "$INPUT_FORCE_FULL_REPO" == "true" ]]; then
  should_scaffold=true
elif [[ "$INPUT_FULL_REPO_WHEN_MISSING_DOCS" == "true" && "$docs_empty" == true ]]; then
  should_scaffold=true
fi
shopt -u nocasematch

if [[ "$should_scaffold" != true || "$docs_empty" != true ]]; then
  exit 0
fi

log "Cold start detected. Generating initial docs in $INPUT_DOCS_FOLDER."
mkdir -p "$INPUT_DOCS_FOLDER/architecture" "$INPUT_DOCS_FOLDER/modules"

cat > "$INPUT_DOCS_FOLDER/README.md" << 'EOF'
# Project Documentation

## Overview
Smart Doc is enabled. This is an initial scaffold created on cold start; future runs will refine it.

## Contents
- Stack, Architecture, Endpoints, Modules.
EOF

cat > "$INPUT_DOCS_FOLDER/stack.md" << 'EOF'
# Stack

## Key Packages
## Commands
## Environments
EOF

cat > "$INPUT_DOCS_FOLDER/architecture/overview.md" << 'EOF'
# Architecture Overview

## Goals
## Components
## Main Flow
EOF

cat > "$INPUT_DOCS_FOLDER/architecture/diagram.md" << 'EOF'
# Architecture Diagram

```mermaid
flowchart LR
  Client --> API
  API --> Queue
  API --> DB
```
EOF

cat > "$INPUT_DOCS_FOLDER/endpoints.md" << 'EOF'
# Endpoints

- GET /health
EOF

log "Scaffold completed."
