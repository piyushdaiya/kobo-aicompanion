#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/diagnose.sh

API_KEY="PASTE_YOUR_API_KEY_HERE"
OUTPUT_HTML="/mnt/onboard/.adds/scripts/result.html"
DEBUG_FILE="/tmp/diagnose_debug.txt"

CURL_SOURCE="/mnt/onboard/.adds/scripts/curl"
CURL_BIN="/tmp/curl_kobo"
if [ ! -f "$CURL_BIN" ]; then cp "$CURL_SOURCE" "$CURL_BIN"; chmod +x "$CURL_BIN"; fi

CSS="<style>body{font-family:'Courier',monospace;font-size:16px;padding:20px;} h2{font-family:sans-serif;border-bottom:2px solid #000;} .model{margin-bottom:10px;padding:10px;background:#eee;border-left:5px solid #000;}</style>"

echo "<html><head>$CSS</head><body><h2>⏳ Querying Google...</h2><p>Checking API permissions...</p></body></html>" > $OUTPUT_HTML

"$CURL_BIN" -k -s -m 20 "https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY" > "$DEBUG_FILE"

if grep -q "\"name\":" "$DEBUG_FILE"; then
    MODELS_FOUND=$(grep -o '"name": "models/[^"]*' "$DEBUG_FILE" | sed 's/"name": "models\///')
    HTML_LIST=""; for m in $MODELS_FOUND; do HTML_LIST="$HTML_LIST <div class='model'>$m</div>"; done
    echo "<html><head>$CSS</head><body><h2>✅ Success</h2><p>Your Key is active. Available models:</p>$HTML_LIST</body></html>" > $OUTPUT_HTML
else
    ERROR_MSG=$(cat "$DEBUG_FILE")
    if [ -z "$ERROR_MSG" ]; then ERROR_MSG="Connection failed. Check Wi-Fi."; fi
    echo "<html><head>$CSS</head><body><h2>⚠️ Connection Failed</h2><p>Could not reach Google.</p><pre>$ERROR_MSG</pre></body></html>" > $OUTPUT_HTML
fi