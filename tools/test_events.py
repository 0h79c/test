"""Exercise the actual commerce and supply-drop adapters using Roblox mocks."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def long_string(value):
    delimiter = "="
    while "]" + delimiter + "]" in value:
        delimiter += "="
    return "[" + delimiter + "[" + value + "]" + delimiter + "]"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    modules = ("src/shared/Config.luau", "src/shared/EventRules.luau", "src/server/Commerce.luau")
    event_modules = ("src/shared/Config.luau", "src/shared/EventRules.luau", "src/server/Events.luau")
    for spec_path, sources in (("tests/commerce.spec.luau", modules), ("tests/drop_runtime.spec.luau", event_modules)):
        spec = (ROOT / spec_path).read_text(encoding="utf-8")
        runner = "local run = (function()\n" + spec + "\nend)()\nrun(" + ",\n".join(
            long_string((ROOT / path).read_text(encoding="utf-8")) for path in sources) + ")\n"
        with tempfile.TemporaryDirectory(prefix="evolution-events-") as directory:
            path = Path(directory) / "run.luau"
            path.write_text(runner, encoding="utf-8")
            subprocess.run([args.luau, str(path)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
