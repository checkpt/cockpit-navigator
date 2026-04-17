#!/usr/bin/env python3
"""
Convert a .po file to a cockpit po.js file.

Usage: po2json.py <lang.po> <output.js>

Produces a JavaScript file that calls cockpit.locale({...}) with the
translation catalog in the format expected by cockpit.js.
"""

import json
import re
import sys


def parse_po(path):
    """Minimal .po parser – returns (headers_dict, entries_list).

    Each entry is (msgctxt, msgid, msgid_plural, [msgstr...]).
    Fuzzy entries are skipped.
    """
    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    # split into blocks separated by blank lines
    blocks = re.split(r"\n{2,}", text)
    headers = {}
    entries = []

    for block in blocks:
        lines = block.strip().splitlines()
        if not lines:
            continue

        # skip obsolete entries
        if lines[0].startswith("#~"):
            continue

        fuzzy = False
        msgctxt = ""
        msgid = ""
        msgid_plural = ""
        msgstr = []
        current = None

        for line in lines:
            # comments
            if line.startswith("#"):
                if ", fuzzy" in line:
                    fuzzy = True
                continue

            if line.startswith("msgctxt "):
                current = "msgctxt"
                msgctxt = _unquote(line[len("msgctxt "):])
            elif line.startswith("msgid_plural "):
                current = "msgid_plural"
                msgid_plural = _unquote(line[len("msgid_plural "):])
            elif line.startswith("msgid "):
                current = "msgid"
                msgid = _unquote(line[len("msgid "):])
            elif re.match(r"msgstr(\[\d+\])? ", line):
                current = "msgstr"
                val = re.sub(r"^msgstr(\[\d+\])? ", "", line)
                msgstr.append(_unquote(val))
            elif line.startswith('"'):
                val = _unquote(line)
                if current == "msgctxt":
                    msgctxt += val
                elif current == "msgid":
                    msgid += val
                elif current == "msgid_plural":
                    msgid_plural += val
                elif current == "msgstr":
                    msgstr[-1] += val
            else:
                continue

        if fuzzy:
            continue

        # header entry
        if msgid == "" and msgstr:
            for hline in msgstr[0].split("\n"):
                if ":" in hline:
                    key, _, val = hline.partition(":")
                    headers[key.strip().lower()] = val.strip()
            continue

        if not msgid:
            continue

        # skip untranslated
        if all(s == "" for s in msgstr):
            continue

        entries.append((msgctxt, msgid, msgid_plural, msgstr))

    return headers, entries


def _unquote(s):
    """Remove surrounding quotes and unescape."""
    s = s.strip()
    if s.startswith('"') and s.endswith('"'):
        s = s[1:-1]
    s = s.replace('\\"', '"')
    s = s.replace("\\n", "\n")
    s = s.replace("\\t", "\t")
    s = s.replace("\\\\", "\\")
    return s


def get_plural_expr(header_val):
    """Extract plural expression from Plural-Forms header."""
    if not header_val:
        return "(n) => n != 1"
    m = re.search(r"plural\s*=\s*(.+?);\s*$", header_val)
    if m:
        expr = m.group(1).strip()
        return f"(n) => {expr}"
    return "(n) => n != 1"


def po_to_js(po_path, js_path, manifest_keys=None):
    """Convert a .po file to cockpit po.js format (ES module).

    If manifest_keys is set, only include entries whose msgid is in that set.
    If manifest_keys is None, include all entries.
    """
    headers, entries = parse_po(po_path)

    lang = headers.get("language", "")
    plural_forms = headers.get("plural-forms", "nplurals=2; plural=(n != 1);")

    rtl_langs = {"ar", "fa", "he", "ur"}
    direction = "rtl" if lang in rtl_langs else "ltr"

    if manifest_keys is not None:
        entries = [(c, m, mp, ms) for c, m, mp, ms in entries if m in manifest_keys]

    chunks = []
    chunks.append("cockpit.locale(")
    chunks.append("{\n")
    chunks.append(' "": {\n')
    chunks.append(f'  "plural-forms": {get_plural_expr(plural_forms)},\n')
    chunks.append(f'  "language": {json.dumps(lang)},\n')
    chunks.append(f'  "language-direction": "{direction}"\n')
    chunks.append(" }")

    for msgctxt, msgid, msgid_plural, msgstr in entries:
        # cockpit uses \u0004 separator for context
        key = (msgctxt + "\u0004" + msgid) if msgctxt else msgid
        chunks.append(f",\n {json.dumps(key)}: [\n  null")
        for s in msgstr:
            chunks.append(f",\n  {json.dumps(s)}")
        chunks.append("\n ]")

    chunks.append("\n}")
    chunks.append(");\n")

    with open(js_path, "w", encoding="utf-8") as fh:
        fh.write("".join(chunks))


def get_manifest_labels(manifest_path):
    """Extract translatable labels from a cockpit manifest.json."""
    with open(manifest_path, encoding="utf-8") as fh:
        manifest = json.load(fh)
    labels = set()
    for section in ("menu", "tools"):
        for entry in manifest.get(section, {}).values():
            if "label" in entry:
                labels.add(entry["label"])
    return labels


if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print(f"Usage: {sys.argv[0]} <input.po> <output.js> [manifest.json]", file=sys.stderr)
        sys.exit(1)
    manifest_keys = None
    if len(sys.argv) == 4:
        manifest_keys = get_manifest_labels(sys.argv[3])
    po_to_js(sys.argv[1], sys.argv[2], manifest_keys=manifest_keys)
