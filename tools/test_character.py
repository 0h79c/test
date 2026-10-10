"""Validate actual morph code with Luau instance/service mocks, not physics."""
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
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau",default="luau")
    args=parser.parse_args()
    spec=(ROOT/"tests/character.spec.luau").read_text(encoding="utf-8")
    files=("src/shared/Config.luau","src/shared/AnimalModels.luau","src/server/Character.luau")
    runner="local run = (function()\n"+spec+"\nend)()\nrun("+",\n".join(
        long_string((ROOT/path).read_text(encoding="utf-8")) for path in files)+")\n"
    with tempfile.TemporaryDirectory(prefix="evolution-character-") as directory:
        path=Path(directory)/"run.luau"
        path.write_text(runner,encoding="utf-8")
        subprocess.run([args.luau,str(path)],cwd=ROOT,check=True)


if __name__=="__main__":
    main()
