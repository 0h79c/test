"""Canonical, original animal geometry used by both Studio XML and Luau.

No mesh, texture or marketplace assets are needed. Run this file after editing
geometry to regenerate src/shared/AnimalModels.luau.
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
WHITE = (248, 245, 233)
BLACK = (30, 34, 44)


class Animal:
    def __init__(self, name, collision):
        self.name, self.collision, self.parts = name, collision, []

    def add(self, name, size, pos, color, shape="Ball", rotation=(0, 0, 0),
            motion="", phase=0, material="SmoothPlastic", class_name="Part"):
        self.parts.append(dict(name=name, size=size, position=pos, color=color,
                               shape=shape, rotation=rotation, motion=motion,
                               phase=phase, material=material, class_name=class_name))

    def rod(self, name, start, end, width, color, motion="", phase=0):
        # Ellipsoids make soft, tapered cartoon limbs without imported meshes.
        start, end = tuple(start), tuple(end)
        delta = [end[i] - start[i] for i in range(3)]
        length = math.sqrt(sum(v * v for v in delta))
        midpoint = tuple((start[i] + end[i]) / 2 for i in range(3))
        # CFrame.Angles applies Rx * Ry * Rz. Solve that Euler basis directly
        # rather than conventional yaw/pitch, otherwise diagonal rods detach.
        yaw = math.degrees(math.asin(max(-1, min(1, delta[0] / length))))
        pitch = math.degrees(math.atan2(-delta[1], delta[2]))
        self.add(name, (width, width, length + width / 2), midpoint, color,
                 rotation=(pitch, yaw, 0), motion=motion, phase=phase)

    def eyes(self, x, y, z, size=.32, wide=False):
        for side in (-1, 1):
            self.add("EyeWhite", (size, size * 1.15, size * .6), (side*x, y, z), WHITE)
            self.add("Pupil", (size*.55, size*.72, size*.4), (side*x, y, z-size*.25), BLACK)
            self.add("EyeSpark", (size*.19, size*.19, size*.13),
                     (side*x-size*.11, y+size*.19, z-size*.45), (255, 255, 255))

    def paws(self, body_color, x=.63, front=-1.1, back=.85, y=.65):
        for side in (-1, 1):
            for n, z in enumerate((front, back)):
                phase = side if n else -side
                self.add("Leg", (.5, y+.1, .55), (side*x, y/2+.1, z), body_color,
                         motion="Leg", phase=phase)
                self.add("Paw", (.58, .24, .75), (side*x, .16, z-.14), body_color,
                         motion="Leg", phase=phase)


def _snail():
    a = Animal("Snail", (1.85, 1.9, 3.4))
    skin, shell, ridge = (180, 213, 106), (190, 133, 76), (116, 72, 46)
    a.add("Foot", (2.1, .45, 3.9), (0, .25, .1), skin)
    a.add("Head", (1.15, .9, .9), (0, .62, -1.3), skin)
    a.add("Shell", (1.95, 2.0, 2.0), (0, 1.25, .45), shell)
    # Two visible spirals on the sides of the shell, actual geometry.
    for side in (-1, 1):
        for step in range(23):
            t = step / 22
            theta = t * math.pi * 3.7
            radius = .08 + t*.78
            a.add("ShellSpiral", (.11, .16, .16),
                  (side*.95, 1.25+math.sin(theta)*radius, .45+math.cos(theta)*radius), ridge)
        start, end = (side*.37, .93, -1.42), (side*.53, 1.72, -1.67)
        a.rod("EyeStalk", start, end, .12, skin)
        a.add("StalkEye", (.37, .37, .37), end, WHITE)
        a.add("Pupil", (.2, .23, .12), (side*.53, 1.74, -1.84), BLACK)
        a.rod("Feeler", (side*.32, .6, -1.65), (side*.65, .75, -1.94), .09, skin)
    a.add("Smile", (.4, .055, .09), (0, .56, -1.74), ridge)
    return a


def _caterpillar():
    a = Animal("Caterpillar", (1.7, 1.3, 4.0))
    greens = ((88, 180, 82), (133, 208, 87), (183, 220, 89))
    for n in range(6):
        z = -1.6 + n*.64
        a.add("Segment", (1.42-n*.045, 1.15, .96), (0, .72, z), greens[n%3], motion="Segment", phase=n)
        for side in (-1, 1):
            a.add("TinyFoot", (.31, .31, .42), (side*.54, .17, z), (52, 126, 68),
                  motion="Leg", phase=(-1 if n%2 else 1)*side)
            if n > 0:
                a.add("SideDot", (.12, .22, .24), (side*.66, .72, z), (241, 221, 110))
    a.eyes(.36, 1, -2.13, .38)
    for side in (-1, 1):
        a.rod("Antenna", (side*.34, 1.1, -1.75), (side*.57, 1.72, -1.82), .12, (55, 108, 64))
        a.add("AntennaTip", (.24, .24, .24), (side*.57, 1.72, -1.82), (244, 193, 71))
    return a


def _mouse():
    a = Animal("Mouse", (1.7, 1.6, 2.8))
    gray, pink = (150, 163, 180), (235, 160, 174)
    a.add("Body", (1.9, 1.35, 2.3), (0, .91, .22), gray)
    a.add("Belly", (1.1, .46, 1.6), (0, .43, -.1), (218, 222, 225))
    a.add("Head", (1.32, 1.12, 1.27), (0, 1.2, -1.02), gray)
    for side in (-1, 1):
        a.add("RoundEar", (.82, .9, .24), (side*.58, 1.87, -.85), gray, rotation=(0, side*12, side*-14))
        a.add("EarInside", (.6, .64, .12), (side*.58, 1.9, -.99), pink, rotation=(0, side*12, side*-14))
        for n in range(3):
            a.rod("Whisker", (side*.36, 1.08, -1.57), (side*1.12, 1+(n-1)*.13, -1.68), .035, WHITE)
    a.eyes(.4, 1.37, -1.57, .27)
    a.add("Nose", (.24, .18, .21), (0, 1.02, -1.69), pink)
    a.paws(pink, .62, -.7, .88, .38)
    path = ((0,.57,1.15), (.5,.42,1.8), (.85,.35,2.24), (.9,.48,2.72), (.6,.65,2.92))
    for i in range(len(path)-1):
        a.rod("Tail", path[i], path[i+1], .15, pink, "Tail", i)
    return a


def _frog():
    a = Animal("Frog", (2.35, 1.65, 2.5))
    green, belly = (63, 176, 102), (194, 222, 115)
    a.add("Body", (2.2, 1.3, 2.2), (0, .88, .3), green)
    a.add("Belly", (1.5, .8, 1.36), (0, .66, -.55), belly)
    a.add("Head", (2.1, .94, 1.38), (0, 1.08, -.79), green)
    for side in (-1, 1):
        a.add("EyeBulge", (.73, .76, .65), (side*.67, 1.63, -.78), green)
        a.add("BackThigh", (.95, .7, 1.25), (side*1.12, .5, .82), green)
        a.rod("FrontArm", (side*.77,.82,-.6), (side*1.08,.18,-1.32), .27, green, "Leg", side)
        for n in range(3):
            a.add("FrontToe", (.18,.12,.57), (side*(.86+n*.2),.09,-1.55), belly, motion="Leg", phase=side)
            a.add("BackToe", (.2,.12,.65), (side*(1+n*.18),.09,1.15), belly, motion="Leg", phase=-side)
        a.add("Freckle", (.11,.13,.2), (side*.81,1.13,-1.37), (36, 125, 78))
    a.eyes(.67, 1.69, -1.1, .48)
    a.add("Mouth", (1.1,.07,.09), (0,.94,-1.46), (39,104,67))
    return a


def _turtle():
    a = Animal("Turtle", (2.65, 1.75, 3.3))
    green, shell, rim = (141, 176, 108), (67, 125, 86), (203, 182, 102)
    a.add("ShellRim", (3.08,.4,3.2), (0,.74,.18), rim)
    a.add("Shell", (2.92,1.72,3.05), (0,1.17,.2), shell)
    for z in (-.72,.15,1):
        a.add("ShellScute", (1.13,.14,.74), (0,1.97 if z==.15 else 1.82,z), (94,151,99))
        for side in (-1,1):
            a.add("ShellScuteSide", (.13,.47,.68), (side*1.3,1.33,z), (101,157,91), rotation=(0,0,side*-24))
    a.add("Neck", (.75,.66,.98), (0,.69,-1.51), green)
    a.add("Head", (.97,.75,.89), (0,.86,-1.95), green)
    a.eyes(.29,1.03,-2.32,.25)
    a.paws(green,1.1,-.83,.99,.5)
    a.rod("Tail", (0,.5,1.6), (0,.34,2.13), .18, green)
    return a


def _rabbit():
    a = Animal("Rabbit", (1.9,2.1,2.6))
    fur, pink = (229, 218, 203), (231, 153, 157)
    a.add("Body", (1.98,1.64,2.04), (0,1.03,.22), fur)
    a.add("Chest", (1.1,1.33,1.03), (0,1.07,-.82), WHITE)
    a.add("Head", (1.31,1.24,1.22), (0,1.55,-1.1), fur)
    for side in (-1,1):
        a.add("LongEar", (.42,1.65,.34), (side*.38,2.77,-.96), fur, rotation=(0,0,side*-12))
        a.add("EarInside", (.22,1.25,.15), (side*.38,2.77,-1.14), pink, rotation=(0,0,side*-12))
        a.add("Haunch", (.87,1.1,1.08), (side*.71,.57,.67), fur)
        a.add("HindPaw", (.56,.31,1.13), (side*.74,.18,.43), WHITE, motion="Leg",phase=-side)
        a.add("ForePaw", (.38,.86,.45), (side*.46,.47,-.89), WHITE,motion="Leg",phase=side)
        a.add("Muzzle", (.52,.42,.4), (side*.22,1.38,-1.58), WHITE)
    a.eyes(.36,1.71,-1.64,.27)
    a.add("Nose", (.21,.17,.19), (0,1.47,-1.86), pink)
    a.add("CottonTail", (.65,.66,.63), (0,1.12,1.25), WHITE, motion="Tail")
    return a


def _cat():
    a = Animal("Cat", (1.8,2.1,3))
    fur, stripe = (237,174,88), (149,86,47)
    a.add("Body", (1.64,1.42,2.34), (0,1.17,.22), fur)
    a.add("Chest", (1.1,1.19,.68), (0,1.09,-.93), WHITE)
    a.add("Head", (1.5,1.33,1.28), (0,1.78,-1.06), fur)
    for side in (-1,1):
        a.add("PointEar", (.56,.73,.47), (side*.53,2.46,-.9), fur, rotation=(0,side*20,side*-10),class_name="WedgePart",shape="Block")
        a.add("EarPink", (.26,.39,.1), (side*.53,2.45,-1.14), (226,145,145),class_name="WedgePart",shape="Block")
        for n in range(3):
            a.add("TabbyStripe", (.13,.68,.18), (side*.76,1.37,.95-n*.55), stripe,rotation=(0,0,side*-20))
            a.rod("Whisker", (side*.3,1.56,-1.65), (side*.99,1.59+(n-1)*.15,-1.77), .03, WHITE)
        a.add("Muzzle", (.5,.36,.43), (side*.22,1.52,-1.58), WHITE)
    a.eyes(.42,1.86,-1.61,.32)
    a.add("Nose", (.21,.17,.17), (0,1.64,-1.82), (221,137,142))
    a.paws(fur,.56,-.9,.94,.93)
    path = ((0,1.3,1.25),(.3,1.7,1.92),(.45,2.36,2.12),(.23,2.76,1.92))
    for i in range(3): a.rod("Tail",path[i],path[i+1],.27,fur,"Tail",i)
    a.add("TailTip",(.28,.29,.34),path[-1],stripe,motion="Tail")
    return a


def _hound():
    a = Animal("Hound", (2,2.15,3.75))
    tan, brown = (200,139,86),(102,65,48)
    a.add("Body", (1.77,1.45,2.75), (0,1.43,.18),tan)
    a.add("Saddle", (1.56,.76,1.86), (0,1.9,.32),brown)
    a.add("Chest", (1.08,1.46,.67), (0,1.31,-1),WHITE)
    a.add("Neck", (1.02,1.3,.95), (0,1.84,-1.1),tan,rotation=(-20,0,0))
    a.add("Head", (1.15,1.12,1.25), (0,2.22,-1.45),tan)
    a.add("LongMuzzle", (.85,.61,1.06), (0,1.98,-2.12),WHITE)
    a.add("Nose", (.6,.36,.31), (0,2.08,-2.65),BLACK)
    for side in (-1,1):
        a.add("FloppyEar", (.45,1.02,.77), (side*.66,1.98,-1.34),brown,rotation=(0,0,side*12))
    a.eyes(.32,2.38,-2,.26)
    a.paws(tan,.61,-.97,1.14,1.26)
    a.rod("RaisedTail",(0,1.72,1.54),(.13,2.25,2.28),.24,brown,"Tail")
    a.add("TailTip",(.27,.3,.42),(.13,2.25,2.28),WHITE,motion="Tail")
    a.add("Collar",(1.12,.2,.96),(0,1.94,-1.12),(61,139,182))
    a.add("Tag",(.22,.28,.08),(0,1.67,-1.65),(250,200,90),material="Metal")
    return a


def _monkey():
    a = Animal("Monkey", (1.9,2.5,2.2))
    fur, face = (148,96,63),(225,183,136)
    a.add("Body",(1.4,1.85,1.25),(0,1.47,.2),fur)
    a.add("Belly",(.98,1.22,.46),(0,1.35,-.43),face)
    a.add("Head",(1.43,1.42,1.36),(0,2.59,-.16),fur)
    a.add("Face",(1.1,.89,.6),(0,2.51,-.78),face)
    a.add("Muzzle",(.81,.45,.5),(0,2.27,-.98),face)
    for side in (-1,1):
        a.add("RoundEar",(.6,.66,.28),(side*.83,2.67,-.09),fur)
        a.add("EarInside",(.37,.4,.11),(side*.85,2.68,-.25),face)
        a.rod("LongArm",(side*.68,1.92,.16),(side*1.14,.76,-.37),.4,fur,"Leg",side)
        a.add("Hand",(.44,.5,.52),(side*1.14,.55,-.43),face,motion="Leg",phase=side)
        a.add("Leg",(.48,.72,.54),(side*.43,.58,.23),fur,motion="Leg",phase=-side)
        a.add("Foot",(.51,.25,.73),(side*.43,.14,-.04),face,motion="Leg",phase=-side)
    a.eyes(.3,2.64,-1.07,.26)
    a.add("Nose",(.25,.13,.1),(0,2.4,-1.26),(112,76,57))
    points=((0,1.08,.77),(.57,.92,1.5),(1.03,1.34,1.88),(1,1.99,1.74),(.61,2.23,1.55))
    for n in range(4): a.rod("CurledTail",points[n],points[n+1],.21,fur,"Tail",n)
    return a


def _cheetah():
    a = Animal("Cheetah", (1.8,2.2,3.55))
    gold = (232,190,84)
    a.add("LeanBody",(1.34,1.18,2.85),(0,1.71,.19),gold)
    a.add("Belly",(.91,.51,2.15),(0,1.29,.12),WHITE)
    a.add("Chest",(1.05,1.34,.92),(0,1.58,-.98),gold)
    a.add("Neck",(.83,1.01,.83),(0,2.07,-1.15),gold)
    a.add("Head",(1.01,1.03,1.03),(0,2.43,-1.45),gold)
    a.add("Muzzle",(.69,.36,.56),(0,2.19,-1.91),WHITE)
    a.add("Nose",(.28,.15,.15),(0,2.27,-2.19),BLACK)
    for side in (-1,1):
        a.add("Ear",(.36,.42,.2),(side*.37,2.97,-1.35),BLACK)
        a.add("EarInside",(.23,.25,.11),(side*.37,2.98,-1.47),gold)
        a.add("TearMark",(.11,.43,.07),(side*.34,2.31,-1.97),BLACK,rotation=(0,0,side*-18))
        for n in range(16):
            z = -1.02+(n%6)*.44
            y = 1.45+(n//6)*.3
            a.add("Spot",(.1,.13+(n%3)*.025,.17),(side*(.65 if n<12 else .48),y,z),BLACK)
    for n in range(8):
        a.add("BackSpot",(.15,.09,.19),((-.27 if n%2 else .27),2.26,-.66+(n//2)*.55),BLACK)
    a.eyes(.29,2.55,-1.91,.24)
    a.paws(gold,.49,-1.03,1.15,1.57)
    tail=((0,1.76,1.6),(.26,1.63,2.34),(.46,1.9,2.96),(.4,2.12,3.24))
    for n in range(3): a.rod("LongTail",tail[n],tail[n+1],.2,gold,"Tail",n)
    for n in range(4): a.add("TailBand",(.24,.22,.13),(.41,2.02+n*.045,2.93+n*.09),BLACK,motion="Tail",phase=n)
    return a


def _kangaroo():
    a=Animal("Kangaroo",(2.05,3.15,2.8))
    fur, light = (190,143,101),(229,194,151)
    a.add("Torso",(1.63,2.22,1.4),(0,1.66,.18),fur)
    a.add("Belly",(1.09,1.66,.45),(0,1.46,-.54),light)
    a.add("Pouch",(1.11,.87,.51),(0,1.1,-.73),(153,107,76))
    a.add("PouchRim",(.99,.14,.25),(0,1.47,-.95),light)
    a.add("Neck",(.89,1.23,.89),(0,2.61,-.19),fur,rotation=(-17,0,0))
    a.add("Head",(.96,1.1,1.09),(0,3.24,-.65),fur)
    a.add("Muzzle",(.58,.47,.83),(0,3.07,-1.23),light)
    a.add("Nose",(.3,.2,.21),(0,3.13,-1.65),BLACK)
    for side in (-1,1):
        a.add("LongEar",(.36,1.12,.34),(side*.33,4.18,-.53),fur,rotation=(0,0,side*-12))
        a.add("EarInside",(.17,.75,.12),(side*.33,4.18,-.71),(137,97,78),rotation=(0,0,side*-12))
        a.add("Thigh",(.81,1.15,1.11),(side*.68,.76,.43),fur)
        a.add("LongFoot",(.56,.38,1.49),(side*.69,.2,-.1),light,motion="Leg",phase=-side)
        a.rod("ShortArm",(side*.67,2.21,-.1),(side*.56,1.76,-.92),.27,fur,"Leg",side)
        a.add("Hand",(.29,.31,.35),(side*.56,1.7,-1.01),light,motion="Leg",phase=side)
    a.eyes(.29,3.4,-1.12,.25)
    a.rod("ThickTail",(0,.96,.87),(0,.33,2.11),.57,fur,"Tail")
    a.rod("TailTip",(0,.33,2.11),(.15,.19,2.8),.28,fur,"Tail")
    return a


def _gorilla():
    a=Animal("Gorilla",(2.9,3.1,2.6))
    fur, skin = (68,74,87),(131,139,147)
    a.add("BarrelChest",(2.45,2.3,1.67),(0,1.95,.18),fur)
    a.add("ChestPlate",(1.53,1.54,.46),(0,1.93,-.68),skin)
    a.add("BackSilver",(1.94,1.26,.37),(0,2.31,.93),(161,168,173))
    a.add("Head",(1.49,1.49,1.34),(0,3.03,-.32),fur)
    a.add("Face",(1.13,.99,.45),(0,2.95,-1),skin)
    a.add("Muzzle",(1.13,.53,.64),(0,2.62,-1.16),skin)
    a.add("Brow",(1.28,.28,.39),(0,3.28,-1.16),fur)
    a.add("Nose",(.53,.25,.19),(0,2.86,-1.49),BLACK)
    for side in (-1,1):
        a.add("Shoulder",(1.13,1.36,1.23),(side*1.12,2.21,-.02),fur)
        a.rod("LongForearm",(side*1.27,1.86,-.08),(side*1.58,.64,-.55),.89,fur,"Leg",side)
        a.add("KnuckleHand",(.87,.61,.83),(side*1.58,.32,-.64),skin,motion="Leg",phase=side)
        for n in range(3):
            a.add("Knuckle",(.19,.26,.3),(side*1.58+(n-1)*.21,.34,-1.06),fur,motion="Leg",phase=side)
        a.add("Leg",(.75,.94,.73),(side*.65,.6,.31),fur,motion="Leg",phase=-side)
        a.add("Foot",(.77,.31,.98),(side*.66,.19,-.03),skin,motion="Leg",phase=-side)
        a.add("Ear",(.26,.42,.19),(side*.83,3.01,-.19),skin)
    a.eyes(.32,3.16,-1.23,.24)
    return a


def _horse_wings(a, color, gold):
    for side in (-1,1):
        a.add("WingShoulder",(.74,.65,1.3),(side*.94,2.04,.16),color,motion="Wing",phase=side)
        a.add("WingArm",(2.03,.3,1.14),(side*1.83,2.24,.11),color,rotation=(0,side*-12,side*13),motion="Wing",phase=side)
        for n in range(7):
            x=side*(1.38+n*.32)
            a.add("FlightFeather",(.41,.18,1.29-n*.055),(x,2.25+n*.072,.52+n*.085),color,
                  rotation=(0,side*(10+n*4),side*13),motion="Wing",phase=side)
            a.add("FeatherTip",(.32,.12,.25),(x,2.25+n*.072,1.1+n*.055),gold,motion="Wing",phase=side)


def _pegasus():
    a=Animal("Pegasus",(2.2,3.05,4.05))
    fur,mane=(241,235,248),(153,125,204)
    a.add("HorseBody",(1.89,1.61,2.89),(0,1.89,.23),fur)
    a.add("Neck",(1.05,1.64,1.12),(0,2.57,-1.06),fur,rotation=(-23,0,0))
    a.add("HorseHead",(.98,1.24,1.38),(0,3.29,-1.67),fur,rotation=(-22,0,0))
    a.add("Muzzle",(.82,.67,.84),(0,2.99,-2.29),(224,216,234))
    for side in (-1,1):
        a.add("Ear",(.29,.69,.28),(side*.32,4.03,-1.43),fur,rotation=(0,0,side*-10))
        a.add("Eye",(.13,.26,.27),(side*.49,3.49,-1.92),(58,75,121))
        a.add("Nostril",(.11,.12,.1),(side*.28,3.06,-2.69),BLACK)
        for z in (-.9,1.21):
            a.add("LongLeg",(.4,1.47,.49),(side*.62,.93,z),fur,motion="Leg",phase=side if z<0 else -side)
            a.add("GoldHoof",(.49,.37,.65),(side*.62,.2,z),(210,176,103),motion="Leg",phase=side if z<0 else -side,material="Metal")
    for n in range(6):
        a.add("Mane",(.34,.51,.46),(0,3.7-n*.25,-.93+n*.12),mane)
    a.rod("SilkenTail",(0,2.1,1.54),(0,1.16,2.45),.56,mane,"Tail")
    _horse_wings(a,fur,(203,183,231))
    return a


def _phoenix():
    a=Animal("Phoenix",(1.8,2.9,2.7))
    orange, red, gold = (246,124,47),(193,51,47),(255,215,96)
    a.add("Body",(1.76,2.02,1.68),(0,1.87,.11),orange)
    a.add("Breast",(1.12,1.31,.54),(0,1.76,-.69),gold)
    a.add("Neck",(.9,1.21,.83),(0,2.63,-.32),red)
    a.add("Head",(1.12,1.04,1.08),(0,3.12,-.61),orange)
    a.add("Beak",(.53,.46,.84),(0,2.98,-1.37),gold,class_name="WedgePart",shape="Block",rotation=(0,180,0))
    a.eyes(.32,3.28,-1.05,.25)
    for n in range(4):
        a.add("FlameCrest",(.22,.82+n*.09,.38),(0,3.79+n*.04,-.6+n*.18),gold if n%2 else red,
              rotation=(25+n*7,0,0),class_name="WedgePart",shape="Block")
    for side in (-1,1):
        a.add("WingBase",(1.38,.63,1.39),(side*1.13,2.26,.18),red,motion="Wing",phase=side,rotation=(0,0,side*13))
        for n in range(8):
            x=side*(1.19+n*.31)
            a.add("FireFeather",(.51,.24,1.77-n*.07),(x,2.26+n*.08,.58+n*.12),orange if n%2 else red,
                  rotation=(0,side*(8+n*4),side*15),motion="Wing",phase=side)
            a.add("GoldenFeatherTip",(.37,.17,.45),(x,2.25+n*.08,1.3+n*.1),gold,motion="Wing",phase=side)
        a.add("Leg",(.25,.75,.29),(side*.4,.63,-.02),gold,motion="Leg",phase=side)
        for toe in range(3): a.add("Talon",(.12,.17,.65),(side*.4+(toe-1)*.14,.14,-.27),gold,motion="Leg",phase=side)
    for n in range(7):
        x=(n-3)*.24
        length=2.1+(3-abs(n-3))*.22
        a.add("FlameTail",(.34,.31,length),(x,1.33-abs(n-3)*.055,1.63),red if n%2 else orange,
              rotation=(-13,n*5-15,0),motion="Tail",phase=n)
        a.add("TailEmber",(.22,.24,.49),(x,1.53,2.64+(3-abs(n-3))*.2),gold,material="Neon",motion="Tail",phase=n)
    return a


def _dragon():
    a=Animal("WhiteDragon",(2.7,3.1,4.0))
    ivory,blue,gold=(241,247,249),(138,199,219),(218,192,122)
    a.add("DragonBody",(2.32,1.86,2.85),(0,1.64,.32),ivory)
    a.add("Belly",(1.39,1.34,1.6),(0,1.26,-.55),blue)
    a.add("Neck",(1.13,1.76,1.14),(0,2.49,-1.08),ivory,rotation=(-17,0,0))
    a.add("Head",(1.43,1.22,1.59),(0,3.23,-1.57),ivory)
    a.add("Snout",(1.18,.65,1.03),(0,3.01,-2.38),ivory)
    a.add("Jaw",(1.03,.23,.93),(0,2.68,-2.34),blue)
    for side in (-1,1):
        a.add("Eye",(.13,.28,.43),(side*.72,3.32,-1.88),(60,143,181),material="Neon")
        a.add("EyeBrow",(.25,.17,.55),(side*.69,3.55,-1.85),ivory,rotation=(0,0,side*-12))
        a.add("Nostril",(.15,.11,.16),(side*.36,3.26,-2.79),(80,121,144))
        a.rod("Horn",(side*.48,3.71,-1.04),(side*.68,4.46,-.49),.31,gold)
        a.add("HornTip",(.17,.44,.21),(side*.7,4.53,-.39),gold,rotation=(25,0,side*12),class_name="WedgePart",shape="Block")
        a.add("CheekFin",(.67,.6,.25),(side*.91,3.16,-1.05),blue,rotation=(0,side*37,0),class_name="WedgePart",shape="Block")
        for z in (-.85,1.24):
            phase=side if z<0 else -side
            a.add("Leg",(.66,1.01,.76),(side*.91,.71,z),ivory,motion="Leg",phase=phase)
            a.add("Paw",(.76,.35,.98),(side*.92,.2,z-.19),ivory,motion="Leg",phase=phase)
            for n in range(3): a.add("Claw",(.14,.16,.35),(side*.92+(n-1)*.19,.14,z-.7),gold,motion="Leg",phase=phase)
        a.rod("WingBone",(side*.83,2.54,.2),(side*3.51,3.24,.42),.21,ivory,"Wing",side)
        a.add("WingMembrane",(2.61,.16,1.68),(side*2.14,2.83,.89),blue,rotation=(0,side*-11,side*14),class_name="WedgePart",shape="Block",motion="Wing",phase=side)
        for n in range(4):
            a.rod("WingFinger",(side*(1.04+n*.6),2.63+n*.13,.25),
                  (side*(1.35+n*.65),2.62+n*.13,1.73+n*.06),.1,ivory,"Wing",side)
    for n in range(6):
        a.add("Spine",(.34,.53,.39),(0,2.64-n*.03,-.45+n*.41),blue,class_name="WedgePart",shape="Block")
    tail=((0,1.63,1.63),(.1,1.08,2.43),(.4,.92,3.15),(.73,1.14,3.69),(1,1.34,4.02))
    for n in range(4): a.rod("Tail",tail[n],tail[n+1],.65-n*.13,ivory,"Tail",n)
    a.add("TailFin",(.77,.54,.21),tail[-1],blue,rotation=(0,-35,0),class_name="WedgePart",shape="Block",motion="Tail")
    return a


def get_models():
    return [factory() for factory in (_snail,_caterpillar,_mouse,_frog,_turtle,
            _rabbit,_cat,_hound,_monkey,_cheetah,_kangaroo,_gorilla,_pegasus,_phoenix,_dragon)]


def _emit_model(parent,item,part,animal,name=None,scale=1,origin=(0,0,0)):
    model=item(parent,"Model",name or animal.name)
    root=part(model,"Root",(.2,.2,.2),origin,WHITE,transparency=1,collide=False)
    props=model.find("Properties")
    import xml.etree.ElementTree as ET
    ET.SubElement(props,"Ref",name="PrimaryPart").text=root.attrib["referent"]
    for desc in animal.parts:
        part(model,desc["name"],tuple(v*scale for v in desc["size"]),
             tuple(origin[i]+desc["position"][i]*scale for i in range(3)),desc["color"],
             class_name=desc["class_name"],rotation=desc["rotation"],shape=desc["shape"],
             material=desc["material"],collide=False)
    return model


def build_models(parent,item,part):
    return {animal.name:_emit_model(parent,item,part,animal) for animal in get_models()}


def build_exhibits(parent,item,part):
    # Three rows behind the spawn, visible when first opening the place.
    folder=item(parent,"Folder","AnimalGallery")
    for n,animal in enumerate(get_models()):
        origin=(-44+(n%5)*12,11.3,-28-(n//5)*16)
        _emit_model(folder,item,part,animal,f"{n+1:02d}_{animal.name}",.72,origin)
    return folder


def _luau(value):
    if isinstance(value,dict):
        return "{"+",".join(f"[{json.dumps(k)}]={_luau(v)}" for k,v in value.items())+"}"
    if isinstance(value,(list,tuple)):
        return "{"+",".join(_luau(v) for v in value)+"}"
    return json.dumps(value,ensure_ascii=False)


def generate_luau():
    models=get_models()
    definitions=[dict(Name=a.name,Collider=a.collision,Parts=a.parts) for a in models]
    source='''-- Generated by tools/model_assets.py; edit canonical geometry there.
-- All fifteen original models use Roblox primitives, with no asset permissions.
local AnimalModels = {}
AnimalModels.Definitions = {
'''+",\n".join(" "+_luau(d) for d in definitions)+'''
}

function AnimalModels.Create(form, parent)
 local definition = AnimalModels.Definitions[form] or AnimalModels.Definitions[1]
 local model = Instance.new("Model")
 model.Name = definition.Name
 local root = Instance.new("Part")
 root.Name = "Root"
 root.Size = Vector3.new(0.2, 0.2, 0.2)
 root.Transparency = 1
 root.Anchored = true
 root.CanCollide = false
 root.CanTouch = false
 root.CanQuery = false
 root.Parent = model
 model.PrimaryPart = root
 for _, description in ipairs(definition.Parts) do
  local part = Instance.new(description.class_name)
  part.Name = description.name
  part.Size = Vector3.new(table.unpack(description.size))
  local rotation = description.rotation
  part.CFrame = CFrame.new(table.unpack(description.position))
   * CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
  part.Color = Color3.fromRGB(table.unpack(description.color))
  part.Material = Enum.Material[description.material]
  if part:IsA("Part") then part.Shape = Enum.PartType[description.shape] end
  part.Anchored = true
  part.CanCollide = false
  part.CanTouch = false
  part.CanQuery = false
  part.Massless = true
  if description.motion ~= "" then
   part:SetAttribute("Motion", description.motion)
   part:SetAttribute("Phase", description.phase)
  end
  part.Parent = model
 end
 model.Parent = parent
 return model
end

function AnimalModels.PopulateLibrary(parent)
 for form, definition in ipairs(AnimalModels.Definitions) do
  if not parent:FindFirstChild(definition.Name) then AnimalModels.Create(form, parent) end
 end
end

function AnimalModels.EnsureLibrary()
 local storage = game:GetService("ReplicatedStorage")
 local folder = storage:FindFirstChild("SpeciesModels")
 if not folder then
  folder = Instance.new("Folder")
  folder.Name = "SpeciesModels"
  folder.Parent = storage
 end
 AnimalModels.PopulateLibrary(folder)
 return folder
end

-- Build also works without a parent, for ViewportFrame previews.
AnimalModels.Build = AnimalModels.Create

return AnimalModels
'''
    (ROOT/"src/shared/AnimalModels.luau").write_text(source,encoding="utf-8")
    return models


write_module = generate_luau


if __name__ == "__main__":
    models=generate_luau()
    print(f"Generated {len(models)} unique animals ({sum(len(a.parts) for a in models)} visible parts)")
