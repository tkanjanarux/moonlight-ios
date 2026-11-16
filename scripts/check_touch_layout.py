from pathlib import Path
import re,itertools
s=Path('Limelight/Input/HogwartsControls.m').read_text(encoding='utf-8')
rows=re.findall(r'@\[@"(\w+)", @"[^"]+", @"[^"]+", @(\d),@(\d+),@(\d+),@(\d+),@(\d)\]',s)
assert len(rows)==30,len(rows)
for w,h,l,r,t,b in [(951,669,0,0,0,21),(951,669,62,62,0,21),(852,393,59,59,0,21),(667,375,0,0,0,0)]:
 u=min((w-l-r-8)/157.7,(h-t-b-8)/88)
 for drawer in (False,True):
  frames=[]
  edge=min(float(x)-float(d)/2 for _,right,x,y,d,extra in rows if int(right) and bool(int(extra))==drawer)
  for name,right,x,y,d,extra in rows:
   right,x,y,d,extra=map(int,(right,x,y,d,extra))
   if (extra and not drawer) or (not extra and right and drawer):continue
   cx=w-8-(x-edge)*u if right else l+4+x*u
   cy=h-b-4-y*u;diam=d*u
   f=(cx-diam/2,cy-diam/2,cx+diam/2,cy+diam/2)
   assert f[0]>=l and f[1]>=t and f[2]<=w-8+1e-6 and f[3]<=h-b,(name,f)
   frames.append((name,f))
  assert abs(max(f[2] for _,f in frames)-(w-8))<1e-6
  for (an,a),(bn,bf) in itertools.combinations(frames,2):
   assert not (max(a[0],bf[0])<min(a[2],bf[2]) and max(a[1],bf[1])<min(a[3],bf[3])),(w,h,drawer,an,bn)
print('PASS: 30 controls; no hit-box overlap or unsafe bounds in 8 layout states')
