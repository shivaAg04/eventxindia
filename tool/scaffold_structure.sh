#!/usr/bin/env bash
# Scaffolds the Clean Architecture feature-first folder structure for EventXIndia.
# Each feature carries a domain/data/presentation triad. Empty leaf folders get a
# .gitkeep so the structure is visible and version-controlled before code lands.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)/lib"

FEATURES=(auth profile events applications attendance earnings reports admin notifications)

# Per-feature triad leaf folders
DOMAIN_DIRS=(entities repositories usecases)
DATA_DIRS=(datasources dtos mappers repositories)
PRESENTATION_DIRS=(bloc screens)

# Core / shared leaf folders
CORE_DIRS=(result error value_objects di)

for d in "${CORE_DIRS[@]}"; do
  mkdir -p "$ROOT/core/$d"
  touch "$ROOT/core/$d/.gitkeep"
done

for f in "${FEATURES[@]}"; do
  for d in "${DOMAIN_DIRS[@]}"; do
    mkdir -p "$ROOT/features/$f/domain/$d"
    touch "$ROOT/features/$f/domain/$d/.gitkeep"
  done
  for d in "${DATA_DIRS[@]}"; do
    mkdir -p "$ROOT/features/$f/data/$d"
    touch "$ROOT/features/$f/data/$d/.gitkeep"
  done
  for d in "${PRESENTATION_DIRS[@]}"; do
    mkdir -p "$ROOT/features/$f/presentation/$d"
    touch "$ROOT/features/$f/presentation/$d/.gitkeep"
  done
done

mkdir -p "$ROOT/routing"
touch "$ROOT/routing/.gitkeep"

echo "Scaffold complete."
