"""Place regressions: a Studio-openable scene must contain physical assets.

Run: python3 -m unittest discover -s tests -p 'test_*.py'
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from world_assets import descriptors, stage_position, _lua


def name(node):
    return node.findtext("./Properties/string[@name='Name']")


def vector(node, prop):
    values = node.find(f"./Properties/Vector3[@name='{prop}']")
    return tuple(float(values.findtext(axis)) for axis in ("X", "Y", "Z"))


def position(node):
    values = node.find("./Properties/CoordinateFrame[@name='CFrame']")
    return tuple(float(values.findtext(axis)) for axis in ("X", "Y", "Z"))


class PlaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.place = ET.parse(ROOT / "EvolutionObby.rbxlx").getroot()
        cls.records = descriptors()
        cls.record_by_name = {r["name"]: r for r in cls.records}
        cls.workspace = cls.place.find("./Item[@class='Workspace']")
        cls.world = next(node for node in cls.workspace.findall("./Item") if name(node) == "EvolutionObby")
        cls.world_nodes = {name(node): node for node in cls.world.findall(".//Item")}

    def test_world_is_physical_before_scripts_execute(self):
        spawn = self.world_nodes["StartSpawn"]
        self.assertEqual(spawn.attrib["class"], "SpawnLocation")
        self.assertEqual(spawn.findtext("./Properties/bool[@name='Anchored']"), "true")
        self.assertEqual(spawn.findtext("./Properties/bool[@name='Neutral']"), "true")
        self.assertEqual(spawn.findtext("./Properties/bool[@name='Enabled']"), "true")
        self.assertEqual(vector(spawn, "size"), (16, 1, 16))
        self.assertEqual(position(spawn), (0, 11, 0))
        floor = self.world_nodes["LobbyGround"]
        self.assertEqual(floor.findtext("./Properties/bool[@name='CanCollide']"), "true")
        self.assertGreaterEqual(vector(floor, "size")[0], 80)
        self.assertGreaterEqual(vector(floor, "size")[2], 100)
        self.assertLess(position(floor)[1], position(spawn)[1])

    def test_all_stages_stations_and_coins_embedded(self):
        stages = sorted(r["stage"] for r in self.records if r.get("kind") == "checkpoint")
        self.assertEqual(stages, list(range(1, 141)))
        for stage in stages:
            self.assertIn(f"Checkpoint{stage:03d}", self.world_nodes)
            self.assertEqual(position(self.world_nodes[f"Checkpoint{stage:03d}"]), stage_position(stage))
        stations = [r for r in self.records if r.get("kind") == "station"]
        self.assertEqual(len(stations), 15)
        for station in stations:
            prompt = self.world_nodes[station["name"]].find("./Item[@class='ProximityPrompt']")
            self.assertIsNotNone(prompt)
        self.assertEqual(sorted(r["id"] for r in self.records if r.get("kind") == "coin"), list(range(1, 141)))
        self.assertIn("VictorySign", self.world_nodes)
        self.assertEqual(sum(r["name"].startswith("ZoneSign") for r in self.records), 14)

    def test_every_mandatory_jump_reachable_by_initial_form(self):
        # Conservative bound: walk speed12 * airborne time with JumpPower40.
        max_jump_distance = 12 * (2 * 40 / 196.2)
        for stage in range(140):
            current = dict(position=stage_position(stage), size=(14, 1, 14))
            following = dict(position=stage_position(stage + 1), size=(14, 1, 14))
            route = [current, self.record_by_name[f"Jump{stage:03d}_1"],
                     self.record_by_name[f"Jump{stage:03d}_2"], following]
            for left, right in zip(route, route[1:]):
                dx = max(0, abs(left["position"][0] - right["position"][0]) - (left["size"][0] + right["size"][0]) / 2)
                dz = max(0, abs(left["position"][2] - right["position"][2]) - (left["size"][2] + right["size"][2]) / 2)
                self.assertLess(math.hypot(dx, dz), max_jump_distance / 2, f"Stage {stage} needs excessive jump")
                self.assertEqual(left["position"][1], right["position"][1])
                self.assertNotIn("form", right, "Mandatory progress must not require a random form")

    def test_optional_ability_trials_are_tangible_and_clear_of_main_route(self):
        expected = {"LowLaser0": 5, "WindVolume": 12, "PhoenixFirewalk": 14, "MovingLavaWall": 14}
        for trial_name, immunity in expected.items():
            record = self.record_by_name[trial_name]
            self.assertEqual(record["immune_form"], immunity)
            self.assertIn(trial_name, self.world_nodes)
            nearest_stage = max(0, min(140, round(record["position"][0] / 26)))
            # All side hazards are beyond even the widest compulsory platform.
            self.assertGreater(record["position"][2] - record["size"][2] / 2,
                               stage_position(nearest_stage)[2] + 14)
        for stage in (40, 90, 110, 130):
            self.assertIn(f"TrialReturn{stage}", self.world_nodes)
            self.assertEqual(self.record_by_name[f"TrialReturn{stage}"]["kind"], "return")
        tunnel_floor = self.record_by_name["TrialFloor40"]
        roof = self.record_by_name["LaserTunnelRoof"]
        clearance = roof["position"][1] - roof["size"][1] / 2 - (tunnel_floor["position"][1] + tunnel_floor["size"][1] / 2)
        self.assertGreater(clearance, 1.9)  # Giant turtle collider height.
        self.assertLess(clearance, 5)  # A visually low tunnel rather than a tall hall.

    def test_dynamic_trials_have_bounded_time_based_settings(self):
        wall = self.record_by_name["MovingLavaWall"]
        motion = wall["motion"]
        self.assertEqual(motion["axis"], "X")
        self.assertGreater(motion["speed"], 12)  # Faster than the first form.
        self.assertLess(motion["speed"], 35)  # Cheetah can outrun it.
        self.assertGreater(motion["pause"], 0)
        floor = self.record_by_name["TrialFloor90"]
        furthest_edge = wall["position"][0] + motion["distance"] + wall["size"][0] / 2
        self.assertLess(furthest_edge, floor["position"][0] + floor["size"][0] / 2)
        wind = self.record_by_name["WindVolume"]
        self.assertEqual(wind["kind"], "wind")
        self.assertGreater(wind["wind"]["acceleration"], 0)
        self.assertLessEqual(wind["wind"]["max_speed"], 24)

    def test_xml_parts_have_real_roblox_properties(self):
        physical = [node for node in self.place.findall(".//Item") if node.attrib["class"] in ("Part", "SpawnLocation", "WedgePart")]
        self.assertGreater(len(physical), 2000)
        for node in physical:
            label = name(node)
            self.assertIsNotNone(node.find("./Properties/Vector3[@name='size']"), label)
            self.assertIsNotNone(node.find("./Properties/CoordinateFrame[@name='CFrame']"), label)
            self.assertIsNotNone(node.find("./Properties/Color3uint8[@name='Color3uint8']"), label)
            self.assertTrue(all(dimension > 0 for dimension in vector(node, "size")), label)
        refs = [node.attrib["referent"] for node in self.place.findall(".//Item")]
        self.assertEqual(len(refs), len(set(refs)))
        self.assertEqual(len(self.records), len(self.record_by_name))

    def test_static_world_and_runtime_layout_do_not_drift(self):
        expected = "-- Generated by tools/world_assets.py. Edit the canonical descriptors, then rebuild.\nreturn {\n" + "\n".join(" " + _lua(record) + "," for record in self.records) + "\n}\n"
        self.assertEqual((ROOT / "src/shared/WorldLayout.luau").read_text(encoding="utf-8"), expected)
        for record in self.records:
            node = self.world_nodes[record["name"]]
            self.assertEqual(vector(node, "size"), tuple(record["size"]))
            for actual, required in zip(position(node), record["position"]):
                self.assertAlmostEqual(actual, required, places=4)

    def test_embedded_scripts_match_source_and_are_enabled(self):
        source_paths = {}
        for section in ("shared", "server", "client"):
            for path in (ROOT / "src" / section).glob("*.luau"):
                script_name = path.name.removesuffix(".luau").removesuffix(".server").removesuffix(".client")
                class_name = "Script" if path.name.endswith(".server.luau") else "LocalScript" if path.name.endswith(".client.luau") else "ModuleScript"
                source_paths[(script_name, class_name)] = path
        embedded = [node for node in self.place.findall(".//Item") if node.attrib["class"] in ("Script", "LocalScript", "ModuleScript")]
        self.assertEqual(len(embedded), len(source_paths))
        for node in embedded:
            self.assertEqual(node.findtext("./Properties/ProtectedString[@name='Source']"), source_paths[(name(node), node.attrib["class"])].read_text(encoding="utf-8"))
            self.assertNotEqual(node.findtext("./Properties/bool[@name='Disabled']"), "true")

    def test_all_fifteen_species_exist_as_models_and_exhibits(self):
        replicated = self.place.find("./Item[@class='ReplicatedStorage']")
        library = next(node for node in replicated.findall("./Item") if name(node) == "SpeciesModels")
        models = library.findall("./Item[@class='Model']")
        self.assertEqual(len(models), 15)
        for model in models:
            self.assertGreaterEqual(len(model.findall("./Item[@class='Part']")), 5, name(model))
        exhibits = next(node for node in self.world.findall("./Item") if name(node) == "Exhibits")
        self.assertEqual(len(exhibits.findall(".//Item[@class='Model']")), 15)


if __name__ == "__main__":
    unittest.main()
