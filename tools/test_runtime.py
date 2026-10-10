"""Run the actual server boot/lifecycle code against the Luau service harness."""
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
    config = (ROOT / "src/shared/Config.luau").read_text(encoding="utf-8")
    spec = (ROOT / "tests/runtime.spec.luau").read_text(encoding="utf-8")
    config_import = 'local Config = require("../src/shared/Config")'
    assert spec.count(config_import) == 1
    spec = spec.replace(config_import, "local Config = (function()\n" + config + "\nend)()")
    source = (ROOT / "src/server/Main.server.luau").read_text(encoding="utf-8")
    runner = "local run = (function()\n" + spec + "\nend)()\nrun(" + long_string(source) + ")\n"
    with tempfile.TemporaryDirectory(prefix="evolution-runtime-") as directory:
        path = Path(directory) / "run.luau"
        path.write_text(runner, encoding="utf-8")
        subprocess.run([args.luau, str(path)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
