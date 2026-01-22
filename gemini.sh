#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/gemini.sh

ACTION=$1
TEXT=$2
API_KEY="PASTE_YOUR_API_KEY_HERE"
OUTPUT_HTML="/mnt/onboard/.adds/scripts/result.html"
DEBUG_FILE="/tmp/gemini_debug.txt"

# --- SETUP CURL ---
CURL_SOURCE="/mnt/onboard/.adds/scripts/curl"
CURL_BIN="/tmp/curl_kobo"
if [ ! -f "$CURL_BIN" ]; then
    cp "$CURL_SOURCE" "$CURL_BIN"
    chmod +x "$CURL_BIN"
fi

# --- CSS ---
CSS="<style>
body { font-family: 'Georgia', serif; font-size: 32px; line-height: 1.4em; background-color: #FFF; color: #000; padding: 30px; margin: 0; }
h2 { font-family: 'Avenir Next', sans-serif; font-size: 38px; text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; }
.visual-text { font-style: italic; color: #333; border-left: 4px solid #555; padding-left: 20px; margin-top: 20px; font-size: 30px; }
pre { font-size: 16px; background: #eee; padding: 10px; border: 1px solid #999; white-space: pre-wrap; }
</style>"

# --- LOADING ---
echo "<html><head><meta http-equiv='refresh' content='2'>$CSS</head><body><h2>⏳ Consulting Gemini...</h2><p style='text-align:center;'>Accessing Gemini 2.5...</p></body></html>" > $OUTPUT_HTML

# --- BACKGROUND PROCESS ---
(
    CLEAN_TEXT=$(echo "$TEXT" | tr -d '\n\r' | sed 's/"/\\"/g')

    if [ "$ACTION" = "explain" ]; then
        TITLE="Explanation"
        PROMPT="Provide a simple, 2-sentence explanation for the term: $CLEAN_TEXT"
    elif [ "$ACTION" = "lookup" ]; then
        TITLE="Who is this?"
        PROMPT="Identify this character or person and provide a brief 3-sentence summary of who they are: $CLEAN_TEXT"
    elif [ "$ACTION" = "visualize" ]; then
        TITLE="Visual Description"
        PROMPT="You are a master artist. Do not explain what '$CLEAN_TEXT' is. Instead, describe its physical appearance in vivid, sensory detail (colors, textures, lighting) as if painting a picture. Keep it under 50 words."
    fi

    # 2026 Model Standard
    MODEL="gemini-2.5-flash:generateContent"
    URL="https://generativelanguage.googleapis.com/v1beta/models/$MODEL?key=$API_KEY"
    PAYLOAD="{\"contents\":[{\"parts\":[{\"text\":\"$PROMPT\"}]}]}"

    "$CURL_BIN" -k -s -m 15 -H 'Content-Type: application/json' -d "$PAYLOAD" "$URL" > "$DEBUG_FILE"

    if grep -q "\"text\":" "$DEBUG_FILE"; then
        TEXT_RESULT=$(grep -o '"text": "[^"]*' "$DEBUG_FILE" | sed 's/"text": "//' | sed 's/\\n/<br>/g')
        if [ "$ACTION" = "visualize" ]; then
            echo "<html><head>$CSS</head><body><h2>$TITLE</h2><div class='visual-text'>$TEXT_RESULT</div></body></html>" > $OUTPUT_HTML
        else
            echo "<html><head>$CSS</head><body><h2>$TITLE</h2><p>$TEXT_RESULT</p></body></html>" > $OUTPUT_HTML
        fi
    else
        ERROR_MSG=$(cat "$DEBUG_FILE")
        if [ -z "$ERROR_MSG" ]; then ERROR_MSG="Curl returned empty. Check API Key or Wi-Fi."; fi
        echo "<html><head>$CSS</head><body><h2>⚠️ Request Failed</h2><p>Could not connect.</p><h3>Debug Log:</h3><pre>$ERROR_MSG</pre></body></html>" > $OUTPUT_HTML
    fi
) &
exit 0