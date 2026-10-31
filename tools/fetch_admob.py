from pathlib import Path
import urllib.request,zipfile,io,hashlib,json
root=Path(__file__).resolve().parents[1]
rows=[]
for name in ['poing-godot-admob-v5.1.0.zip','android-template-v4.7.2.zip']:
 url='https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/'+name
 data=urllib.request.urlopen(url,timeout=45).read()
 archive=zipfile.ZipFile(io.BytesIO(data))
 target=root/'third_party/admob'/name.replace('.zip','')
 target.mkdir(parents=True,exist_ok=True)
 archive.extractall(target)
 rows.append({'name':name,'url':url,'sha256':hashlib.sha256(data).hexdigest(),'license':'MIT','downloaded':'2026-10-31'})
 print(name, 'downloaded',len(data),'bytes')
(root/'results/admob_downloads.json').write_text(json.dumps(rows,indent=2))
