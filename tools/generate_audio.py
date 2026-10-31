"""Original procedural SFX and short loops; no third-party recordings."""
from pathlib import Path
import wave,math,struct,random
out=Path(__file__).resolve().parents[1]/'assets/audio'
out.mkdir(exist_ok=True)
rate=22050
rng=random.Random(77)
def write(name,values):
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*22000)) for v in values))
for name,freq,duration in [('attach',180,.16),('upgrade',660,.24),('stage',110,.4),('scrap',1200,.055),('fire',320,.08),('hit',80,.18),('break',65,.3),('warning',780,.16),('special',440,.3),('victory',550,.8),('defeat',180,.65),('click',550,.06),('explosion',50,.28),('dodge',900,.1)]:
 values=[]
 for i in range(int(rate*duration)):
  t=i/rate;fade=(1-t/duration)**2
  noise=rng.uniform(-1,1)*(.45 if name in ['hit','break','explosion','attach'] else .03)
  pitch=freq*(1+1.8*t if name in ['upgrade','special','victory'] else 1-t*.5)
  values.append((math.sin(2*math.pi*pitch*t)*.48+noise)*fade)
 write(name,values)
for name,notes in [('run_music',[110,164.81,220,164.81,130.81,196,261.63,196]),('hangar_music',[130.81,164.81,196,164.81,146.83,174.61,220,174.61])]:
 beat=60/110;values=[]
 for i in range(int(rate*beat*16)):
  t=i/rate;step=int(t/beat);local=t%beat;freq=notes[step%len(notes)]
  bass=math.sin(2*math.pi*freq*t)*math.exp(-local*6)*.19
  kick=math.sin(2*math.pi*(52-local*20)*t)*math.exp(-local*24)*.2 if step%2==0 else 0
  hat=rng.uniform(-1,1)*math.exp(-(t%(beat/2))*80)*.025
  values.append(bass+kick+hat)
 write(name,values)

import subprocess
for name in ["run_music","hangar_music"]:
 subprocess.run(["ffmpeg","-loglevel","error","-y","-i",str(out/(name+".wav")),"-ac","2","-c:a","vorbis","-strict","experimental","-q:a","3",str(out/(name+".ogg"))],check=True)
 (out/(name+".wav")).unlink()
