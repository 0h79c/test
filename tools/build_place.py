"""Build a Roblox XML place using only the Python standard library."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
place = ET.Element("roblox", version="4")
counter = 0


def item(parent, class_name, name, source=None):
    global counter
    counter += 1
    node = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{counter}"})
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", name="Name").text = name
    if source is not None:
        ET.SubElement(props, "ProtectedString", name="Source").text = source
    return node


item(place, "Workspace", "Workspace")
shared = item(item(place, "ReplicatedStorage", "ReplicatedStorage"), "Folder", "Shared")
server = item(item(place, "ServerScriptService", "ServerScriptService"), "Folder", "Game")
client = item(item(place, "StarterPlayer", "StarterPlayer"), "StarterPlayerScripts", "StarterPlayerScripts")
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
        item(target, class_name, name, path.read_text(encoding="utf-8"))
output = ROOT / "EvolutionObby.rbxlx"
ET.indent(place)
ET.ElementTree(place).write(output, encoding="utf-8", xml_declaration=True)
print(f"Built {output.name} with {len(place.findall('.//ProtectedString'))} scripts")
