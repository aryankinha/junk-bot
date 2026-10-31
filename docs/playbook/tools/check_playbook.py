"""Read-only checks for the playbook. Run from the workspace root:
    python3 -I godot_playbook/tools/check_playbook.py
1. Every backticked number is found in the file(s) named by the nearest (src: ...) citation
   (inline on the line, or on the section heading, or after the section's table for FINDINGS.md).
   Binary artifacts (.apk/.aab/fonts) are matched by byte size.
2. Line limits (AGENTS.md <= 80, every other file <= 150) and the Purpose / Last verified / Read this when header.
3. Banned words (whole-word 'bug'; 'fail*', 'problem', 'broken', 'unsafe', 'cannot', "can't", 'NOT VERIFIED').
4. Every doc that holds numbers has a 'Measured on' line (FINDINGS: one per section)."""
import glob, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PB = os.path.join(ROOT, "godot_playbook")
BIN = (".apk", ".aab", ".ttf", ".otf")
TEXT = (".txt", ".csv", ".md", ".json", ".cfg", ".gd", ".godot", ".py", ".sh", ".gradle", ".properties")


def text_of(path):
    if path.endswith(BIN):
        return str(os.path.getsize(path))
    if path.endswith(TEXT):
        return open(path, errors="ignore").read()
    return ""


def expand(token):
    token = token.strip().rstrip(".,;)")
    token = re.sub(r"<[^>]+>", "*", token)
    full = os.path.join(ROOT, token)
    if "*" in token:
        return glob.glob(full)
    if os.path.isdir(full):
        out = []
        for dp, _, fs in os.walk(full):
            out += [os.path.join(dp, f) for f in fs]
        return out
    return [full] if os.path.exists(full) else []


def haystack(src):
    parts = []
    for tok in re.split(r"[;,\s]+", src):
        if "/" in tok or tok.endswith(TEXT + BIN):
            for p in expand(tok):
                parts.append(text_of(p))
    return "\n".join(parts)


def numbers(line):
    out = []
    for m in re.finditer(r"`([^`]*)`", line):
        content = m.group(1).strip()
        if re.fullmatch(r"[~\d.,\u2013\- ]+", content):          # pure numbers only; identifiers, paths and versions are skipped
            out += re.findall(r"\d[\d.]*\d|\d", content)
    return out


def has(num, hay):
    return re.search(r"(?<![\d.])" + re.escape(num) + r"(?![\d])", hay) is not None


def src_of(line):
    m = re.search(r"\(src: ([^)]*)\)", line)
    return m.group(1) if m else None


errors, checked = [], 0
docs = [os.path.join(PB, "AGENTS.md"), os.path.join(PB, "CLAUDE.md")] + sorted(glob.glob(os.path.join(PB, "docs", "*.md")))
for path in docs:
    rel = os.path.relpath(path, ROOT)
    lines = open(path).read().splitlines()
    limit = 80 if rel.endswith("AGENTS.md") else 150
    if len(lines) > limit and not rel.endswith("CLAUDE.md"):
        errors.append(f"{rel}: {len(lines)} lines > {limit}")
    if rel.endswith("CLAUDE.md"):
        if lines != ["Read AGENTS.md first."]:
            errors.append(f"{rel}: must be the single line 'Read AGENTS.md first.'")
        continue
    head = "\n".join(lines[:6])
    for key in ("Purpose:", "Last verified:", "Read this when:"):
        if key not in head:
            errors.append(f"{rel}: header missing '{key}'")
    body = "\n".join(lines)
    for pat, name in [(r"\bbug\b", "bug"), (r"\bfail\w*", "fail*"), (r"\bproblem\w*", "problem"), (r"\bbroken\b", "broken"),
                      (r"\bunsafe\b", "unsafe"), (r"\bcannot\b", "cannot"), (r"can't", "can't"), (r"NOT VERIFIED", "NOT VERIFIED")]:
        for m in re.finditer(pat, body, re.I if name != "NOT VERIFIED" else 0):
            ln = body[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{ln}: banned word '{name}': {lines[ln-1].strip()[:80]}")
    if numbers(body) and "Measured on" not in body:
        errors.append(f"{rel}: has measured numbers but no 'Measured on' line")
    # number -> source checks
    section_src, section_hay = None, ""
    findings = rel.endswith("FINDINGS.md")
    sec_start = 0
    for i, line in enumerate(lines):
        if line.startswith("## "):
            section_src = src_of(line)
            sec_start = i
            if findings:
                # FINDINGS: the citation is the first '(src:' line after the heading
                for j in range(i + 1, len(lines)):
                    if lines[j].startswith("## "):
                        break
                    s = src_of(lines[j])
                    if s and lines[j].startswith("(src:"):
                        section_src = s
                        break
                body_sec = "\n".join(lines[i:i + 40])
                if "Measured on" not in "\n".join(lines[i:min(len(lines), i + 4)]) and any(l.startswith("|") for l in lines[i:i + 8]):
                    errors.append(f"{rel}:{i+1}: section '{line[:50]}' has a table but no 'Measured on' line")
            section_hay = haystack(section_src) if section_src else ""
        nums = numbers(line)
        if not nums:
            continue
        s = src_of(line)
        hay = haystack(s) if s else section_hay
        if not hay:
            errors.append(f"{rel}:{i+1}: numbers {nums[:3]} have no (src: ...) citation: {line.strip()[:70]}")
            continue
        for n in nums:
            checked += 1
            if not has(n, hay):
                errors.append(f"{rel}:{i+1}: number {n} not found in cited source: {line.strip()[:70]}")

print(f"files checked: {len(docs)}; backticked numbers checked against their sources: {checked}")
for e in errors:
    print("MISMATCH:", e)
print("RESULT:", "ALL CHECKS PASSED" if not errors else f"{len(errors)} item(s) to fix")
sys.exit(1 if errors else 0)
