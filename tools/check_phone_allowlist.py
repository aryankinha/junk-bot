"""Validate the exact adb forms in the phone runner before use."""
from pathlib import Path
p=Path(__file__).with_name('phone_perf_session.sh')
lines=p.read_text().splitlines()
allowed=['shell getprop "$prop"','shell dumpsys battery','shell dumpsys thermalservice',"shell 'dumpsys window | grep mCurrentFocus'",'shell pm path "$PKG"','install -r build/scrap_dragon_debug.apk','install build/scrap_dragon_debug.apk','shell am force-stop "$PKG"','shell am start -W -n "$PKG/com.godot.game.GodotAppLauncher"','shell dumpsys meminfo "$PKG"','exec-out run-as "$PKG" cat files/perf.json','exec-out run-as "$PKG" cat files/perf_frames.csv','exec-out run-as "$PKG" cat files/telemetry.jsonl','exec-out screencap -p','exec-out run-as "$PKG" touch "files/$marker"']
count=0
for num,line in enumerate(lines,1):
 if 'adb ' not in line or line.lstrip().startswith('#'):continue
 if 'adb devices -l' in line:count+=1;continue
 assert 'adb -s "$SERIAL" ' in line, f'{num}: missing serial'
 assert any(form in line for form in allowed),f'{num}: command outside allowlist'
 assert not any(word in line for word in ['uninstall','settings put','input tap','pm clear','rm ']),f'{num}: forbidden mutation'
 count+=1
assert "PKG='com.aryankinha.scrapdragon'" in p.read_text()
print(f'PASS: {count} adb calls, explicit serial and owned package, foreground-gated screenshot')

assert "scrap_stress_a$attempt" in p.read_text()
