# Kobo AI Companion (Gemini 2.5)

**Restoration Kit & Installation Guide**

This project enhances a Kobo e-reader with on-demand AI intelligence. It allows you to highlight text while reading and instantly get definitions, character summaries, or vivid scene visualizations without leaving the page.

## 📂 Project Structure

When installed, your Kobo file system should look like this:

```text
(KOBO ROOT DIRECTORY)
│
├── .kobo/
│   └── KoboRoot.tgz          <-- (Only needed once to install NickelMenu, then it disappears)
│
├── .adds/
│   ├── nm/
│   │   └── config            <-- (The text file where you added the menu_item lines)
│   │
│   └── scripts/
│       ├── curl              <-- (The binary file you downloaded, NO file extension)
│       ├── gemini.sh         <-- (The main script, code provided below)
│       ├── diagnose.sh       <-- (The fix-it tool, code provided below)
│       └── result.html       <-- (Generated automatically; you don't need to create this)
│
└── (Your Books Folder)

```

## 🛠️ Prerequisites

1. **Kobo E-Reader** (Any model running recent firmware).
2. **NickelMenu** installed (v0.6.0+).
3. **Google Gemini API Key** (Free tier from [aistudio.google.com](https://aistudio.google.com/)).
4. **Static Curl Binary** (downloaded from `static-curl` repo).

---

## 🚀 Installation Instructions

### Step 1: Install NickelMenu

If not already installed:

1. Download `KoboRoot.tgz` from the [NickelMenu releases](https://github.com/pgaskin/NickelMenu/releases).
2. Connect Kobo to PC.
3. Place `KoboRoot.tgz` into the `.kobo` folder.
4. Eject and wait for reboot.

### Step 2: Install Curl

The built-in Kobo network tools are too weak for secure API calls. We use a standalone `curl` binary.

1. Download `curl-armhf-linux-musl` from [moparisthebest/static-curl](https://github.com/moparisthebest/static-curl/releases).
2. Rename the file to `curl` (no extension).
3. Copy it to: `.adds/scripts/curl`

### Step 3: The Script (`gemini.sh`)

Create a file named `gemini.sh` in `.adds/scripts/`. Paste the code below. **IMPORTANT:** Replace `PASTE_YOUR_API_KEY_HERE` with your actual key.

```bash
#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/gemini.sh

ACTION=$1
TEXT=$2
API_KEY="PASTE_YOUR_API_KEY_HERE"
OUTPUT_HTML="/mnt/onboard/.adds/scripts/result.html"
DEBUG_FILE="/tmp/gemini_debug.txt"

# --- 1. SETUP CURL ---
CURL_SOURCE="/mnt/onboard/.adds/scripts/curl"
CURL_BIN="/tmp/curl_kobo"

if [ ! -f "$CURL_BIN" ]; then
    cp "$CURL_SOURCE" "$CURL_BIN"
    chmod +x "$CURL_BIN"
fi

# --- 2. CSS STYLING ---
CSS="<style>
body { font-family: 'Georgia', serif; font-size: 32px; line-height: 1.4em; background-color: #FFF; color: #000; padding: 30px; margin: 0; }
h2 { font-family: 'Avenir Next', sans-serif; font-size: 38px; text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; }
.visual-text { font-style: italic; color: #333; border-left: 4px solid #555; padding-left: 20px; margin-top: 20px; font-size: 30px; }
pre { font-size: 16px; background: #eee; padding: 10px; border: 1px solid #999; white-space: pre-wrap; }
</style>"

# --- 3. LOADING SCREEN ---
echo "<html><head><meta http-equiv='refresh' content='2'>$CSS</head><body><h2>⏳ Consulting Gemini...</h2><p style='text-align:center;'>Accessing Gemini 2.5...</p></body></html>" > $OUTPUT_HTML

# --- 4. BACKGROUND PROCESS ---
(
    CLEAN_TEXT=$(echo "$TEXT" | tr -d '\n\r' | sed 's/"/\\"/g')

    # --- DEFINE PROMPTS ---
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

    # --- MODEL CONFIGURATION (v1beta / Gemini 2.5) ---
    MODEL="gemini-2.5-flash:generateContent"
    URL="[https://generativelanguage.googleapis.com/v1beta/models/$MODEL?key=$API_KEY](https://generativelanguage.googleapis.com/v1beta/models/$MODEL?key=$API_KEY)"
    PAYLOAD="{\"contents\":[{\"parts\":[{\"text\":\"$PROMPT\"}]}]}"

    # --- EXECUTE REQUEST ---
    "$CURL_BIN" -k -s -m 15 -H 'Content-Type: application/json' -d "$PAYLOAD" "$URL" > "$DEBUG_FILE"

    # --- PROCESS RESULT ---
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

```

### Step 4: Configure NickelMenu

Add these lines to `.adds/nm/config`:

```text
# --- GEMINI INTEGRATION ---
menu_item : selection : 🧠 Explain : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "explain" "{1||$}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

menu_item : selection : 👤 Who is this? : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "lookup" "{1||$}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

menu_item : selection : 🖼️ Visualize : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "visualize" "{1||$}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

```

---

## 🎮 How to Use

1. Connect your Kobo to Wi-Fi.
2. Open a book.
3. Long-press a word or phrase to select it.
4. Tap **🧠 Explain**, **👤 Who is this?**, or **🖼️ Visualize** in the menu.
5. Wait a few seconds for the pop-up modal.
6. Close the window to resume reading.

## ⚠️ Troubleshooting

* **"Request Failed / Curl returned empty"**: Check your Wi-Fi connection. Kobo drops Wi-Fi to save battery; ensure the icon is active before searching.
* **"Model not found"**: Google may have updated API names. Check `gemini.sh` and ensure `gemini-2.5-flash` is still the current model name.
* **Stuck on Loading Screen**: The script might have crashed. Reboot the Kobo to clear the `/tmp` RAM folder.

---

## 🔧 Appendix: Diagnostic Tool

If the scripts ever stop working, use this tool to ask Google specifically "What models can I use?" This helps verify if your API Key is active or if model names have changed.

### 1. Create `diagnose.sh`

Create a file at `.adds/scripts/diagnose.sh` and paste this code:

```bash
#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/diagnose.sh

API_KEY="PASTE_YOUR_API_KEY_HERE"
OUTPUT_HTML="/mnt/onboard/.adds/scripts/result.html"
DEBUG_FILE="/tmp/diagnose_debug.txt"

# --- SETUP CURL ---
CURL_SOURCE="/mnt/onboard/.adds/scripts/curl"
CURL_BIN="/tmp/curl_kobo"
if [ ! -f "$CURL_BIN" ]; then
    cp "$CURL_SOURCE" "$CURL_BIN"
    chmod +x "$CURL_BIN"
fi

# --- CSS ---
CSS="<style>body{font-family:'Courier',monospace;font-size:16px;padding:20px;} h2{font-family:sans-serif;border-bottom:2px solid #000;} .model{margin-bottom:10px;padding:10px;background:#eee;border-left:5px solid #000;}</style>"

# --- LOADING ---
echo "<html><head>$CSS</head><body><h2>⏳ Querying Google...</h2><p>Checking API permissions...</p></body></html>" > $OUTPUT_HTML

# --- FETCH MODELS ---
# queries the API for a list of all available models
"$CURL_BIN" -k -s -m 20 "[https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY](https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY)" > "$DEBUG_FILE"

# --- PARSE RESULTS ---
if grep -q "\"name\":" "$DEBUG_FILE"; then
    # Filter for 'gemini' or 'imagen' models
    MODELS_FOUND=$(grep -o '"name": "models/[^"]*' "$DEBUG_FILE" | sed 's/"name": "models\///')
    
    HTML_LIST=""
    for m in $MODELS_FOUND; do
        HTML_LIST="$HTML_LIST <div class='model'>$m</div>"
    done
    
    echo "<html><head>$CSS</head><body><h2>✅ Success</h2><p>Your Key is active. Available models:</p>$HTML_LIST</body></html>" > $OUTPUT_HTML
else
    # FAILURE
    ERROR_MSG=$(cat "$DEBUG_FILE")
    if [ -z "$ERROR_MSG" ]; then ERROR_MSG="Connection failed. Check Wi-Fi."; fi
    echo "<html><head>$CSS</head><body><h2>⚠️ Connection Failed</h2><p>Could not reach Google.</p><pre>$ERROR_MSG</pre></body></html>" > $OUTPUT_HTML
fi

```

### 2. Add to NickelMenu

Add this line to your `.adds/nm/config` file to create a "Tools" button:

```text
menu_item : selection : 🛠️ Diagnostics : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/diagnose.sh
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

```

```

```