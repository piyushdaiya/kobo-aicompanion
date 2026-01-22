#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/gemini.sh

ACTION=$1
TEXT=$2
BOOK_TITLE=$3
BOOK_AUTHOR=$4

SCRIPT_DIR="/mnt/onboard/.adds/scripts"
OUTPUT_HTML="$SCRIPT_DIR/result.html"
IMG_FILE="$SCRIPT_DIR/vis.png"
DEBUG_FILE="/tmp/gemini_debug.txt"

# ================= CONFIGURATION =================
GEMINI_API_KEY="PASTE_GOOGLE_API_KEY_HERE"
CF_WORKER_URL="https://your-worker-name.your-subdomain.workers.dev"
CF_API_KEY="PASTE_CLOUDFLARE_SECRET_KEY_HERE"
# =================================================

CURL_BIN="/tmp/curl_kobo"
[ ! -f "$CURL_BIN" ] && cp "$SCRIPT_DIR/curl" "$CURL_BIN" && chmod +x "$CURL_BIN"

CSS="<style>
body { font-family: 'Georgia', serif; font-size: 32px; padding: 20px; margin: 0; }
h2 { font-family: sans-serif; border-bottom: 2px solid #000; text-align: center; margin-bottom: 10px; }
img { width: 100%; height: auto; display: block; margin: 10px auto; border: 2px solid #333; }
.meta { font-size: 14px; color: #666; text-align: center; margin-top: 5px; font-style: italic; }
.visual-text { font-style: italic; color: #333; border-left: 4px solid #555; padding-left: 20px; margin-top: 20px; font-size: 30px; }
</style>"

RAND=$(date +%s)

# --- LOADING SCREEN ---
if [ "$ACTION" = "visualize" ]; then
    MSG="Rendering Image..."
    REFRESH="7"
elif [ "$ACTION" = "lookup" ]; then
    MSG="Scanning Book Context..."
    REFRESH="3"
else
    MSG="Defining Term..."
    REFRESH="2"
fi

echo "<html><head><meta http-equiv='refresh' content='$REFRESH'>$CSS</head><body><h2>Processing</h2><p style='text-align:center;'>$MSG</p></body></html>" > $OUTPUT_HTML

(
    CLEAN_TEXT=$(echo "$TEXT" | tr -d '\n\r' | sed 's/"/\\"/g')
    "$CURL_BIN" -k -s -m 2 "https://www.google.com" > /dev/null

    # --- TEXT GENERATION ---
    generate_text() {
        TYPE=$1
        
        if [ "$TYPE" = "explain" ]; then
            PROMPT="Provide a simple, 2-sentence explanation for the term: $CLEAN_TEXT"
            TITLE="Explanation"
            
        elif [ "$TYPE" = "lookup" ]; then
            # --- SPOILER SAFE LOGIC ---
            # We strictly instruct the model that we are reading the book right now.
            PROMPT="I am currently reading '$BOOK_TITLE' by $BOOK_AUTHOR. I have NOT finished the book. Identify the character or term '$CLEAN_TEXT'. STRICTLY avoid spoilers, endings, or future plot twists. Only describe them as they are introduced."
            TITLE="Who is this?"
            
        elif [ "$TYPE" = "fallback" ]; then
            PROMPT="You are an artist. Describe '$CLEAN_TEXT' in vivid sensory detail. Under 50 words."
            TITLE="Visual Description"
        fi
        
        MODEL="gemini-2.5-flash:generateContent"
        URL="https://generativelanguage.googleapis.com/v1beta/models/$MODEL?key=$GEMINI_API_KEY"
        PAYLOAD="{\"contents\":[{\"parts\":[{\"text\":\"$PROMPT\"}]}]}"
        
        "$CURL_BIN" -k -s -m 15 -H 'Content-Type: application/json' -d "$PAYLOAD" "$URL" > "$DEBUG_FILE"
        
        # --- ROBUST JSON PARSER ---
        if grep -q "\"text\":" "$DEBUG_FILE"; then
            # 1. Protect escaped quotes (\") by renaming them to %QUOT%
            # 2. Extract the text field
            # 3. Restore quotes and newlines
            TXT=$(cat "$DEBUG_FILE" | tr '\n' ' ' | sed 's/\\"/%QUOT%/g' | sed 's/.*"text": "//' | sed 's/".*//' | sed 's/%QUOT%/"/g' | sed 's/\\n/<br>/g')

            if [ "$TYPE" = "fallback" ]; then
                 echo "<html><head>$CSS</head><body><h2>$TITLE</h2><div class='visual-text'>$TXT</div><div class='meta'>Switched to text mode.</div></body></html>" > $OUTPUT_HTML
            else
                 echo "<html><head>$CSS</head><body><h2>$TITLE</h2><p>$TXT</p></body></html>" > $OUTPUT_HTML
            fi
        else
            ERR=$(cat "$DEBUG_FILE" | head -c 200)
            echo "<html><head>$CSS</head><body><h2>⚠️ Error</h2><p>Response Error:</p><pre>$ERR</pre></body></html>" > $OUTPUT_HTML
        fi
    }

    # --- MAIN ROUTER ---
    if [ "$ACTION" = "visualize" ]; then
        PROMPT="Simple minimalist line art of $CLEAN_TEXT, black ink on white background, high contrast, no shading, clean lines."
        JSON_DATA="{ \"prompt\": \"$PROMPT\", \"width\": 384, \"height\": 512, \"num_inference_steps\": 20, \"guidance_scale\": 7, \"scheduler\": \"DPM++ 2M Karras\" }"
        
        "$CURL_BIN" -k -s -m 30 -X POST "$CF_WORKER_URL" \
            -H "Authorization: Bearer $CF_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$JSON_DATA" \
            -o "$IMG_FILE"

        if [ -s "$IMG_FILE" ]; then
            FIRST=$(head -c 1 "$IMG_FILE")
            if [ "$FIRST" = "{" ] || [ "$FIRST" = "<" ]; then
                generate_text "fallback"
            else
                echo "<html><head>$CSS</head><body><h2>Visualization</h2><img src='vis.png?v=$RAND'><div class='meta'>Optimized 384x512</div></body></html>" > $OUTPUT_HTML
            fi
        else
            generate_text "fallback"
        fi
        
    else
        generate_text "$ACTION"
    fi
) &

exit 0