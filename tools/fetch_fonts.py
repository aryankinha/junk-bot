from pathlib import Path
import urllib.request,hashlib,json
root=Path(__file__).resolve().parents[1]
out=root/'assets/fonts';out.mkdir(exist_ok=True)
rows=[]
for family,name in [('rajdhani','Rajdhani-Bold.ttf'),('barlow','Barlow-SemiBold.ttf')]:
 for filename in [name,'OFL.txt']:
  url=f'https://raw.githubusercontent.com/google/fonts/main/ofl/{family}/{filename}'
  data=urllib.request.urlopen(url,timeout=30).read()
  if filename.endswith('.ttf') and not data.startswith((b'\x00\x01\x00\x00',b'OTTO')):raise ValueError('Expected real font bytes')
  target=out/(family+'_'+filename)
  target.write_bytes(data)
  rows.append({'file':str(target.relative_to(root)),'source':url,'license':'SIL OFL 1.1','downloaded':'2026-10-31','sha256':hashlib.sha256(data).hexdigest()})
(root/'results/font_downloads.json').write_text(json.dumps(rows,indent=2))
print('Downloaded two fonts and their OFL licences')
