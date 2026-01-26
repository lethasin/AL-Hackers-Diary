#!/bin/bash
# ==================================================
# PASSIVE SUBDOMAIN ENUMERATION – FAST & PARALLEL
# ==================================================

BASE_OUT="passive_enum_results"

# -------- TIMEOUTS (seconds) --------
T_SUBFINDER=50
T_AMASS=15 #can be incresed if amass is working well on system
T_ASSETFINDER=50
T_SUBLIST3R=45
T_CRTSH=30
T_FINDOMAIN=30
T_WAYBACK=50
# -----------------------------------

if [ -z "$1" ]; then
    echo "Usage:"
    echo "  $0 example.com"
    echo "  $0 domains.txt"
    exit 1
fi

INPUT="$1"
mkdir -p "$BASE_OUT"

clean_output() {
    sed -E '
        s~https?://~~g;
        s~^www\.~~g;
        s~/.*$~~g;
        s~\*$~~g
    '
}

run_tool() {
    TOOL="$1"
    CMD="$2"
    OUTFILE="$3"
    TIME="$4"

    echo "[*] Running $TOOL ..."
    if timeout "$TIME" bash -c "$CMD" > "$OUTFILE" 2>/dev/null; then
        echo "[✔] $TOOL completed ($(wc -l < "$OUTFILE") results)"
    else
        echo "[!] $TOOL skipped (timeout/error)"
    fi
}

run_enum() {
    DOMAIN="$1"
    OUT="$BASE_OUT/$DOMAIN"
    mkdir -p "$OUT"

    echo
    echo "====================================="
    echo "[*] Target: $DOMAIN"
    echo "====================================="

    # -------- PARALLEL EXECUTION --------
    run_tool "subfinder" \
        "subfinder -d $DOMAIN -silent" \
        "$OUT/subfinder.txt" "$T_SUBFINDER" &

    run_tool "amass" \
        "amass enum -passive -d $DOMAIN" \
        "$OUT/amass.txt" "$T_AMASS" &

    run_tool "assetfinder" \
        "assetfinder -subs-only $DOMAIN" \
        "$OUT/assetfinder.txt" "$T_ASSETFINDER" &

    run_tool "sublist3r" \
        "sublist3r -d $DOMAIN -n -t 50" \
        "$OUT/sublist3r.txt" "$T_SUBLIST3R" &

    run_tool "crt.sh" \
        "curl -s 'https://crt.sh/?q=%25.$DOMAIN&output=json' | jq -r '.[].name_value' | sed 's/\*\.//g'" \
        "$OUT/crtsh.txt" "$T_CRTSH" &

    run_tool "findomain" \
        "findomain -t $DOMAIN -q" \
        "$OUT/findomain.txt" "$T_FINDOMAIN" &

    run_tool "waybackurls" \
        "echo $DOMAIN | waybackurls" \
        "$OUT/wayback.txt" "$T_WAYBACK" &

    wait
    echo "[✔] All tools finished"

    # -------- MERGE + CLEAN --------
    cat "$OUT"/*.txt 2>/dev/null \
        | clean_output \
        | grep -F ".$DOMAIN" \
        | sort -u > "$OUT/final.txt"

    FINAL_COUNT=$(wc -l < "$OUT/final.txt")

    echo "-------------------------------------"
    echo "[+] FINAL UNIQUE SUBDOMAINS: $FINAL_COUNT"
    echo "[📁] Output: $OUT/final.txt"
}

# -------- INPUT HANDLING --------
if [ -f "$INPUT" ]; then
    while read -r DOMAIN; do
        [[ -z "$DOMAIN" || "$DOMAIN" =~ ^# ]] && continue
        run_enum "$DOMAIN"
    done < "$INPUT"
else
    run_enum "$INPUT"
fi

echo
echo "====================================="
echo "[✔] Enumeration Completed"
echo "====================================="
