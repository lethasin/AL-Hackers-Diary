# Passive Recon

  ## Manual Subdomain Enumeration
  - Dorking
    - Search Engines
      - Google
      - DuckDuckGo
      - Bing
    - Dorks
      - site:*domain
      - site:*.domain
      - inurl:*domain
      - inurl:domain -site:www.domain
    - Auto-Extraction from google search (Linux friendly)
      - Search using dorks
      - Save the source code of page by Ctrl+S in a file
      - Run this [Bash Script](url_extractor.sh)

  
## Automated Subdomain Enumeration

  - [Own Toolkit](mysubenum.sh)
  - [Subenum](https://github.com/bing0o/SubEnum/)
  - Sublist3r {available on kali linux}
    - sublist3r -d domain -o <output_file>
  
