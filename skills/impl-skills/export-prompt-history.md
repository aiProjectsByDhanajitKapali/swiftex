---
name: export-prompt-history
description: >-
  Exports Cursor Composer/Agent user prompts from local agent-transcripts JSONL
  files to TSV or HTML after mandatory gates: date range (AskQuestion presets or
  chat) and output format (TSV vs HTML). Filter uses each transcript file's mtime.
  Use when the user asks to export prompt history, regenerate the export, filter
  by dates, or runs @export-prompt-history.
owner: Ram Sharma
disable-model-invocation: true
---

# Export prompt history (gated TSV or HTML)

## Gate 1 — date range (mandatory — block export)

Until **both** inclusive bounds are confirmed (`YYYY-MM-DD` start **and** end), **do not**:

- Run `export_prompt_history.py` or any shell that performs the export
- Create or overwrite report files (**`.tsv`** or **`.html`**)
- Paste a **concrete** runnable command with real `--start-date` / `--end-date` values (placeholders only until Gate 1 clears)

If the user explicitly approves **named defaults** you proposed (both dates stated), treat Gate 1 as cleared.

### Cursor UX — prefer AskQuestion when available

Use **`AskQuestion`** for the first interaction when dates are missing:

- Offer **preset ranges**, e.g. `Last 7 days`, `Last 30 days`, `Custom — I will type start/end in chat next`.
- When the user picks a preset, **you** derive inclusive `YYYY-MM-DD` start/end from **today’s calendar date** in the chosen timezone, then confirm once in prose before running.
- When the user picks **Custom**, ask **once** in chat for **start** and **end**: both `YYYY-MM-DD`.

**Timezone (optional):** After dates are known or preset-selected, either confirm **machine local** timezone or ask once for an **IANA** name (e.g. `Asia/Jakarta`). If omitted when running the script, use machine local.

If **`AskQuestion` is unavailable**, ask conversationally **once** for start date, end date, and optional timezone.

### Gate 1 already satisfied

If the user’s message already contains **both** bounds as `YYYY-MM-DD`, skip the date AskQuestion (still confirm timezone if ambiguous).

---

## Gate 2 — output format (mandatory — block export)

Until the user chooses **`tsv`** or **`html`**, **do not** run the exporter or write any report file.

### Cursor UX — prefer AskQuestion when available

Use **`AskQuestion`** with **exactly two options**:

- **TSV** — tab-separated; open in Sheets/Excel as UTF-8, tab-delimited.
- **HTML** — single `.html` file; open in a browser (sortable plain table, prompts escaped).

If **`AskQuestion` is unavailable**, ask conversationally: *“Export as TSV or HTML?”*

Pass **`--format tsv`** or **`--format html`** accordingly.

### Gate 2 already satisfied

If the user already stated **`TSV`** / **`tab`** / **`spreadsheet`** or **`HTML`** / **`browser`** / **`web`** in the same message **after** dates are known (or in one combined message), map to `--format tsv` or `--format html` and skip the format AskQuestion.

---

## What gets filtered

- **Included:** Transcript JSONL files whose **last modified time (`mtime`)** falls within `[start of start-date, end of end-date]` in the chosen timezone.
- **Excluded:** `/subagents/` paths under `agent-transcripts`.
- **Scope:** `agent-transcripts` under `~/.cursor/projects/<…>/` for this workspace (auto-discovered by workspace folder name unless overridden).

**Important:** This is **not** per-message sent time—only transcript file `mtime`.

## Run the exporter

From **repository root** (`MyIOSApp`). **Both gates must be cleared first.**

```bash
python3 .cursor/skills/documentation/export-prompt-history/scripts/export_prompt_history.py \
  --start-date YYYY-MM-DD \
  --end-date YYYY-MM-DD \
  --format tsv   # or: html
  [--timezone Region/City] \
  [--output path/to/custom.tsv|html]
```

Default output when `--output` is omitted:

- `--format tsv` → `.cursor/prompt-history-export_<START>_to_<END>.tsv`
- `--format html` → `.cursor/prompt-history-export_<START>_to_<END>.html`

If discovery fails (unusual project path), set:

```bash
export CURSOR_AGENT_TRANSCRIPTS_DIR="$HOME/.cursor/projects/Users-ramsharma-MyIOSApp/agent-transcripts"
```

or pass `--transcripts-dir` explicitly.

## After running

1. Report **`output=`**, **`format=`**, **`chats_in_range=`**, **`user_rows=`**, and **`transcripts_dir=`** from script stdout.
2. **TSV:** remind — open as **UTF-8**, **tab-delimited**.
3. **HTML:** remind — open file in a **browser**.
4. Offer to widen/narrow the date range or switch format if counts are wrong.

## Columns (same schema for TSV and HTML table)

`chat_rank_by_mtime`, `transcript_mtime_local`, `transcript_mtime_utc_iso`, `transcript_mtime_unix`, `chat_uuid`, `transcript_absolute_path`, `transcript_size_bytes`, `user_messages_in_chat`, `message_index_in_chat`, `user_prompt_char_count`, `user_prompt_text`
