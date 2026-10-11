"""Seeded open world shared by the embedded Studio scene and runtime builder.

No external assets are required. Regenerating with another seed randomises
natural scenery while keeping topology, safe spawns and travel services stable.
"""
from __future__ import annotations
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = 734091
METERS_PER_STUD = 0.28
BIOME_WIDTH, BIOME_DEPTH, GROUND_Y = 1440, 840, 12
BIOMES = [
    ('forest','RỪNG CỔ THỤ',-1440,-840,(61,115,79),(43,94,64),'Grass'),
    ('mountains','NÚI ĐÁ PHA LÊ',0,-840,(137,150,149),(94,111,127),'Rock'),
    ('snow','CAO NGUYÊN TUYẾT',1440,-840,(220,235,237),(153,202,218),'Snow'),
    ('plains','ĐỒNG BẰNG NẮNG',-1440,0,(175,190,102),(126,152,72),'Grass'),
    ('meadow','ĐỒNG CỎ HOA',0,0,(128,184,108),(95,151,90),'Grass'),
    ('river','SÔNG NGỌC LAM',1440,0,(97,166,142),(66,145,153),'Grass'),
    ('swamp','ĐẦM LẦY PHÁT SÁNG',-1440,840,(75,115,94),(95,137,115),'Grass'),
    ('desert','SA MẠC HỔ PHÁCH',0,840,(224,192,128),(193,153,100),'Sand'),
    ('volcano','NÚI LỬA TRO ĐỎ',1440,840,(78,73,86),(118,81,87),'Basalt'),
]


def biome_at(x,z):
    for ident,_,cx,cz,*_ in BIOMES:
        if cx-720 <= x <= cx+720 and cz-420 <= z <= cz+420:
            return ident
    return None


def protected_regions():
    return [
        dict(Biome='river',MinX=1374,MaxX=1506,MinZ=-420,MaxZ=420,Kind='water'),
        dict(Biome='swamp',MinX=-1740,MaxX=-1540,MinZ=910,MaxZ=1030,Kind='swamp'),
        dict(Biome='swamp',MinX=-1155,MaxX=-975,MinZ=620,MaxZ=730,Kind='swamp'),
        dict(Biome='volcano',MinX=1640,MaxX=1820,MinZ=780,MaxZ=1020,Kind='lava'),
        dict(Biome='mountains',MinX=-200,MaxX=220,MinZ=-1190,MaxZ=-970,Kind='landmark'),
        dict(Biome='snow',MinX=1590,MaxX=1840,MinZ=-1180,MaxZ=-960,Kind='landmark'),
        dict(Biome='desert',MinX=310,MaxX=580,MinZ=910,MaxZ=1110,Kind='landmark'),
    ]


def safe_point(x,z,clearance=22):
    if biome_at(x,z) is None:
        return False
    return not any(r['MinX']-clearance < x < r['MaxX']+clearance and
                   r['MinZ']-clearance < z < r['MaxZ']+clearance for r in protected_regions())


def world_config(seed=SEED):
    spawns,foods,biomes=[],[],[]
    for ident,label,cx,cz,color,_,_ in BIOMES:
        biomes.append(dict(Id=ident,Name=label,Center=[cx,GROUND_Y,cz],
                           MinX=cx-720,MaxX=cx+720,MinZ=cz-420,MaxZ=cz+420,
                           Size=[1440,0,840],Color=list(color),AreaSquareMeters=round(1440*840*.28**2,2)))
        for dx in (-688,-568,-448,-328,-208,-88,32,152,272,392,512,688):
            for dz in (-368,-248,-128,-8,112,232,368):
                x,z=cx+dx,cz+dz
                if safe_point(x,z,12):
                    spawns.append(dict(Position=[x,12.1,z],Biome=ident))
        for dx in range(-600,601,150):
            for dz in range(-300,301,150):
                x,z=cx+dx,cz+dz
                if safe_point(x,z):
                    foods.append(dict(Position=[x,12.1,z],Biome=ident))
    return dict(Seed=seed,MetersPerStud=.28,BiomeWidth=1440,BiomeDepth=840,GroundY=12,MapSize=[4320,0,2520],
                RespawnDistanceMeters=200,RespawnDistanceStuds=200/.28,
                BridgeCost=150,TeleportCost=250,Biomes=biomes,
                SafeSpawns=spawns,FoodSpawnPoints=foods,ProtectedRegions=protected_regions(),
                Bridge=dict(Id='river_bridge',X=1440,Z=-205,HalfLength=92,HalfWidth=14),
                Teleports=[dict(Id='meadow',Name='Đồng cỏ',Biome='meadow',Cost=250,Position=[-65,13,-65]),
                           dict(Id='snow',Name='Cao nguyên tuyết',Biome='snow',Cost=250,Position=[1250,13,-700]),
                           dict(Id='volcano',Name='Núi lửa',Biome='volcano',Cost=250,Position=[1260,13,650])])


def descriptors(seed=SEED):
    rng=random.Random(seed)
    records=[]
    config=world_config(seed)
    reserved=config['SafeSpawns']+config['FoodSpawnPoints']
    reserved += [dict(Position=t['Position'],Biome=t['Biome']) for t in config['Teleports']]

    def add(name,size,position,color,**kwargs):
        r=dict(name=name,size=[round(v,3) for v in size],position=[round(v,3) for v in position],
               color=list(color),group='Details')
        r.update(kwargs)
        records.append(r)
        return r

    def text(name,position,title,subtitle='',color=(239,245,219),width=350,height=80):
        return add(name,(1,1,1),position,color,collide=False,transparency=1,
                   billboard=dict(title=title,subtitle=subtitle,width=width,height=height))

    def decoration_position(row,radius=18):
        ident,_,cx,cz,*_=row
        for _ in range(150):
            x,z=rng.uniform(cx-660,cx+660),rng.uniform(cz-360,cz+360)
            if not safe_point(x,z,radius+8):
                continue
            if ident=='meadow' and math.hypot(x,z)<90:
                continue
            if ident=='river' and (abs(z+205)<36 or abs(z-155)<30):
                continue
            if any(math.hypot(x-p['Position'][0],z-p['Position'][2]) < radius+18
                   for p in reserved if p['Biome']==ident):
                continue
            return x,z
        return None

    def tree(prefix,x,z,color,height=28,pine=False,willow=False):
        # A few overlapping, tilted boxes make an angular organic silhouette.
        # Only the central trunk collides: branches/crowns cannot obstruct food
        # or catch a tall evolved animal beneath the canopy.
        yaw=rng.uniform(0,360)
        lean=rng.uniform(-4,4)
        thickness=height*rng.uniform(.075,.095)
        bark=(101,79,64) if willow else (116,85,62)
        add(prefix+'Trunk',(thickness,height*.65,thickness*.88),
            (x,12+height*.31,z),bark,material='Wood',rotation=(0,yaw,lean))
        add(prefix+'RootFlare',(thickness*1.55,height*.12,thickness*1.35),
            (x,12+height*.035,z),tuple(max(0,c-12) for c in bark),
            material='Wood',rotation=(0,yaw+12,0))
        heading=math.radians(yaw)
        for side in (-1,1):
            add(prefix+f'Branch{side}',(thickness*.63,height*.38,thickness*.63),
                (x+side*math.cos(heading)*height*.1,12+height*.61,
                 z-side*math.sin(heading)*height*.1),
                tuple(min(255,c+side*5) for c in bark),material='Wood',
                rotation=(0,yaw,-side*38),collide=False)
        if pine:
            for layer in range(3):
                width=height*(.58-layer*.13)
                tint=tuple(min(255,c+layer*12) for c in color)
                cy=12+height*(.58+layer*.19)
                add(prefix+f'Needles{layer}',(width,height*.24,width*.84),
                    (x,cy,z),tint,rotation=(layer*3-3,yaw+layer*21,layer*2-2),collide=False)
                add(prefix+f'NeedleFacet{layer}',(width*.62,height*.22,width*.6),
                    (x,cy+height*.135,z),tuple(min(255,c+12) for c in tint),
                    class_name='WedgePart',rotation=(0,yaw+layer*21,0),collide=False)
        else:
            clusters=((0,0,1,.91),(-.24,.13,.78,.76),(.25,-.12,.82,.80))
            for branch,(dx,dz,s,cy) in enumerate(clusters):
                tint=tuple(min(255,c+branch*12) for c in color)
                rotation=(rng.uniform(-9,9),yaw+branch*24,rng.uniform(-9,9))
                add(prefix+f'Crown{branch}',(height*.66*s,height*.43*s,height*.6*s),
                    (x+dx*height,12+height*cy,z+dz*height),tint,
                    rotation=rotation,collide=False)
                if branch != 1:
                    add(prefix+f'CrownFacet{branch}',(height*.36*s,height*.16*s,height*.36*s),
                        (x+dx*height,12+height*(cy+.24*s),z+dz*height),
                        tuple(min(255,c+10) for c in tint),class_name='WedgePart',
                        rotation=(0,yaw+branch*24,0),collide=False)
            if willow:
                for strand in range(5):
                    a=strand*math.pi*2/5
                    length=height*rng.uniform(.37,.57)
                    add(prefix+f'Drape{strand}',(height*.075,length,height*.1),
                        (x+math.cos(a)*height*.29,12+height*.78-length/2,z+math.sin(a)*height*.29),
                        tuple(min(255,c+18) for c in color),
                        rotation=(rng.uniform(-5,5),math.degrees(a),rng.uniform(-5,5)),collide=False)

    def rocks(prefix,x,z,color,scale=1):
        yaw=rng.uniform(0,360)
        sx,sy,sz=rng.uniform(7,11)*scale,rng.uniform(5,9)*scale,rng.uniform(6,10)*scale
        add(prefix+'Core',(sx,sy,sz),(x,12+sy/2-.7*scale,z),color,
            material='Rock',rotation=(rng.uniform(-8,8),yaw,rng.uniform(-8,8)))
        # Offset companion and exposed wedge faces avoid identical perfect cubes.
        add(prefix+'Shoulder',(sx*.62,sy*.66,sz*.7),(x+sx*.42,12+sy*.27,z+sz*.2),
            tuple(min(255,c+10) for c in color),material='Rock',rotation=(5,yaw+24,-7))
        add(prefix+'Facet0',(sx*.78,sy*.45,sz*.8),(x,12+sy*.91,z),
            tuple(min(255,c+20) for c in color),class_name='WedgePart',
            material='Rock',rotation=(0,yaw,0))
        add(prefix+'Facet1',(sx*.55,sy*.5,sz*.62),(x-sx*.36,12+sy*.19,z-sz*.12),
            tuple(max(0,c-11) for c in color),class_name='WedgePart',
            material='Rock',rotation=(0,yaw+90,0))

    for row in BIOMES:
        ident,label,cx,cz,ground,accent,material=row
        if ident=='river':
            for iz in range(3):
                for side in (-1,1):
                    add(f'Ground_river_{iz}_{side}',(654,30,280),(cx+side*393,-3,cz-280+iz*280),
                        ground,group='GroundTerrain',material=material)
        else:
            for ix in range(4):
                for iz in range(3):
                    color=tuple(max(0,min(255,c+rng.randint(-4,4))) for c in ground)
                    add(f'Ground_{ident}_{ix}_{iz}',(360,30,280),(cx-540+ix*360,-3,cz-280+iz*280),
                        color,group='GroundTerrain',material=material)
        for n in range(28):
            p=decoration_position(row,7)
            if p:
                x,z=p
                add(f'{ident}_Moss{n}',(rng.uniform(18,45),.16,rng.uniform(16,38)),(x,12.03,z),
                    tuple(max(0,min(255,c+rng.randint(-10,10))) for c in accent),
                    rotation=(0,rng.uniform(-35,35),0),collide=False,material=material)
        text('BiomeLabel_'+ident,(cx-500,32,cz-250),label,'Khám phá · tìm thức ăn · tiến hóa',tuple(min(255,c+55) for c in accent))
        trees={'forest':135,'meadow':28,'plains':21,'mountains':12,'snow':42,'river':35,'swamp':44,'desert':0,'volcano':0}[ident]
        for n in range(trees):
            p=decoration_position(row,18)
            if p:
                green=(50,108,75) if ident=='forest' else (51,109,91) if ident=='snow' else (95,143,88)
                tree(f'{ident}_Tree{n}_',*p,green,rng.uniform(22,45),pine=ident in ('snow','mountains'),willow=ident=='swamp')
        for n in range(42 if ident in ('mountains','volcano','desert') else 20):
            p=decoration_position(row,18)
            if p:
                rocks(f'{ident}_Rock{n}_',*p,(93,104,107) if ident not in ('volcano','desert') else accent,rng.uniform(.7,2.2))
        for n in range(35 if ident in ('meadow','forest','plains','river') else 12):
            p=decoration_position(row,4)
            if not p:
                continue
            x,z=p
            if ident in ('volcano','mountains','snow'):
                for shard in range(3):
                    add(f'{ident}_Crystal{n}_{shard}',(2.6,7+shard*2.5,2.6),(x+shard*2.5,16+shard,z),
                        (113,221,237) if ident!='volcano' else (255,116,55),material='Neon',class_name='WedgePart',rotation=(0,shard*60,8),collide=False)
            elif ident=='desert':
                add(f'desert_Cactus{n}',(3,12,3),(x,18,z),(83,137,92),rotation=(0,12,0))
                add(f'desert_CactusArm{n}',(6,2,2),(x+2,18,z),(92,147,98),collide=False)
            else:
                palette=((248,183,204),(244,220,144),(200,172,238),(254,241,205))
                for b in range(3):
                    fx,fz=x+b*1.8,z+(b%2)*2
                    add(f'{ident}_Flower{n}_{b}_Stem',(.3,1.8,.3),(fx,12.9,fz),(81,135,82),collide=False)
                    add(f'{ident}_Flower{n}_{b}_Petals',(2,.65,2),(fx,13.9,fz),palette[(n+b)%4],shape='Ball',collide=False)
                    add(f'{ident}_Flower{n}_{b}_Pollen',(.5,.3,.5),(fx,14.3,fz),(255,225,126),shape='Ball',collide=False)

    def mountain(prefix,x,z,width,depth,height,color):
        for side in range(4):
            # Four triangular slopes enclose a broad mountain rather than a cuboid.
            add(prefix+f'Slope{side}',(width if side%2==0 else depth,height,depth/2 if side%2==0 else width/2),
                (x+(width/4 if side==1 else -width/4 if side==3 else 0),12+height/2,
                 z+(depth/4 if side==0 else -depth/4 if side==2 else 0)),
                tuple(min(255,c+side*6) for c in color),material='Rock',class_name='WedgePart',rotation=(0,side*90+180,0))
    mountain('RockySummit',0,-1080,360,180,116,(94,107,118))
    mountain('IcePeak',1715,-1070,220,180,145,(183,210,223))
    add('IcePeakSnowcap',(95,45,90),(1715,155,-1070),(239,248,255),class_name='WedgePart',material='Snow')
    mountain('AmberMesa',445,1010,235,175,70,(191,130,91))
    add('AmberMesaCap',(130,6,105),(445,84,1010),(226,164,99),material='Sand')
    mountain('VolcanicCrater',1730,900,170,220,82,(73,61,72))
    add('CraterCore',(95,78,105),(1730,51,900),(70,59,67),material='Basalt')
    add('CraterLava',(105,3,115),(1730,91,900),(255,102,34),group='Hazards',material='Neon',kind='lava',collide=False)
    for f in range(5):
        add(f'LavaFissure{f}',(5,1,48),(1690+f*19,12.5,800+f*38),(255,116,36),group='Hazards',material='Neon',kind='lava',collide=False,rotation=(0,30-f*11,0))
    for n,r in enumerate(protected_regions()[1:3]):
        x,z=(r['MinX']+r['MaxX'])/2,(r['MinZ']+r['MaxZ'])/2
        add(f'MarshPool{n}',(r['MaxX']-r['MinX'],.45,r['MaxZ']-r['MinZ']),(x,12.3,z),
            (75,151,144),material='Glass',transparency=.25,collide=False,group='Hazards',kind='swamp')
        for pad in range(9):
            px,pz=x+rng.uniform(-70,70),z+rng.uniform(-40,40)
            add(f'LilyPad{n}_{pad}',(.35,7,6),(px,12.7,pz),(107,162,110),shape='Cylinder',rotation=(0,0,90),collide=False)
            add(f'LilyBloom{n}_{pad}',(2,1.1,2),(px,13.4,pz),(232,176,228),shape='Ball',collide=False)
    add('RiverBed',(132,8,840),(1440,-12,0),(61,102,114),group='GroundTerrain',material='Rock')
    add('RiverWater',(132,2,840),(1440,9,0),(67,168,192),group='Hazards',material='Glass',kind='water',collide=False,transparency=.25)
    for r in range(24):
        add(f'RiverRipple{r}',(rng.uniform(10,22),.1,1.4),(1440+rng.uniform(-48,48),10.04,-390+r*33),
            (164,235,242),material='Neon',collide=False,transparency=.55,rotation=(0,-15,0))
    for n in range(7):
        # Angular stepping stones retain the same flat landing top and 4stud gap.
        add(f'RiverStep{n}',(18,3,24),(1374+n*22,12.5,155),(113+n*4,129+n*3,137+n*3),
            group='Crossings',material='Rock')
        add(f'RiverStepFacet{n}',(6,2,11),(1369+n*22,12,160),
            (94+n*4,114+n*3,124+n*3),group='Crossings',material='Rock',
            class_name='WedgePart',rotation=(0,180,0),collide=False)
    text('FreeCrossingSign',(1332,23,155),'ĐÁ BƯỚC · LỐI QUA MIỄN PHÍ','Nhảy qua đá · rơi xuống nước sẽ bị cuốn đi',width=360)
    add('PaidBridgeDeck',(184,2,28),(1440,13,-205),(125,92,70),group='Crossings',material='WoodPlanks',kind='bridge')
    for n in range(23):
        add(f'BridgePlank{n}',(7.5,.35,27),(1352+n*8,14.2,-205),(156+n%3*8,115+n%3*5,78),group='Crossings',material='WoodPlanks')
    for side in (-1,1):
        add(f'BridgeRailing{side}',(184,1.2,1.2),(1440,18,-205+side*14),(101,78,65),group='Crossings',material='Wood')
        for n in range(7):
            add(f'BridgePost{side}_{n}',(2,7,2),(1354+n*28,16.5,-205+side*14),(112,82,64),group='Crossings',material='Wood')
        x=1440+side*105
        add(f'BridgeToll{side}',(6,9,4),(x,16.5,-218),(188,151,91),group='Travel',material='Wood',kind='bridge_toll',bridge='river_bridge',side=side,
            prompt=dict(action='Qua cầu · 150 Coins',object='Cầu Thương Gia',distance=15))
        text(f'BridgeSign{side}',(x,28,-211),'CẦU THƯƠNG GIA','150 Coins · đi an toàn qua sông',(255,221,145),300,75)
    for t in config['Teleports']:
        ident=t['Id'];x,y,z=t['Position']
        add('PortalBase_'+ident,(26,2,26),(x,12,z),(97,109,124),group='Travel',material='Slate')
        add('Teleport_'+ident,(17,.6,17),(x,13.4,z),(117,226,232),group='Travel',material='Neon',collide=False,
            kind='teleport',id=ident,biome=t['Biome'],cost=250,prompt=dict(action='Dịch chuyển · 250 Coins',object='Cổng du hành',distance=16))
        for side in (-1,1):
            add(f'PortalPillar_{ident}_{side}',(3,18,3),(x+side*11,22,z),(166,184,197),group='Travel',material='Marble')
            add(f'PortalRune_{ident}_{side}',(1.3,12,.2),(x+side*11,23,z-1.6),(129,240,232),group='Travel',material='Neon',collide=False)
        add('PortalLintel_'+ident,(27,3,4),(x,32,z),(136,163,180),group='Travel',material='Marble')
        text('PortalLabel_'+ident,(x,38,z),'CỔNG DU HÀNH','250 Coins · đến cổng tiếp theo',(163,244,247),300,75)
    add('SpawnStoneCircle',(.7,37,37),(0,12.2,0),(164,190,155),group='GroundTerrain',shape='Cylinder',rotation=(0,0,90),material='Slate')
    add('StartSpawn',(16,1,16),(0,13,0),(151,211,143),group='Travel',class_name='SpawnLocation',kind='spawn',material='Grass',transparency=.15)
    for n in range(12):
        a=n*math.pi/6
        add(f'SpawnPetal{n}',(2,.2,3),(math.cos(a)*16,12.9,math.sin(a)*16),(230,241,203),collide=False,rotation=(0,-n*30,0))
    text('WelcomeSign',(0,29,-24),'EVOLUTION WILDS','Ăn · khám phá 9 quần xã · tiến hóa tại 100% độ no',(239,249,209),480,92)
    text('Instructions',(34,21,9),'THẾ GIỚI MỞ 360°','WASD di chuyển · Space nhảy · tìm thức ăn quanh bạn',(245,238,193),410,75)
    # Split invisible boundaries stay within Roblox's 2048-stud part size limit.
    # They prevent accidental falls into an unrendered void outside the landscape.
    for side in (-1,1):
        for section in range(4):
            add(f'WorldBoundaryZ{side}_{section}',(1080,180,2),(-1620+section*1080,70,side*1260),
                (0,0,0),group='Boundaries',transparency=1)
        for section in range(2):
            add(f'WorldBoundaryX{side}_{section}',(2,180,1260),(side*2160,70,-630+section*1260),
                (0,0,0),group='Boundaries',transparency=1)
    return records


def _lua(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,(list,tuple)):return '{'+','.join(_lua(x) for x in v)+'}'
    return '{'+','.join(f'{k}={_lua(x)}' for k,x in v.items())+'}'


def write_layout(output=None,seed=SEED):
    output=output or ROOT/'src/shared/WorldLayout.luau'
    output.write_text('-- Generated by tools/world_assets.py. Edit the canonical descriptors, then rebuild.\nreturn {\n'+
                      '\n'.join(' '+_lua(r)+',' for r in descriptors(seed))+'\n}\n',encoding='utf-8')
    (ROOT/'src/shared/WorldConfig.luau').write_text('-- Generated map metadata. Distances use 1 stud = 0.28 metres.\nreturn '+_lua(world_config(seed))+'\n',encoding='utf-8')
    return output

if __name__=='__main__':
    print(write_layout())
