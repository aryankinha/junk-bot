"""Builds docs/FINDINGS.md and data/ads_frame_stats.txt from the result files (read-only on sources).
Run from the workspace root:  python3 -I godot_playbook/tools/build_findings.py
Every measured value is extracted from the file named in its (src: ...) citation, so the
tables stay in step with the results folders. Backticked values are checked by tools/check_playbook.py."""
import csv, os, re, statistics as st

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RD = "car/phone_test_results"
A, B = f"{RD}/20261028-123123", f"{RD}/20261028-125203_session2"
LAB = "godot_lab/results"
P2, P3, P4, P4C = (f"{LAB}/phone2_20261028-143502", f"{LAB}/phone3_20261028-150837_b_c",
                   f"{LAB}/phone4_20261028-153046_b", f"{LAB}/phone4_20261028-153046_b_c")

def rd(p): return open(os.path.join(ROOT, p), errors="ignore").read()
def x(p, pat, g=1, flags=0):
    m = re.search(pat, rd(p), flags)
    assert m, (p, pat)
    return m.group(g)
def b(v): return f"`{v}`"
def sz(p): return os.path.getsize(os.path.join(ROOT, p))

def playing_block(p):
    t = rd(p).split("PLAYING only:")[1].split("PLAYING tier")[0]
    return t
def road(p):
    t = playing_block(p)
    g = lambda pat: re.search(pat, t).group(1)
    return dict(frames=g(r"frames=(\d+)"), span=g(r"span=([\d.]+)s"), p99=g(r"p99=([\d.]+)"), worst=g(r"worst=([\d.]+)"),
                over167=g(r">16\.7ms=([\d.]+)%"), over25=g(r">25ms=(\d+)"), over50=g(r">50ms=(\d+)"), draws=g(r"draw_calls avg=(\d+)"))
def totals(p):
    return [int(v) for v in re.findall(r"TotalTime: (\d+)", rd(p))]
def mem(p):
    return x(p, r"TOTAL PSS:\s+(\d+)"), x(p, r"Graphics:\s+(\d+)")

dev = "OnePlus CPH2585, SM8550 (kalama), Android 16 (SDK 36), 60 Hz"
L = []
w = L.append
w("# FINDINGS: measured results")
w("")
w("Purpose: every measurement we hold, with its source file and measuring context.")
w("Last verified: 2026-10-28")
w("Read this when: you need a number to plan a budget, choose an import setting, or compare a new game with ours.")
w("")
w("Values in backticks are extracted from the cited file by `tools/build_findings.py` and re-checked by `tools/check_playbook.py`.")
w("Paths are relative to the workspace root (the folder that holds `car/`, `godot_lab/`, `godot_playbook/`).")
w("")
# ---- T1
mo, gl = road(f"{B}/summary_mobile.txt"), road(f"{A}/summary_gl.txt")
w("## 1. Road Dodge on the phone: Mobile (Vulkan) vs Compat (OpenGL)")
w(f"Measured on: {dev}; Road Dodge debug APKs; frame_ms from the engine delta (the Road Dodge logger); hand-played sessions.")
w("")
w("| Metric (PLAYING frames only) | Mobile (Vulkan) | Compat (OpenGL) |")
w("| --- | --- | --- |")
w(f"| Frames logged / seconds | {b(mo['frames'])} / {b(mo['span'])} | {b(gl['frames'])} / {b(gl['span'])} |")
w(f"| p99 frame_ms | {b(mo['p99'])} | {b(gl['p99'])} |")
w(f"| Worst frame_ms | {b(mo['worst'])} | {b(gl['worst'])} |")
w(f"| Share over 16.7 ms (%) | {b(mo['over167'])} | {b(gl['over167'])} |")
w(f"| Frames over 25 ms / over 50 ms | {b(mo['over25'])} / {b(mo['over50'])} | {b(gl['over25'])} / {b(gl['over50'])} |")
w(f"| Average draw calls | {b(mo['draws'])} | {b(gl['draws'])} |")
tm, tg = totals(f"{A}/cold_start_mobile.txt"), totals(f"{A}/cold_start_gl.txt")
w(f"| Cold start `am start -W` TotalTime, 5 launches (ms) | {b(tm[0])}, {b(tm[1])}, {b(tm[2])}, {b(tm[3])}, {b(tm[4])} | {b(tg[0])}, {b(tg[1])}, {b(tg[2])}, {b(tg[3])}, {b(tg[4])} |")
fm, fg = totals(f"{A}/first_launch_mobile.txt")[0], totals(f"{A}/first_launch_gl.txt")[0]
w(f"| First launch after install TotalTime (ms) | {b(fm)} | {b(fg)} |")
def csvcol(p, col): return [r[col] for r in csv.DictReader(open(os.path.join(ROOT, p)))][1:]
pm, pg = csvcol(f"{A}/coldstart_mobile_on.csv", "first_playable_frame_ms"), csvcol(f"{A}/coldstart_gl_on.csv", "first_playable_frame_ms")
w(f"| Engine start to first playable frame, warm-up on, 5 launches (ms) | {b(pm[0])}, {b(pm[1])}, {b(pm[2])}, {b(pm[3])}, {b(pm[4])} | {b(pg[0])}, {b(pg[1])}, {b(pg[2])}, {b(pg[3])}, {b(pg[4])} |")
ms, mg = mem(f"{B}/meminfo_mobile_end.txt"), mem(f"{A}/meminfo_gl_end.txt")
w(f"| `dumpsys meminfo` TOTAL PSS / Graphics at session end (KB) | {b(ms[0])} / {b(ms[1])} | {b(mg[0])} / {b(mg[1])} |")
tb = rd(f"{B}/system_mobile.txt"); tt = rd(f"{A}/system_gl.txt")
w(f"| Battery temperature at session end (tenths of a degree C) | {b(re.findall(r'temperature: (\d+)', tb)[-1])} | {b(re.findall(r'temperature: (\d+)', tt)[-1])} |")
tier = rd(f"{A}/summary_gl.txt")
hi = re.search(r"tier=HIGH: frames=(\d+)", tier).group(1); me = re.search(r"tier=MEDIUM: frames=(\d+)", tier).group(1)
mo_t = re.search(r"tier=MEDIUM: frames=(\d+)", rd(f"{B}/summary_mobile.txt")).group(1)
w(f"| Quality tier of those frames | MEDIUM {b(mo_t)} | HIGH {b(hi)}, MEDIUM {b(me)} |")
w("")
w(f"(src: {B}/summary_mobile.txt; {A}/summary_gl.txt; {A}/cold_start_mobile.txt; {A}/cold_start_gl.txt; {A}/first_launch_mobile.txt; {A}/first_launch_gl.txt; {A}/coldstart_mobile_on.csv; {A}/coldstart_gl_on.csv; {B}/meminfo_mobile_end.txt; {A}/meminfo_gl_end.txt; {B}/system_mobile.txt; {A}/system_gl.txt)")
w("")
# ---- T2 ladder
w("## 2. Texture ladder (one full-screen textured quad, 30 s per cell)")
w(f"Measured on: {dev}; godot_lab Compat build, Adreno 740; raw = Lossless import, etc2 = VRAM compressed, astc = VRAM compressed high quality; mipmaps on.")
w("")
w("| Size | Format | Load ms | Godot texture memory MB | p99 frame ms | Share over 20 ms (%) |")
w("| --- | --- | --- | --- | --- | --- |")
srcs = []
for s in (512, 1024, 2048, 4096, 8192):
    for f in ("raw", "etc2", "astc"):
        n = f"s5_{s}_{f}_a1"
        sp, mp = f"{P2}/summary_{n}.txt", f"{P2}/bench_{n}_meta.txt"
        w(f"| {s} | {f} | {b(x(mp, r'load_ms=([\d.]+)'))} | {b(x(mp, r'texture_mem_mb=([\d.]+)'))} | {b(x(sp, r'p99=([\d.]+)'))} | {b(x(sp, r'20ms=([\d.]+)%'))} |")
w("")
w(f"(src: {P2}/summary_s5_<size>_<format>_a1.txt and {P2}/bench_s5_<size>_<format>_a1_meta.txt, one pair per row)")
w("")
# ---- T3 S4
w("## 3. S4 heavy model: Poly Haven ship_pinnace (CC0), 60 s per run")
w(f"Measured on: {dev}; godot_lab Compat build, Adreno 740; raw unsmoothed frame times.")
w("")
runs = [("2K lossless", P3, "s4_2k_a1", "s4_2k_a1", "builds/lab_s4_2k_debug.apk"),
        ("4K ASTC + mipmaps", P4, "s4_4k_a1", "s4_4k_astc_a1", "builds/lab_s4_astc4k_debug.apk"),
        ("4K lossless", P4C, "s4_4k_a2", "s4_4k_lossless_a2", "builds/lab_s4_4k_lossless_debug2.apk")]
w("| Metric | 2K lossless | 4K ASTC + mipmaps | 4K lossless |")
w("| --- | --- | --- | --- |")
def row(name, fn): w(f"| {name} | " + " | ".join(fn(r) for r in runs) + " |")
row("APK size (bytes)", lambda r: b(sz("godot_lab/" + r[4])))
row("Primitives per frame", lambda r: b(x(f"{r[1]}/summary_{r[2]}.txt", r"primitives=(\d+)")))
row("Draw calls per frame", lambda r: b(x(f"{r[1]}/summary_{r[2]}.txt", r"draws=(\d+)")))
row("Texture load ms", lambda r: b(x(f"{r[1]}/bench_{r[2]}_meta.txt", r"load_ms=(\d+)")))
row("First frame since engine start ms", lambda r: b(x(f"{r[1]}/bench_{r[2]}_meta.txt", r"first_frame_since_engine_start_ms=(\d+)")))
row("Godot texture memory MB", lambda r: b(x(f"{r[1]}/bench_{r[2]}_meta.txt", r"texture_mem_mb=([\d.]+)")))
row("`dumpsys` TOTAL PSS KB (end)", lambda r: b(mem(f"{r[1]}/{r[3]}_meminfo_end.txt")[0]))
row("`dumpsys` Graphics KB (end)", lambda r: b(mem(f"{r[1]}/{r[3]}_meminfo_end.txt")[1]))
row("p99 frame ms", lambda r: b(x(f"{r[1]}/summary_{r[2]}.txt", r"p99=([\d.]+)")))
row("Share over 20 ms (%)", lambda r: b(x(f"{r[1]}/summary_{r[2]}.txt", r"20ms=([\d.]+)%")))
row("Worst frame ms", lambda r: b(x(f"{r[1]}/summary_{r[2]}.txt", r"worst=([\d.]+)")))
row("Cold start `am start -W` TotalTime ms", lambda r: b(x(f"{r[1]}/{r[3]}_launch.txt", r"TotalTime: (\d+)")))
row("Battery temperature start to end (tenths C)", lambda r: b(re.findall(r"temperature: (\d+)", rd(f"{r[1]}/{r[3]}_temp_start.txt"))[0]) + " to " + b(re.findall(r"temperature: (\d+)", rd(f"{r[1]}/{r[3]}_temp_end.txt"))[0]))
w("")
w(f"(src: summary_*, bench_*_meta, *_meminfo_end, *_launch, *_temp_* files in {P3}, {P4}, {P4C}; APK sizes from godot_lab/builds/)")
w("")
# ---- T4 fonts
w("## 4. Fonts and text cost")
w(f"Measured on: {dev}; godot_lab Compat build; Bungee + Noto Sans Devanagari + Noto Sans Arabic with a Latin, Devanagari, Arabic fallback chain.")
w("")
w("| Scene | Seconds | p99 frame ms | Share over 20 ms (%) | Worst ms | Draw calls | Objects | Process ms avg | Render CPU ms avg |")
w("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
fonts = [("View 16 px", P3, "fonts_view_16_a1"), ("View 32 px", P3, "fonts_view_32_a1"), ("View 64 px", P3, "fonts_view_64_a1"),
         ("200 Labels", P4C, "fonts_cost_a2"), ("Counter Label (text changes every frame)", P4C, "fonts_cost_counter_a2")]
for n, d, i in fonts:
    p = f"{d}/summary_{i}.txt"
    w(f"| {n} | {b(x(p, r'span=([\d.]+)s'))} | {b(x(p, r'p99=([\d.]+)'))} | {b(x(p, r'20ms=([\d.]+)%'))} | {b(x(p, r'worst=([\d.]+)'))} | {b(x(p, r'draws=(\d+)'))} | {b(x(p, r'objects=(\d+)'))} | {b(x(p, r'process_ms avg=([\d.]+)'))} | {b(x(p, r'render_cpu_ms avg=([\d.]+)'))} |")
w("")
mp = f"{P3}/bench_fonts_view_16_a1_meta.txt"
w(f"Text server reported by the app on the phone: {b(x(mp, r'text_server=(.*)'))}; shaping {b(x(mp, r'shaping=(\w+)'))}, bidi {b(x(mp, r'bidi=(\w+)'))}, variable fonts {b(x(mp, r'variable_fonts=(\w+)'))}.")
fs = {n: sz(f"godot_lab/third_party/fonts/{p}") for n, p in [("Bungee-Regular.ttf", "bungee/Bungee-Regular.ttf"), ("NotoSansDevanagari-VF.ttf", "noto_sans_devanagari/NotoSansDevanagari-VF.ttf"), ("NotoSansArabic-VF.ttf", "noto_sans_arabic/NotoSansArabic-VF.ttf")]}
w(f"Font file sizes in bytes: Bungee {b(fs['Bungee-Regular.ttf'])}, Devanagari variable {b(fs['NotoSansDevanagari-VF.ttf'])}, Arabic variable {b(fs['NotoSansArabic-VF.ttf'])}.")
w("")
w(f"(src: {P3}/summary_fonts_view_*_a1.txt; {P4C}/summary_fonts_cost_a2.txt; {P4C}/summary_fonts_cost_counter_a2.txt; {mp}; godot_lab/third_party/fonts/)")
w("")
# ---- T5 ads
w("## 5. AdMob test ads (Google public test IDs)")
w(f"Measured on: {dev}; godot_lab Compat build with Poing Studios godot-admob-plugin v5.1.0; callbacks logged by `godot_lab/scripts/ads_menu.gd`.")
w("")
rows = list(csv.DictReader(open(os.path.join(ROOT, P3, "ads_log.csv"))))
w("| Callback | ms since app start |")
w("| --- | --- |")
keep = ["sdk_initialized", "banner_load_started", "banner_loaded", "banner_impression", "interstitial_loaded", "interstitial_shown", "interstitial_impression",
        "rewarded_loaded", "rewarded_shown", "rewarded_impression", "reward_earned", "rewarded_dismissed", "interstitial_dismissed", "banner_hidden"]
for r in rows:
    if r["event"] in keep:
        w(f"| {r['event']} | {b(r['ticks_ms'])} |")
lc = [r for r in rows if r["event"] == "lifecycle"]
pause = [r for r in lc if r["detail"] == "APPLICATION_PAUSED"][0]; res = [r for r in lc if r["detail"] == "APPLICATION_RESUMED"][0]
w(f"| lifecycle APPLICATION_PAUSED / APPLICATION_RESUMED | {b(pause['ticks_ms'])} / {b(res['ticks_ms'])} |")
w("")
fr = list(csv.DictReader(open(os.path.join(ROOT, P3, "ads_frames.csv"))))
def pct(v, p):
    v = sorted(v); return v[min(len(v) - 1, int(round(p / 100 * (len(v) - 1))))]
ban = [float(r["frame_ms"]) for r in fr if r["banner_visible"] == "1" and r["fullscreen_open"] == "0" and not r["note"]]
fsf = [float(r["frame_ms"]) for r in fr if r["fullscreen_open"] == "1"]
allf = [float(r["frame_ms"]) for r in fr]
gaps = [float(r["frame_ms"]) for r in fr if float(r["frame_ms"]) > 250]
out = ["Derived from " + f"{P3}/ads_frames.csv" + " by tools/build_findings.py",
       f"frames_total={len(allf)} p99={pct(allf,99):.2f} worst={max(allf):.2f}",
       f"banner_visible_no_fullscreen frames={len(ban)} p99={pct(ban,99):.2f} over20ms_pct={100*sum(x>20 for x in ban)/len(ban):.2f} worst={max(ban):.2f}",
       f"fullscreen_open frames={len(fsf)} p99={pct(fsf,99):.2f} worst={max(fsf):.2f}",
       f"frames_over_250ms={len(gaps)}"]
open(os.path.join(ROOT, "godot_playbook/data/ads_frame_stats.txt"), "w").write("\n".join(out) + "\n")
w(f"Frame times from the Godot loop while ads were up (derived file): banner visible {b(len(ban))} frames, p99 {b(f'{pct(ban,99):.2f}')} ms, worst {b(f'{max(ban):.2f}')} ms; full-screen ad open {b(len(fsf))} frames, p99 {b(f'{pct(fsf,99):.2f}')} ms; frames over 250 ms: {b(len(gaps))}.")
w("")
w(f"(src: {P3}/ads_log.csv; godot_playbook/data/ads_frame_stats.txt)")
w("")
# ---- T6 draw calls
w("## 6. Draw-call history (Road Dodge, HIGH tier, playing, 4 cars)")
w("Measured on: Apple M3 desktop (Metal, Forward Mobile) with `tests/draw_breakdown.gd`; table copied from the project README.")
w("")
w("| Category | Before | After |")
w("| --- | --- | --- |")
rm = rd("car/README.md")
for m in re.finditer(r"^\| (road|props \(trees, bushes, posts\)|clouds|hills|traffic|player|UI|\*\*total\*\*) \| (?:\*\*)?(\d+)(?:\*\*)? \| (?:\*\*)?(\d+)(?:\*\*)? \|", rm, re.M):
    w(f"| {m.group(1).replace('**','')} | {b(m.group(2))} | {b(m.group(3))} |")
tiers = re.search(r"\| Draw calls \(measured\) \| (~\d+) \| (~\d+–\d+) \| (~\d+) \|", rm)
w(f"| Tier draw calls HIGH / MEDIUM / LOW (after) | {b(tiers.group(1))} / {b(tiers.group(2))} / {b(tiers.group(3))} | |")
w("")
w("(src: car/README.md)")
w("")
# ---- T7 sizes
w("## 7. Package sizes")
w("Measured on: file sizes of the exported artifacts on the Mac (bytes).")
w("")
w("| Artifact | Bytes |")
w("| --- | --- |")
for n, p in [("Road Dodge debug APK (non-Gradle, arm64)", "car/build/road_dodge_debug.apk"), ("Road Dodge sideload APK (arm64, release-signed)", "car/build/road_dodge_sideload_arm64.apk"),
             ("Road Dodge release AAB", "car/build/road_dodge_release.aab"), ("godot_lab S4 2K APK", "godot_lab/builds/lab_s4_2k_debug.apk"),
             ("godot_lab S4 4K ASTC APK", "godot_lab/builds/lab_s4_astc4k_debug.apk"), ("godot_lab S4 4K lossless APK", "godot_lab/builds/lab_s4_4k_lossless_debug2.apk"),
             ("godot_lab fonts + ads APK (no ship textures)", "godot_lab/builds/lab_fontsads_debug.apk"), ("godot_lab textures-only APK", "godot_lab/builds/lab_textures_debug2.apk")]:
    w(f"| {n} | {b(sz(p))} |")
g = re.search(r"arm64-v8a only, but ([\d.]+) MB because.*?the same APK is ([\d.]+) MB", rm, re.S)
w(f"| Gradle debug APK, native libs stored uncompressed / compressed (MB) | {b(g.group(1))} / {b(g.group(2))} |")
w("")
w("(src: car/build/; godot_lab/builds/; car/README.md)")
open(os.path.join(ROOT, "godot_playbook/docs/FINDINGS.md"), "w").write("\n".join(L) + "\n")
print("FINDINGS.md lines:", len(L))
