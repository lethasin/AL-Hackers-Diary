#!/usr/bin/env bash

set -uo pipefail

# ---- Colors ----
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RESET="\e[0m"

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Usage: $0 domain.com | domains.txt${RESET}"
  exit 1
fi

INPUT="$1"
TMPBASE="$(mktemp -d)"
trap 'rm -rf "$TMPBASE"' EXIT

DOMAIN_TIMEOUT=60   # max seconds per domain

safe_count() {
  [[ -f "$1" ]] && wc -l < "$1" | tr -d ' ' || echo 0
}

clean_output() {
  sed -E '
    s~https?://~~g;
    s~^www\.~~g;
    s~[,/\\:;]+$~~g;
  ' \
  | tr '[:upper:]' '[:lower:]' \
  | grep -E '^([a-z0-9-]+\.)+[a-z]{2,}$' \
  | sort -u
}

# ---------- Tool functions ----------
run_tool_parallel() {
  local name="$1"
  local cmd="$2"
  local outfile="$3"

  echo -e "${BLUE}[*] $name started${RESET}"
  eval "$cmd" > "$outfile" 2>/dev/null &
  echo $!   # PID
}

wait_tool() {
  local name="$1"
  local pid="$2"
  local outfile="$3"

  wait "$pid"
  echo -e "${GREEN}[*] $name finished ($(safe_count "$outfile") results)${RESET}"
}

run_tool_sequential() {
  local name="$1"
  local cmd="$2"
  local outfile="$3"

  echo -e "${BLUE}[*] $name started${RESET}"
  eval "$cmd" > "$outfile" 2>/dev/null || true
  echo -e "${GREEN}[*] $name finished ($(safe_count "$outfile") results)${RESET}"
}

# ---------- Domain enumeration ----------
enum_domain() {
  local domain="$1"
  local outdir="$2"
  local tmpdir="$TMPBASE/$domain"

  mkdir -p "$tmpdir"
  echo -e "${YELLOW}[*] enumeration started for $domain (max ${DOMAIN_TIMEOUT}s)${RESET}"

  SECONDS=0

  declare -A pids

  # --- Heavy tools parallel ---
  pids[sublist3r]=$(run_tool_parallel "sublist3r" "sublist3r -d $domain -o $tmpdir/sublist3r.txt" "$tmpdir/sublist3r.txt")
  pids[subfinder]=$(run_tool_parallel "subfinder" "subfinder -silent -d $domain -o $tmpdir/subfinder.txt" "$tmpdir/subfinder.txt")

  # --- Lightweight tools sequential ---
  run_tool_sequential "findomain" "findomain -t $domain -q -o $tmpdir/findomain.txt" "$tmpdir/findomain.txt"
  run_tool_sequential "assetfinder" "assetfinder --subs-only $domain > $tmpdir/assetfinder.txt" "$tmpdir/assetfinder.txt"
  run_tool_sequential "crtsh" "curl -s 'https://crt.sh/?q=%25.$domain&output=json' | jq -r '.[].name_value' > $tmpdir/crtsh.txt" "$tmpdir/crtsh.txt"
  run_tool_sequential "waybackurls" "echo $domain | waybackurls > $tmpdir/waybackurls.txt" "$tmpdir/waybackurls.txt"

  # --- Wait heavy tools with domain timeout ---
  for t in sublist3r subfinder; do
    pid=${pids[$t]}
    outfile="$tmpdir/$t.txt"

    while kill -0 "$pid" 2>/dev/null; do
      now=$(date +%s)
      (( now - SECONDS >= DOMAIN_TIMEOUT )) && {
        echo -e "${RED}[!] $t killed due to domain timeout${RESET}"
        kill -9 "$pid" 2>/dev/null
        break
      }
      sleep 0.5
    done
    wait_tool "$t" "$pid" "$outfile"
  done

  # --- Merge + clean ---
  cat "$tmpdir"/*.txt 2>/dev/null | clean_output > "$outdir/sub.$domain.txt"
  final_count=$(safe_count "$outdir/sub.$domain.txt")
  echo -e "${YELLOW}[*] completed $domain ($final_count unique subdomains)${RESET}"
}

### MAIN ###
if [[ -f "$INPUT" ]]; then
  OUTDIR="passive_enum"
  mkdir -p "$OUTDIR"
  ALL="$OUTDIR/all_subdomains.txt"
  : > "$ALL"

  while read -r domain; do
    [[ -z "$domain" ]] && continue
    enum_domain "$domain" "$OUTDIR"
  done < "$INPUT"

  cat "$OUTDIR"/sub.*.txt | sort -u > "$ALL"
  echo -e "${YELLOW}[*] all domains done ($(wc -l < "$ALL") total unique subdomains)${RESET}"

else
  enum_domain "$INPUT" "."
fi
