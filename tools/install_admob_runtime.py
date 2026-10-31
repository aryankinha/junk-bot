from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
source=root/'third_party/admob/poing-godot-admob-v5.1.0/poing-godot-admob/addons/admob'
dest=root/'addons/admob'
for folder in ['gdscript/src','internal/version','internal/mock']:
 shutil.copytree(source/folder,dest/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.import'))
(dest/'assets').mkdir(exist_ok=True)
for f in (source/'assets').iterdir():
 if f.suffix in ['.svg','.png']:shutil.copy2(f,dest/'assets'/f.name)
shutil.copy2(source/'LICENSE',dest/'LICENSE')
for filename in ['package.gd']:
 target=dest/'android/bin'/filename;target.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(root/'third_party/admob/android-template-v4.7.2'/filename,target)
shutil.copytree(root/'third_party/admob/android-template-v4.7.2/ads',dest/'android/bin/ads',dirs_exist_ok=True)
print('Installed unmodified GDScript runtime and matching core native libraries; no mediation SDKs')
