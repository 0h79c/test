"""Build a playable Roblox XML place, including map and model geometry.

Uses the standard library. All scripts and assets are embedded; opening the place
never needs a plugin, HTTP download, or an enabled DataStore to show the world.
"""
from __future__ import annotations

import math
from pathlib import Path
import xml.etree.ElementTree as ET

from world_assets import descriptors, write_layout

ROOT = Path(__file__).resolve().parents[1]
MATERIALS = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512,
    "WoodPlanks": 528, "Marble": 784, "Basalt": 788, "Slate": 800,
    "Concrete": 816, "Brick": 848, "Rock": 896, "Metal": 1088,
    "Grass": 1280, "Sand": 1296, "Snow": 1328, "Glass": 1568,
}
SHAPES = {"Ball": 0, "Block": 1, "Cylinder": 2}


class PlaceBuilder:
    def __init__(self):
        self.place = ET.Element("roblox", version="4")
        ET.SubElement(self.place, "External").text = "null"
        ET.SubElement(self.place, "External").text = "nil"
        self.counter = 0

    def item(self, parent, class_name, name, source=None):
        self.counter += 1
        node = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{self.counter}"})
        props = ET.SubElement(node, "Properties")
        ET.SubElement(props, "string", name="Name").text = name
        if source is not None:
            ET.SubElement(props, "ProtectedString", name="Source").text = source
        return node

    @staticmethod
    def prop(node, kind, name, value):
        entry = ET.SubElement(node.find("Properties"), kind, name=name)
        if isinstance(value, bool):
            entry.text = "true" if value else "false"
        elif isinstance(value, (list, tuple)):
            names = {"Vector3": ("X", "Y", "Z"), "Color3": ("R", "G", "B"),
                     "UDim2": ("XS", "XO", "YS", "YO"), "UDim": ("S", "O")}[kind]
            for key, number in zip(names, value):
                ET.SubElement(entry, key).text = str(number)
        else:
            entry.text = str(value)
        return entry

    @staticmethod
    def cframe(node, name, position, rotation=(0, 0, 0)):
        rx, ry, rz = (math.radians(angle) for angle in rotation)
        cx, cy, cz, sx, sy, sz = math.cos(rx), math.cos(ry), math.cos(rz), math.sin(rx), math.sin(ry), math.sin(rz)
        # Rx * Ry * Rz, matching CFrame.Angles in the runtime builder.
        matrix = (
            cy * cz, -cy * sz, sy,
            sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy,
            -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy,
        )
        entry = ET.SubElement(node.find("Properties"), "CoordinateFrame", name=name)
        for key, value in zip(("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"), (*position, *matrix)):
            ET.SubElement(entry, key).text = f"{value:.8g}"
        return entry

    def part(self, parent, name, size, position, color, *, class_name="Part", rotation=(0, 0, 0),
             shape="Block", material="SmoothPlastic", anchored=True, collide=True, transparency=0,
             can_touch=False):
        node = self.item(parent, class_name, name)
        self.prop(node, "Vector3", "size", size)
        self.cframe(node, "CFrame", position, rotation)
        # BasePart serializes Color via Color3uint8, and Size via lowercase size.
        packed_color = 0xFF000000 | (int(color[0]) << 16) | (int(color[1]) << 8) | int(color[2])
        self.prop(node, "Color3uint8", "Color3uint8", packed_color)
        self.prop(node, "bool", "Anchored", anchored)
        self.prop(node, "bool", "CanCollide", collide)
        self.prop(node, "bool", "CanTouch", can_touch)
        self.prop(node, "float", "Transparency", transparency)
        self.prop(node, "token", "Material", MATERIALS[material])
        self.prop(node, "token", "TopSurface", 0)
        self.prop(node, "token", "BottomSurface", 0)
        if class_name == "Part":
            self.prop(node, "token", "shape", SHAPES[shape])
        if class_name == "SpawnLocation":
            self.prop(node, "bool", "Neutral", True)
            self.prop(node, "bool", "Enabled", True)
            self.prop(node, "int", "Duration", 0)
        return node

    def billboard(self, parent, spec, color):
        gui = self.item(parent, "BillboardGui", "Label")
        self.prop(gui, "UDim2", "Size", (0, spec["width"], 0, spec["height"]))
        self.prop(gui, "float", "MaxDistance", 160 if spec["width"] >= 300 else 65)
        self.prop(gui, "float", "LightInfluence", 0)
        self.prop(gui, "bool", "AlwaysOnTop", False)
        label = self.item(gui, "TextLabel", "Text")
        self.prop(label, "UDim2", "Size", (1, 0, 1, 0))
        self.prop(label, "Color3", "BackgroundColor3", tuple(v / 255 for v in (23, 34, 52)))
        self.prop(label, "float", "BackgroundTransparency", .18)
        self.prop(label, "int", "BorderSizePixel", 0)
        self.prop(label, "Color3", "TextColor3", tuple(v / 255 for v in color))
        self.prop(label, "token", "Font", 37)
        self.prop(label, "float", "TextSize", 25 if spec["width"] >= 300 else 20)
        self.prop(label, "bool", "TextWrapped", True)
        self.prop(label, "string", "Text", spec["title"] + ("\n" + spec["subtitle"] if spec["subtitle"] else ""))
        corner = self.item(label, "UICorner", "UICorner")
        self.prop(corner, "UDim", "CornerRadius", (0, 10))

    def world(self, workspace):
        folder = self.item(workspace, "Folder", "EvolutionObby")
        groups = {}
        for record in descriptors():
            parent = groups.get(record["group"])
            if parent is None:
                parent = self.item(folder, "Folder", record["group"])
                groups[record["group"]] = parent
            node = self.part(parent, record["name"], record["size"], record["position"], record["color"],
                             class_name=record.get("class_name", "Part"), rotation=record.get("rotation", (0, 0, 0)),
                             shape=record.get("shape", "Block"), material=record.get("material", "SmoothPlastic"),
                             collide=record.get("collide", True), transparency=record.get("transparency", 0),
                             can_touch=record.get("kind") is not None)
            if "billboard" in record:
                self.billboard(node, record["billboard"], record["color"])
            if "prompt" in record:
                prompt = self.item(node, "ProximityPrompt", "ProximityPrompt")
                self.prop(prompt, "string", "ActionText", record["prompt"]["action"])
                self.prop(prompt, "string", "ObjectText", record["prompt"]["object"])
                self.prop(prompt, "float", "MaxActivationDistance", record["prompt"]["distance"])
                self.prop(prompt, "bool", "RequiresLineOfSight", False)
                self.prop(prompt, "float", "HoldDuration", 0)
        return folder

    def build(self):
        write_layout()
        workspace = self.item(self.place, "Workspace", "Workspace")
        self.prop(workspace, "float", "FallenPartsDestroyHeight", -50)
        self.prop(workspace, "bool", "StreamingEnabled", False)
        self.prop(workspace, "float", "Gravity", 196.2)
        self.world_folder = self.world(workspace)
        # A useful initial editor view of the spawn, lobby gallery, and first zone.
        camera = self.item(workspace, "Camera", "Camera")
        self.cframe(camera, "CFrame", (-70, 68, 110), (-25, -25, 0))
        self.cframe(camera, "Focus", (8, 12, 0))
        self.prop(camera, "float", "FieldOfView", 70)
        self.prop(workspace, "Ref", "CurrentCamera", camera.attrib["referent"])
        lighting = self.item(self.place, "Lighting", "Lighting")
        self.prop(lighting, "float", "ClockTime", 14)
        self.prop(lighting, "float", "Brightness", 2)
        self.prop(lighting, "Color3", "Ambient", (.4, .45, .55))
        self.prop(lighting, "Color3", "OutdoorAmbient", (.6, .65, .7))
        self.prop(lighting, "bool", "GlobalShadows", True)
        self.prop(lighting, "float", "FogEnd", 6000)
        atmosphere = self.item(lighting, "Atmosphere", "Atmosphere")
        self.prop(atmosphere, "float", "Density", .18)
        self.prop(atmosphere, "float", "Haze", 1)
        self.prop(atmosphere, "Color3", "Color", (.78, .86, 1))
        self.prop(atmosphere, "Color3", "Decay", (.55, .67, .85))
        storage = self.item(self.place, "ReplicatedStorage", "ReplicatedStorage")
        shared = self.item(storage, "Folder", "Shared")
        # Model assets are embedded when their canonical generator is present.
        from model_assets import build_models, build_exhibits, write_module
        write_module()
        library = self.item(storage, "Folder", "SpeciesModels")
        build_models(library, self.item, self.part)
        exhibits = self.item(self.world_folder, "Folder", "Exhibits")
        build_exhibits(exhibits, self.item, self.part)
        server = self.item(self.item(self.place, "ServerScriptService", "ServerScriptService"), "Folder", "Game")
        player = self.item(self.place, "StarterPlayer", "StarterPlayer")
        self.prop(player, "float", "CameraMinZoomDistance", 6)
        self.prop(player, "float", "CameraMaxZoomDistance", 36)
        client = self.item(player, "StarterPlayerScripts", "StarterPlayerScripts")
        for folder, target in (("shared", shared), ("server", server), ("client", client)):
            for path in sorted((ROOT / "src" / folder).glob("*.luau")):
                name = path.name.removesuffix(".luau")
                class_name = "ModuleScript"
                if name.endswith(".server"):
                    name = name.removesuffix(".server")
                    class_name = "Script"
                elif name.endswith(".client"):
                    name = name.removesuffix(".client")
                    class_name = "LocalScript"
                self.item(target, class_name, name, path.read_text(encoding="utf-8"))
        return self.place


def build(output: Path | None = None):
    builder = PlaceBuilder()
    place = builder.build()
    output = output or ROOT / "EvolutionObby.rbxlx"
    ET.indent(place)
    ET.ElementTree(place).write(output, encoding="utf-8", xml_declaration=True)
    print(f"Built {output.name}: {len(place.findall('.//Item'))} instances, {len(place.findall('.//ProtectedString'))} scripts")
    return output


if __name__ == "__main__":
    build()
