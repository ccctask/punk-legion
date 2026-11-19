"""Original PunkLegion industrial toy sound cues, generated without external samples."""
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / "game" / "audio"
RATE = 22050
TAU = math.tau

def print_wav(name, duration, synth, peak, loop=False):
    values = [synth(i/RATE) for i in range(round(duration*RATE))]
    gain = peak * 32767 / max(abs(x) for x in values)
    path = ROOT / (name+".wav")
    with wave.open(str(path), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack("<"+"h"*len(values), *(round(x*gain) for x in values)))
    if loop:
        content = bytearray(path.read_bytes())
        loop_chunk = struct.pack("<15I", 0,0,round(1e9/RATE),60,0,0,0,1,0, 0,0,0,len(values)-1,0,0)
        content.extend(b"smpl"+struct.pack("<I",len(loop_chunk))+loop_chunk)
        struct.pack_into("<I",content,4,len(content)-8)
        path.write_bytes(content)

def tread(t):
    sound = 0
    for onset, pitch, gain in [(0.02,370,1),(.080,720,.32),(.235,305,.8),(.302,620,.35)]:
        age=t-onset
        if 0<=age<.11:
            pulse=(1-math.exp(-age*850))*math.exp(-age*60)
            sound+=gain*pulse*(math.sin(TAU*pitch*age)+.32*math.sin(TAU*pitch*2.71*age))
    return sound

def steam(t):
    global filtered, previous
    noise=RNG.uniform(-1,1)
    filtered=.70*filtered+.30*noise
    hiss=filtered-previous
    previous=.94*previous+.06*filtered
    body=math.sin(TAU*(120*t+52*(1-math.exp(-t*14))/14))
    tail=max(0,1-t/.30)**2
    return min(1,t/.009)*tail*(.65*hiss+.19*body*math.exp(-t*22))

def danger(t):
    hit=0
    for start,hz in [(0.015,625),(.15,835)]:
        age=t-start
        if 0<=age<.15:
            env=math.sin(math.pi*age/.15)**1.4
            hit+=env*(math.sin(TAU*hz*age)+.22*math.sin(TAU*hz*1.5*age))
    return hit

RNG=random.Random(19716)
filtered=previous=0.0
print_wav("tread",.455,tread,.43,loop=True)
print_wav("steam",.30,steam,.57)
print_wav("danger",.33,danger,.58)

def heel(t):
    # Hollow boot sole followed by a shorter brass hinge click.
    sole = (1-math.exp(-t*650))*math.exp(-t*32)*math.sin(TAU*(106*t+1.2*(1-math.exp(-t*20))))
    hinge = max(0,t-.026)
    click = (1-math.exp(-hinge*830))*math.exp(-hinge*58)*math.sin(TAU*538*hinge)
    return sole+.34*click

print_wav("heel",.19,heel,.51)
