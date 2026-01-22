# Kobo AI Companion (Hybrid Edition)

**Restoration Kit & Installation Guide**

This project turns your Kobo e-reader into a powerful AI assistant using a "Hybrid" approach to get the best of both worlds:

* **Text (Definitions/Summaries):** Uses **Google Gemini 2.5** (Fast, smart, free).
* **Images (Visualization):** Uses **Cloudflare Workers AI** (Stable Diffusion) to generate scenes.

## 📂 Project Structure

When installed, your Kobo file system should look like this:

```text
(KOBO ROOT DIRECTORY)
│
├── .kobo/
│   └── KoboRoot.tgz          <-- (Only needed once to install NickelMenu)
│
├── .adds/
│   ├── nm/
│   │   └── config            <-- (Menu configuration file)
│   │
│   └── scripts/
│       ├── curl              <-- (The binary file you downloaded, NO file extension)
│       ├── gemini.sh         <-- (The main logic script)
│       ├── diagnose.sh       <-- (Diagnostic tool)
│       ├── result.html       <-- (Generated automatically)
│       └── vis.png           <-- (Generated automatically)
│
└── (Your Books Folder)

```

## 🛠️ Prerequisites

1. **Kobo E-Reader** (Any model running recent firmware).
2. **NickelMenu** installed (v0.6.0+).
3. **Google Gemini API Key** (Free tier from [aistudio.google.com](https://aistudio.google.com/)).
4. **Cloudflare Account** (Free tier from [cloudflare.com](https://www.cloudflare.com/)).

## 🚀 Installation Instructions

### Step 1: Install NickelMenu

If not already installed:

1. Download `KoboRoot.tgz` from the [NickelMenu releases](https://github.com/pgaskin/NickelMenu/releases).
2. Connect Kobo to PC.
3. Place `KoboRoot.tgz` into the `.kobo` folder.
4. Eject and wait for reboot.

### Step 2: Install Curl

The built-in Kobo network tools are too weak for secure API calls.

1. Download `curl-armhf-linux-musl` from [moparisthebest/static-curl](https://github.com/moparisthebest/static-curl/releases).
2. Rename the file to `curl` (no extension).
3. Copy it to: `.adds/scripts/curl`

### Step 3: Setup Cloudflare Worker (For Images)

To get image generation working, you need to set up a free "Worker" on Cloudflare.

**📺 Video Reference:**
For a visual guide on setting up the Cloudflare environment, refer to **[Code With Nomi's Guide](https://www.youtube.com/watch?v=ZSHEL1EUQuE)**.

**📋 Setup Checklist:**

1. **Create Worker:** Go to Cloudflare Dashboard > Compute (Workers) > Create Application > "Hello World" script. Name it something like `kobo-art`.
2. **Add AI Binding:**

* Go to **Settings > Bindings**.
* Click **Add**.
* Choose **Workers AI**.
* Variable Name: `AI` (Must be uppercase).

3. **Add Secret Key:**

* Go to **Settings > Variables and Secrets**.
* Add a variable named `API_KEY`.
* Value: Create your own password (e.g., `MySuperSecretPassword123`). *You will need this later.*

4. **Paste the Code:**

* Click **Edit Code**.
* Delete the existing code and paste the **Worker Code** below. (This is optimized to accept the specific parameters sent by the Kobo).

**☁️ Cloudflare Worker Code:**

```javascript
export default {
  async fetch(request, env) {
    // 1. Security Check
    const token = request.headers.get("Authorization");
    if (token !== `Bearer ${env.API_KEY}`) {
      return new Response("Unauthorized", { status: 403 });
    }

    // 2. Get Input from Kobo
    // This allows the Kobo to specify width, height, and steps dynamically
    const inputs = await request.json();

    // 3. Run AI Model
    // We use SDXL Lightning for speed. You can also use '@cf/stabilityai/stable-diffusion-xl-base-1.0'
    const response = await env.AI.run(
      "@cf/bytedance/stable-diffusion-xl-lightning",
      inputs
    );

    // 4. Return Image
    return new Response(response, {
      headers: { "content-type": "image/png" },
    });
  },
};

```

5. **Deploy:** Click "Deploy". Copy your Worker URL (e.g., `https://kobo-art.yourname.workers.dev`).

### Step 4: The Script (`gemini.sh`)

Create a file named `gemini.sh` in `.adds/scripts/`. Paste the code below.
**IMPORTANT:** Fill in the Configuration section with your Google Key, Cloudflare URL, and Cloudflare Secret Key.

```bash
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

echo "<html><head><meta http-equiv='refresh' content='$REFRESH'>$CSS</head><body><h2>⏳ Processing</h2><p style='text-align:center;'>$MSG</p></body></html>" > $OUTPUT_HTML

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
```

### Step 5: Configure NickelMenu

Add these lines to `.adds/nm/config`:

```text
# 1. Explain
menu_item : selection : 🧠 Explain : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "explain" "{1||$}" "{m_title}" "{m_authors}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

# 2. Who is this?
menu_item : selection : 👤 Who is this? : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "lookup" "{1||$}" "{m_title}" "{m_authors}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

# 3. Visualize
menu_item : selection : 🖼️ Visualize : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/gemini.sh "visualize" "{1||$}" "{m_title}" "{m_authors}"
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html

# 4. Diagnostics
menu_item : selection : 🛠️ Diagnostics : cmd_spawn : quiet : /bin/sh /mnt/onboard/.adds/scripts/diagnose.sh
chain_success : nickel_browser : modal : file:///mnt/onboard/.adds/scripts/result.html


```

---

## ⚠️ Troubleshooting

* **Black/Incomplete Images:** The Kobo has limited RAM. The script uses `384x512` resolution to ensure stability. If images still fail, the script will automatically switch to a Text Description fallback.
* **Broken Image Icon:** This means the download failed or returned text (like an error message). The new script saves images to disk (`vis.png`) to solve Base64 display issues.
* **"Unauthorized":** Check that the `CF_API_KEY` in `gemini.sh` matches the `API_KEY` variable in your Cloudflare Worker settings.

---

## 🔧 Appendix: Diagnostic Tool

If the text features stop working, use this tool to ask Google specifically "What models can I use?"

### 1. Create `diagnose.sh`

Create a file at `.adds/scripts/diagnose.sh` and paste this code:

```bash
#!/bin/sh
# Location: /mnt/onboard/.adds/scripts/diagnose.sh

API_KEY="PASTE_GOOGLE_API_KEY_HERE"
OUTPUT_HTML="/mnt/onboard/.adds/scripts/result.html"
DEBUG_FILE="/tmp/diagnose_debug.txt"

CURL_BIN="/tmp/curl_kobo"
[ ! -f "$CURL_BIN" ] && cp "/mnt/onboard/.adds/scripts/curl" "$CURL_BIN" && chmod +x "$CURL_BIN"

CSS="<style>body{font-family:'Courier',monospace;font-size:16px;padding:20px;} h2{font-family:sans-serif;border-bottom:2px solid #000;} .model{margin-bottom:10px;padding:10px;background:#eee;border-left:5px solid #000;}</style>"

echo "<html><head>$CSS</head><body><h2>⏳ Querying Google...</h2><p>Checking API permissions...</p></body></html>" > $OUTPUT_HTML

"$CURL_BIN" -k -s -m 20 "[https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY](https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY)" > "$DEBUG_FILE"

if grep -q "\"name\":" "$DEBUG_FILE"; then
    MODELS_FOUND=$(grep -o '"name": "models/[^"]*' "$DEBUG_FILE" | sed 's/"name": "models\///')
    HTML_LIST=""; for m in $MODELS_FOUND; do HTML_LIST="$HTML_LIST <div class='model'>$m</div>"; done
    echo "<html><head>$CSS</head><body><h2>✅ Success</h2><p>Key active. Available models:</p>$HTML_LIST</body></html>" > $OUTPUT_HTML
else
    ERROR_MSG=$(cat "$DEBUG_FILE")
    echo "<html><head>$CSS</head><body><h2>⚠️ Failed</h2><pre>$ERROR_MSG</pre></body></html>" > $OUTPUT_HTML
fi

```
