"""Validate the place, Luau sources and actual open-world service modules."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    parser.add_argument("--compiler", default="luau-compile")
    args = parser.parse_args()
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], cwd=ROOT, check=True)
    files = sorted((ROOT / "src").rglob("*.luau")) + sorted((ROOT / "tests").glob("*.luau"))
    for source in files:
        result = subprocess.run([args.compiler, str(source)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if result.returncode:
            print(result.stderr.decode(errors="replace"), file=sys.stderr)
            raise SystemExit(result.returncode)
    print(f"PASS: {len(files)} Luau source files compile", flush=True)
    for spec in ("config", "rules", "events"):
        subprocess.run([args.luau, f"tests/{spec}.spec.luau"], cwd=ROOT, check=True)
    for service in ("runtime", "character", "animation", "buffs", "world", "ecology", "events", "presentation"):
        subprocess.run([sys.executable, f"tools/test_{service}.py", "--luau", args.luau], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
