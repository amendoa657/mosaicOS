#!/usr/bin/env python3
"""Mosaic OS: Claude Code's hooks (~/.claude/settings.json) on the island.

  island.py done   Stop: "Claude terminou · <project>" with the start of its last reply
  island.py ask    Notification: "Claude precisa de você · <project>" with the message

Reads the hook's JSON on stdin and calls the shell over IPC, detached. It never
blocks Claude Code and always exits 0 (nothing happens when the shell is off).
"""
import json
import os
import subprocess
import sys


def last_reply(transcript):
    """The first line of the last assistant text in the transcript (JSONL)."""
    try:
        with open(transcript, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            handle.seek(max(0, handle.tell() - 200_000))
            lines = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        message = entry.get("message") or {}
        if entry.get("type") != "assistant" or not isinstance(message.get("content"), list):
            continue
        for part in message["content"]:
            if part.get("type") == "text" and part.get("text", "").strip():
                return part["text"].strip().splitlines()[0]
    return ""


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "done"
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}
    project = os.path.basename((data.get("cwd") or os.getcwd()).rstrip("/")) or "~"
    if kind == "ask":
        text = data.get("message") or "esperando você"
    else:
        text = data.get("last_assistant_message") or last_reply(data.get("transcript_path") or "") or "pronto"
    text = " ".join(text.split())
    if len(text) > 90:
        text = text[:89] + "…"
    try:
        subprocess.Popen(["qs", "-c", "mosaic", "ipc", "call", "island", "claude", kind, project, text],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:  # a hook must never get in Claude Code's way
        pass
    sys.exit(0)
