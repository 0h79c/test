"""Regression checks for a physically embedded, broad and safe Roblox world."""
from __future__ import annotations
import math
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from world_assets import descriptors, world_config, safe_point, biome_at, _lua


def name(node):
    return node.findtext("./Properties/string[@name='Name']")


def vector(node,prop):
    values=node.find(f"./Properties/Vector3[@name='{prop}']")
    return tuple(float(values.findtext(axis)) for axis in ('X','Y','Z'))


def position(node):
    values=node.find("./Properties/CoordinateFrame[@name='CFrame']")
    return tuple(float(values.findtext(axis)) for axis in ('X','Y','Z'))


class PlaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.place=ET.parse(ROOT/'EvolutionObby.rbxlx').getroot()
        cls.records=descriptors()
        cls.config=world_config()
        cls.record_by_name={r['name']:r for r in cls.records}
        cls.workspace=cls.place.find("./Item[@class='Workspace']")
        cls.world=next(n for n in cls.workspace.findall('./Item') if name(n)=='EvolutionObby')
        cls.world_nodes={name(n):n for n in cls.world.findall('.//Item')}

    def test_world_and_safe_spawn_exist_before_scripts_execute(self):
        spawn=self.world_nodes['StartSpawn']
        self.assertEqual(spawn.attrib['class'],'SpawnLocation')
        for prop in ('Anchored','Neutral','Enabled','CanCollide'):
            self.assertEqual(spawn.findtext(f"./Properties/bool[@name='{prop}']"),'true')
        self.assertEqual(vector(spawn,'size'),(16,1,16))
        self.assertEqual(position(spawn),(0,13,0))
        ground=[r for r in self.records if r['group']=='GroundTerrain']
        self.assertGreater(len(ground),90)
        self.assertTrue(any(r['position'][0] < -1800 for r in ground))
        self.assertTrue(any(r['position'][0] > 1800 for r in ground))
        self.assertTrue(any(r['position'][2] < -1000 for r in ground))
        self.assertTrue(any(r['position'][2] > 1000 for r in ground))
        self.assertFalse(any(r.get('kind') in ('checkpoint','station') for r in self.records))
        self.assertFalse(any('MutationPad' in r['name'] for r in self.records))

    def test_nine_biomes_have_real_world_area_and_contiguous_bounds(self):
        biomes=self.config['Biomes']
        self.assertEqual(len(biomes),9)
        self.assertEqual(self.config['MetersPerStud'],.28)
        self.assertEqual(self.config['MapSize'],[4320,0,2520])
        self.assertEqual({b['Id'] for b in biomes},{'forest','mountains','snow','plains','meadow','river','swamp','desert','volcano'})
        for b in biomes:
            self.assertGreaterEqual(b['AreaSquareMeters'],10000)
            self.assertLessEqual(b['AreaSquareMeters'],100000)
            self.assertAlmostEqual((b['MaxX']-b['MinX'])*(b['MaxZ']-b['MinZ'])*.28**2,b['AreaSquareMeters'],places=2)
            self.assertIn('BiomeLabel_'+b['Id'],self.world_nodes)
        self.assertEqual(biome_at(0,0),'meadow')
        # No void corridors between neighbours across the world grid.
        for x in range(-2100,2101,100):
            for z in range(-1200,1201,100):
                self.assertIsNotNone(biome_at(x,z))

    def test_same_biome_respawn_can_always_move_at_least_two_hundred_metres(self):
        minimum=200/.28
        for b in self.config['Biomes']:
            pool=[p['Position'] for p in self.config['SafeSpawns'] if p['Biome']==b['Id']]
            self.assertGreater(len(pool),50)
            for p in pool:
                self.assertEqual(biome_at(p[0],p[2]),b['Id'])
                self.assertTrue(safe_point(p[0],p[2],12))
            # Grid covers edges, centre and landmark interiors, not only spawn points.
            for xi in range(17):
                for zi in range(11):
                    x=b['MinX']+(b['MaxX']-b['MinX'])*xi/16
                    z=b['MinZ']+(b['MaxZ']-b['MinZ'])*zi/10
                    furthest=max(math.hypot(p[0]-x,p[2]-z) for p in pool)
                    self.assertGreaterEqual(furthest,minimum,f"{b['Id']} at {x},{z}")

    def test_food_candidates_are_spread_and_clear_of_danger(self):
        points=self.config['FoodSpawnPoints']
        self.assertGreater(len(points),300)
        self.assertTrue(all(safe_point(p['Position'][0],p['Position'][2]) for p in points))
        for b in self.config['Biomes']:
            pool=[p['Position'] for p in points if p['Biome']==b['Id']]
            self.assertGreater(len(pool),30)
            for i,left in enumerate(pool):
                for right in pool[i+1:]:
                    self.assertGreaterEqual(math.hypot(left[0]-right[0],left[2]-right[2]),150)
        # Collision footprints use rotated native part axes (cylinders rotate 90Z).
        for record in self.records:
            if record['group'] != 'Details' or record.get('collide') is False or record.get('billboard'):
                continue
            rx,ry,rz=(math.radians(v) for v in record.get('rotation',(0,0,0)))
            cx,cy,cz,sx,sy,sz=math.cos(rx),math.cos(ry),math.cos(rz),math.sin(rx),math.sin(ry),math.sin(rz)
            matrix=((cy*cz,-cy*sz,sy),(-cx*sy*cz+sx*sz,cx*sy*sz+sx*cz,cx*cy))
            half=[v/2 for v in record['size']]
            extent_x=sum(abs(m)*h for m,h in zip(matrix[0],half))
            extent_z=sum(abs(m)*h for m,h in zip(matrix[1],half))
            for point in points:
                p=point['Position'];r=record['position']
                intersects=abs(p[0]-r[0]) < extent_x+4 and abs(p[2]-r[2]) < extent_z+4
                self.assertFalse(intersects,f"food point {p} blocked by {record['name']}")

    def test_river_has_gaps_and_two_independent_crossing_options(self):
        water=self.record_by_name['RiverWater']
        self.assertFalse(water['collide'])
        self.assertEqual(water['kind'],'water')
        stones=[self.record_by_name[f'RiverStep{i}'] for i in range(7)]
        # Box-shaped stones preserve the original 4stud gap and flat landing top.
        for left,right in zip(stones,stones[1:]):
            gap=right['position'][0]-left['position'][0]-(left['size'][0]+right['size'][0])/2
            self.assertGreater(gap,0)
            self.assertLessEqual(gap,12*(2*40/196.2))
            self.assertEqual(left['position'][1],right['position'][1])
            self.assertEqual(left.get('shape','Block'),'Block')
            self.assertEqual(left['position'][1]+left['size'][1]/2,14)
        self.assertEqual(self.record_by_name['PaidBridgeDeck']['kind'],'bridge')
        tolls=[r for r in self.records if r.get('kind')=='bridge_toll']
        self.assertEqual(len(tolls),2)
        self.assertEqual({r['side'] for r in tolls},{-1,1})
        self.assertTrue(all('150 Coins' in r['prompt']['action'] for r in tolls))
        # A continuous underwater ground at surface level would bypass the crossings.
        for r in self.records:
            if r['group']=='GroundTerrain' and r['name'].startswith('Ground_river'):
                self.assertGreaterEqual(abs(r['position'][0]-1440)-r['size'][0]/2,66)

    def test_angular_scenery_is_varied_and_does_not_block_travel(self):
        trees=[r for r in self.records if '_Tree' in r['name']]
        rocks=[r for r in self.records if '_Rock' in r['name']]
        self.assertGreater(len(trees),2000)
        self.assertGreater(len(rocks),700)
        self.assertTrue(all(r.get('shape','Block')=='Block' for r in trees+rocks))
        self.assertTrue(any(r.get('class_name')=='WedgePart' for r in trees))
        self.assertTrue(any(r.get('class_name')=='WedgePart' for r in rocks))
        trunks=[r for r in trees if r['name'].endswith('Trunk')]
        self.assertGreater(len({tuple(r['size']) for r in trunks}),200)
        self.assertGreater(len({tuple(r['rotation']) for r in trunks}),200)
        for r in trees:
            if not r['name'].endswith(('Trunk','RootFlare')):
                self.assertIs(r.get('collide'),False,r['name'])
        # Additional facets have a bounded scene cost under streaming.
        self.assertLess(len(self.records),7000)

    def test_only_three_paid_teleport_locations(self):
        portals=[r for r in self.records if r.get('kind')=='teleport']
        self.assertEqual(len(portals),3)
        self.assertEqual({r['biome'] for r in portals},{'meadow','snow','volcano'})
        for r in portals:
            self.assertGreater(r['cost'],0)
            self.assertIsNotNone(self.world_nodes[r['name']].find("./Item[@class='ProximityPrompt']"))

    def test_xml_geometry_serializes_valid_roblox_properties(self):
        physical=[n for n in self.place.findall('.//Item') if n.attrib['class'] in ('Part','SpawnLocation','WedgePart')]
        self.assertGreater(len(physical),4000)
        for n in physical:
            self.assertIsNotNone(n.find("./Properties/CoordinateFrame[@name='CFrame']"),name(n))
            self.assertIsNotNone(n.find("./Properties/Color3uint8[@name='Color3uint8']"),name(n))
            self.assertTrue(all(0<d<=2048 for d in vector(n,'size')),name(n))
        refs=[n.attrib['referent'] for n in self.place.findall('.//Item')]
        self.assertEqual(len(refs),len(set(refs)))
        self.assertEqual(len(self.records),len(self.record_by_name))

    def test_static_world_runtime_layout_and_seed_do_not_drift(self):
        expected='-- Generated by tools/world_assets.py. Edit the canonical descriptors, then rebuild.\nreturn {\n'+'\n'.join(' '+_lua(r)+',' for r in self.records)+'\n}\n'
        self.assertEqual((ROOT/'src/shared/WorldLayout.luau').read_text(encoding='utf-8'),expected)
        self.assertEqual(descriptors(),descriptors())
        self.assertNotEqual(descriptors(seed=1),descriptors(seed=2))
        for r in self.records:
            n=self.world_nodes[r['name']]
            self.assertEqual(vector(n,'size'),tuple(r['size']))
            for actual,required in zip(position(n),r['position']):
                self.assertAlmostEqual(actual,required,places=3)

    def test_embedded_scripts_match_current_enabled_sources(self):
        paths={}
        for section in ('shared','server','client'):
            for path in (ROOT/'src'/section).glob('*.luau'):
                script_name=path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
                kind='Script' if path.name.endswith('.server.luau') else 'LocalScript' if path.name.endswith('.client.luau') else 'ModuleScript'
                paths[(script_name,kind)]=path
        embedded=[n for n in self.place.findall('.//Item') if n.attrib['class'] in ('Script','LocalScript','ModuleScript')]
        self.assertEqual(len(embedded),len(paths))
        for n in embedded:
            self.assertEqual(n.findtext("./Properties/ProtectedString[@name='Source']"),paths[(name(n),n.attrib['class'])].read_text(encoding='utf-8'))
            self.assertNotEqual(n.findtext("./Properties/bool[@name='Disabled']"),'true')

    def test_all_fifteen_species_are_embedded_without_external_asset_ids(self):
        replicated=self.place.find("./Item[@class='ReplicatedStorage']")
        library=next(n for n in replicated.findall('./Item') if name(n)=='SpeciesModels')
        models=library.findall("./Item[@class='Model']")
        self.assertEqual(len(models),15)
        for model in models:
            self.assertGreaterEqual(len(model.findall("./Item[@class='Part']")),5,name(model))
        self.assertIsNone(next((n for n in self.world.findall('./Item') if name(n)=='Exhibits'),None))


if __name__=='__main__':
    unittest.main()
