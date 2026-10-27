#!/usr/bin/env bash
# Shared helpers for the Collie fork scripts. Source this file.

# Print the repository root.
collie_root() {
  git rev-parse --show-toplevel
}

# Print the ledger rows of FORK.md as: file<TAB>why<TAB>pr<TAB>status
# Skips the header, the separator and the "none yet" row.
# Argument 1: path to FORK.md.
collie_ledger_rows() {
  awk -F'|' '
    /^\|/ && NF >= 7 {
      for (i = 2; i <= 7; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i); gsub(/`/, "", $i) }
      if ($3 == "Upstream file" || $3 ~ /^-+$/ || $3 == "" || $3 == "none yet") next
      if ($2 == "Zone" || $2 ~ /^-+$/ && $3 ~ /^-+$/) next
      print $3 "\t" $4 "\t" $5 "\t" $6
    }
  ' "$1"
}

# Return 0 when a path is in the green zone (our own paths).
collie_is_green() {
  case "$1" in
    collie/*|FORK.md|.github/workflows/collie-fork-guard.yml) return 0 ;;
    *) return 1 ;;
  esac
}
