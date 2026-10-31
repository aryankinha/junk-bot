"""Extract only android_source.zip from the official remote export archive using HTTP ranges."""
from pathlib import Path
import urllib.request,struct,zlib,zipfile,io,hashlib,json
root=Path(__file__).resolve().parents[1]
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
SIZE=1281349702
def get_range(start,end):
 req=urllib.request.Request(URL,headers={'User-Agent':'ScrapDragon-template-setup','Range':f'bytes={start}-{end}'})
 with urllib.request.urlopen(req,timeout=60) as r:
  if r.status!=206:raise RuntimeError(f'Server did not support partial download (HTTP {r.status}); stopped before downloading full archive')
  data=r.read(end-start+2)
  if len(data)!=end-start+1:raise RuntimeError('Incomplete range')
  return data
try:
 tail=get_range(SIZE-65536,SIZE-1)
 pos=tail.rfind(b'PK\x05\x06')
 e=struct.unpack_from('<4s4H2IH',tail,pos)
 central=get_range(e[6],e[6]+e[5]-1)
 offset=0;entry=None
 while offset<len(central):
  h=struct.unpack_from('<4s6H3I5H2I',central,offset)
  assert h[0]==b'PK\x01\x02'
  name=central[offset+46:offset+46+h[10]].decode()
  if name.endswith('/android_source.zip') or name=='android_source.zip':entry=(name,h);break
  offset+=46+h[10]+h[11]+h[12]
 if entry is None:raise RuntimeError('Matching archive has no Android source template')
 name,h=entry
 print('Fetching only',name,'compressed bytes',h[8],flush=True)
 local=get_range(h[16],h[16]+29)
 lh=struct.unpack('<4s5H3I2H',local)
 start=h[16]+30+lh[9]+lh[10]
 compressed=get_range(start,start+h[8]-1)
 data=zlib.decompress(compressed,-15) if h[4]==8 else compressed
 assert len(data)==h[9] and zlib.crc32(data)&0xffffffff==h[7]
 out=root/'android/build';out.mkdir(parents=True,exist_ok=True)
 zipfile.ZipFile(io.BytesIO(data)).extractall(out)
 (root/'android/.build_version').write_text('4.7.2.stable')
 (root/'android/.gdignore').touch()
 (root/'results/android_template.json').write_text(json.dumps({'source':URL,'file':name,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)},indent=2))
 print('Installed matching Gradle template',len(data),'bytes')
except Exception as e:
 print('TEMPLATE SETUP INCOMPLETE:',type(e).__name__,e)
 (root/'results/android_template_setup.txt').write_text(str(e)+'\n')
 raise SystemExit(1)
