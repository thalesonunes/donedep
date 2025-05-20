#!/bin/bash

# Test script to verify Java version extraction for problematic projects
# Author: Thales Nunes

echo "Testing Java version extraction for problematic projects..."

# Load the version extractor module
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/scripts/modules/version_extractor.sh"

# Define projects to test
PROJECTS=(
  "batseguro"
  "card-tokenization-service"
  "payment-stream"
)

echo "Results:"
echo "-------------------------"

# Test each project
for project in "${PROJECTS[@]}"; do
  project_path="$SCRIPT_DIR/data/repo_cache/$project"
  if [ -d "$project_path" ]; then
    java_version=$(extract_java_version "$project_path")
    echo "$project: Java version detected = $java_version"
  else
    echo "$project: Directory not found"
  fi
done

echo "-------------------------"
echo "Test completed!"
