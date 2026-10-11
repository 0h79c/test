"""Exercise the actual ecology module with server-side instances and services."""
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
    spec = (ROOT / "tests/ecology.spec.luau").read_text(encoding="utf-8")
    source = (ROOT / "src/server/Ecology.luau").read_text(encoding="utf-8")
    food_source = (ROOT / "src/shared/FoodModels.luau").read_text(encoding="utf-8")
    runner = "local run = (function()\n" + spec + "\nend)()\nrun(" + long_string(source) + "," + long_string(food_source) + ")\n"
    with tempfile.TemporaryDirectory(prefix="evolution-ecology-") as directory:
        path = Path(directory) / "run.luau"
        path.write_text(runner, encoding="utf-8")
        subprocess.run([args.luau, str(path)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
