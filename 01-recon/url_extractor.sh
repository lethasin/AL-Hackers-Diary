#!/bin/bash
# Save as url_extractor.sh
# chmod +x url_extractor.sh

echo -e "\nUse this way to save output to a file: \n\turl_extractor.sh <html_file> >> output.txt\n"

# check argument
if [ $# -ne 1 ]; then
  echo "Usage: url_extractor <html_file>"
  exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
  echo "Error: File not found -> $FILE"
  exit 1
fi

# Ask for allowed TLDs
read -r -p "Enter allowed TLDs (comma-separated, e.g. in,gov.in,nic.in,com,org): " TLDS
TLD_REGEX=$(echo "$TLDS" | sed 's/,/|/g')

# Ask for keyword
read -r -p "Enter keyword to search in domains (leave empty if none): " KEYWORD

# Extract domains
grep -oE '(http|https)://[^"< >]+|www\.[^"< >]+' "$FILE" \
| sed -E 's#^(http://|https://)##' \
| sed -E 's/^www\.//' \
| sed -E 's#[\\/].*##' \
| sed -E 's/[[:punct:]]+$//' \
| grep -Ei "\.($TLD_REGEX)$|$KEYWORD" \
| sort -u
