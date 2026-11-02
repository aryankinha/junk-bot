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
# UI-v2 ready cue; isolated mode leaves every existing sample byte-identical.
import sys
if '--hook-only' in sys.argv:
 hook_rng=random.Random(412)
 for name,duration,f0,f1,noise in [('weld',.36,440,950,.22),('plate_clang',.34,210,90,.13),('polish',.5,720,1700,.005),('gate_step',.18,520,840,.01),('jackpot',.48,370,1550,.025),('kill_pop',.12,360,160,.05)]:
  values=[];phase=0.0
  for i in range(int(rate*duration)):
   t=i/rate;u=t/duration;phase+=2*math.pi*(f0+(f1-f0)*u)/rate
   tone=math.sin(phase)+.22*math.sin(phase*2.03)+.13*math.sin(phase*4.1)
   values.append((tone*.3+hook_rng.uniform(-1,1)*noise)*min(1,t/.006)*(1-u)**1.6)
  write(name,values)
 sys.exit(0)
if '--ui-only' in sys.argv:
 values=[]
 for i in range(int(rate*.22)):
  t=i/rate;f=620 if t<.1 else 920
  values.append(math.sin(2*math.pi*f*t)*.35*min(1,t/.008)*(1-t/.22)**2)
 write('ready',values)
 sys.exit(0)
for name,freq,duration in [('attach',180,.16),('upgrade',660,.24),('stage',110,.4),('scrap',1200,.055),('fire',320,.08),('hit',80,.18),('break',65,.3),('warning',780,.16),('special',440,.3),('victory',550,.8),('defeat',180,.65),('click',550,.06),('explosion',50,.28),('dodge',900,.1)]:
 values=[]
 for i in range(int(rate*duration)):
  t=i/rate;fade=(1-t/duration)**2
  noise=rng.uniform(-1,1)*(.45 if name in ['hit','break','explosion','attach'] else .03)
  pitch=freq*(1+1.8*t if name in ['upgrade','special','victory'] else 1-t*.5)
  values.append((math.sin(2*math.pi*pitch*t)*.48+noise)*fade)
 write(name,values)

# Mob Stream sounds (own RNG so the original effects and music stay bit-identical).
import sys
mob_rng=random.Random(91)
def sweep(duration,f0,f1,noise=0.0,square=0.0,attack=0.01,power=2.0,harm=0.0):
 values=[];phase=0.0
 for i in range(int(rate*duration)):
  t=i/rate;u=t/duration;freq=f0+(f1-f0)*u;phase+=2*math.pi*freq/rate
  tone=math.sin(phase)+harm*math.sin(2*phase)
  if square:tone=tone*(1-square)+square*(1 if math.sin(phase)>0 else -1)
  env=min(1,t/attack)*(1-u)**power
  values.append((tone*.42+mob_rng.uniform(-1,1)*noise)*env)
 return values
write('multiply',sweep(.26,520,1180,noise=.02,harm=.5,power=1.4))
write('swarm_hit',sweep(.11,170,60,noise=.5,power=3.0))
write('champion',[a+b for a,b in zip(sweep(.8,95,38,noise=.18,harm=.6,attack=.03,power=1.2),sweep(.8,200,900,noise=.04,power=0.7)[:int(rate*.8)])])
write('trap',sweep(.28,640,140,noise=.05,square=.6,power=1.6))
if '--mob-only' in sys.argv:
 sys.exit(0)

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
