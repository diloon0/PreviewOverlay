import sys
from PIL import Image
# 17x17 design, scaled x2 (34px, 1x) and x4 (68px, 2x).
# B body (lightened Spades), D wing shade, E eye (beak colour), K beak, . clear
ART = """
......BBBB.......
.....BBBBBB......
....BBBBBBBB.....
....BBEBBBBB.....
KKKKBBBBBBBB.....
.KKKBBBBBBBBB....
...BBBBBBBBBB....
...BBBBBBBBBBB...
...BBBBBBBBBBB...
...BBBBDDDDBBBB..
...BBBDDDDDDBBB..
...BBBDDDDDDDBB..
...BBBBDDDDDDDB..
...BBBBDDDDDDDBB.
....BBBBDDDDDDDB.
....BBBBBDDDDDDBB
....BBBBBBDDDDDDB
""".strip().splitlines()
body=(0x9e,0x8e,0xd8,255); shade=(0x6e,0x5c,0xb8,255); eye=(0x4a,0x3c,0x8a,255); beak=(0x4a,0x3c,0x8a,255)
pal={'B':body,'D':shade,'E':eye,'K':beak}
assert all(len(r)==17 for r in ART) and len(ART)==17
base=Image.new('RGBA',(17,17),(0,0,0,0))
for y,r in enumerate(ART):
    for x,ch in enumerate(r):
        if ch in pal: base.putpixel((x,y),pal[ch])
out=sys.argv[1]
base.resize((34,34),Image.NEAREST).save(out+'/1x.png')
base.resize((68,68),Image.NEAREST).save(out+'/2x.png')
prev=Image.new('RGBA',(272,272),(0,0,0,0)); big=base.resize((272,272),Image.NEAREST); prev.alpha_composite(big); prev.save(out+'/preview.png')
