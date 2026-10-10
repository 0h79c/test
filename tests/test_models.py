"""Original animal geometry and its Studio/runtime contract."""
import math
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from model_assets import Animal, build_models, get_models


class AnimalGeometryTests(unittest.TestCase):
    def test_all_fifteen_animals_have_distinct_anatomy(self):
        expected={
            "Snail":{"ShellSpiral","EyeStalk","Feeler"},
            "Caterpillar":{"Segment","TinyFoot","Antenna"},
            "Mouse":{"RoundEar","Whisker","Tail"},
            "Frog":{"EyeBulge","BackThigh","FrontToe"},
            "Turtle":{"ShellScute","ShellRim","Tail"},
            "Rabbit":{"LongEar","CottonTail","Haunch"},
            "Cat":{"PointEar","TabbyStripe","Whisker"},
            "Hound":{"FloppyEar","LongMuzzle","Collar"},
            "Monkey":{"LongArm","CurledTail","RoundEar"},
            "Cheetah":{"Spot","TearMark","TailBand"},
            "Kangaroo":{"Pouch","LongFoot","ThickTail"},
            "Gorilla":{"BarrelChest","KnuckleHand","BackSilver"},
            "Pegasus":{"GoldHoof","FlightFeather","Mane"},
            "Phoenix":{"FlameCrest","FireFeather","FlameTail"},
            "WhiteDragon":{"Horn","WingMembrane","Spine"},
        }
        animals=get_models()
        self.assertEqual([a.name for a in animals],list(expected))
        signatures=set()
        for animal in animals:
            names={part["name"] for part in animal.parts}
            self.assertTrue(expected[animal.name] <= names,animal.name)
            signatures.add(tuple((part["name"],part["size"],part["position"])
                                 for part in animal.parts))
            self.assertTrue(all(v>0 for v in animal.collision))
            for part in animal.parts:
                self.assertTrue(all(math.isfinite(v) and v>0 for v in part["size"]))
                self.assertTrue(all(math.isfinite(v) for v in part["position"]+part["rotation"]))
                self.assertTrue(all(0<=v<=255 for v in part["color"]))
                self.assertIn(part["class_name"],("Part","WedgePart"))
        self.assertEqual(len(signatures),15)

    def test_rod_euler_rotation_aligns_both_endpoints(self):
        for start,end in (
            ((0,0,0),(1,2,3)), ((0,0,0),(-2,1,-4)),
            ((.2,1,2),(1,.5,-.4)), ((1,2,3),(-2,-1,3)),
            ((0,0,0),(3,0,0)), ((0,0,0),(0,2,0)),
            ((0,0,0),(0,0,-2)),
        ):
            animal=Animal("Test",(1,1,1))
            animal.rod("JoinedLimb",start,end,.2,(255,255,255))
            part=animal.parts[0]
            pitch,yaw,_=map(math.radians,part["rotation"])
            direction=(math.sin(yaw),-math.sin(pitch)*math.cos(yaw),
                       math.cos(pitch)*math.cos(yaw))
            length=math.sqrt(sum((end[i]-start[i])**2 for i in range(3)))
            for i in range(3):
                self.assertAlmostEqual(direction[i],(end[i]-start[i])/length,places=9)
                self.assertAlmostEqual(part["position"][i]-direction[i]*length/2,start[i],places=9)
                self.assertAlmostEqual(part["position"][i]+direction[i]*length/2,end[i],places=9)

    def test_xml_templates_have_floor_root_and_all_authored_parts(self):
        parent=ET.Element("Item",{"class":"Folder","referent":"Folder"})
        counter=0
        def item(parent,class_name,name,source=None):
            nonlocal counter
            counter+=1
            node=ET.SubElement(parent,"Item",{"class":class_name,"referent":str(counter)})
            props=ET.SubElement(node,"Properties")
            ET.SubElement(props,"string",name="Name").text=name
            return node
        calls=[]
        def part(parent,name,size,position,color,**kwargs):
            calls.append((name,size,position,color,kwargs))
            return item(parent,kwargs.get("class_name","Part"),name)
        templates=build_models(parent,item,part)
        self.assertEqual(len(templates),15)
        for animal in get_models():
            model=templates[animal.name]
            children=model.findall("Item")
            self.assertEqual(len(children),len(animal.parts)+1)
            root=children[0]
            self.assertEqual(root.find("Properties/string[@name='Name']").text,"Root")
            self.assertEqual(model.find("Properties/Ref[@name='PrimaryPart']").text,root.attrib["referent"])
        for name,_,position,_,options in calls:
            self.assertFalse(options["collide"])
            if name=="Root":
                self.assertEqual(position,(0,0,0))
                self.assertEqual(options["transparency"],1)


if __name__=="__main__":
    unittest.main()
