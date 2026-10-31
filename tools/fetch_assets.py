"""Fetch public CC0 source archives outside the repository; retain inventories/licenses."""
from pathlib import Path
import urllib.request,zipfile,hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
URLS={
 'space-kit':'https://kenney.nl/media/pages/assets/space-kit/20874c75ac-1677698978/kenney_space-kit.zip',
 'blaster-kit':'https://kenney.nl/media/pages/assets/blaster-kit/261d80a716-1753959510/kenney_blaster-kit_2.1.zip',
 'car-kit':'https://kenney.nl/media/pages/assets/car-kit/1a312ec241-1775131960/kenney_car-kit.zip',
}
rows=[]
for name,url in URLS.items():
 dest=Path('/tmp')/('scrap_'+name+'.zip')
 try:
  if not dest.exists():dest.write_bytes(urllib.request.urlopen(url,timeout=45).read())
  z=zipfile.ZipFile(dest); names=z.namelist()
  models=[n for n in names if n.lower().endswith(('.glb','.gltf'))]
  out=ROOT/'results'/('inventory_'+name+'.json');out.write_text(json.dumps(models,indent=2))
  licenses=[n for n in names if re.search(r'licen[cs]e.*\.txt$',n,re.I)]
  for i,n in enumerate(licenses):
   target=ROOT/'assets/licenses'/f'{name}_{i}.txt';target.parent.mkdir(exist_ok=True);target.write_bytes(z.read(n))
  rows.append([name,url,hashlib.sha256(dest.read_bytes()).hexdigest(),len(models)])
  print(name,len(models),'models')
 except Exception as e: print(name,'FAILED',e)
(ROOT/'results/asset_downloads.json').write_text(json.dumps(rows,indent=2))
