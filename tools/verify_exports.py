from pathlib import Path
import zipfile,struct,json,hashlib,subprocess
root=Path(__file__).resolve().parents[1]
tools=Path('/Users/aryankinha/Library/Android/sdk/build-tools/36.1.0')
rows=[]
for file in sorted((root/'build').glob('scrap_dragon*')):
 if file.suffix not in ['.apk','.aab']:continue
 row={'file':str(file.relative_to(root)),'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'debug_signed':True,'native_libraries':[]}
 with zipfile.ZipFile(file) as z:
  row['development_files_in_package']=[n for n in z.namelist() if n.startswith(('assets/reports/','assets/results/','assets/tests/','assets/docs/'))]
  for name in z.namelist():
   if not name.endswith('.so'):continue
   data=z.read(name)
   if data[:4]!=b'\x7fELF':continue
   eh=struct.unpack_from('<16sHHIQQQIHHHHHH',data)
   alignments=[]
   for i in range(eh[10]):
    ph=struct.unpack_from('<IIQQQQQQ',data,eh[5]+i*eh[9])
    if ph[0]==1:alignments.append(ph[7])
   row['native_libraries'].append({'name':name,'load_segment_alignments':alignments,'supports_16k_pages':bool(alignments) and min(alignments)>=16384})
 if file.suffix=='.apk':
  for command,label in [('badging','badging'),('permissions','permissions')]:
   r=subprocess.run([str(tools/'aapt2'),'dump',command,str(file)],capture_output=True,text=True)
   (root/f'results/{file.stem}_{label}.txt').write_text(r.stdout)
  r=subprocess.run([str(tools/'zipalign'),'-c','-P','16','-v','4',str(file)],capture_output=True,text=True)
  row['zipalign_16k_ok']=r.returncode==0
  (root/f'results/{file.stem}_zipalign.txt').write_text(r.stdout+r.stderr)
 rows.append(row)
(root/'results/export_verification.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
