"""Exercise actual gait transforms and client speed sampling without Roblox physics."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from model_assets import get_models, mutation_geometry, _luau
from test_character import long_string

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau",default="luau")
    args=parser.parse_args()
    models=get_models()
    source=(ROOT/"tools/model_runtime.luau").read_text()
    source=source.replace("@@DEFINITIONS@@",",\n".join(_luau(dict(Name=a.name,Collider=a.collision,Parts=a.parts)) for a in models))
    source=source.replace("@@VARIANTS@@",",\n".join(_luau(mutation_geometry(a)) for a in models))
    sources=[source,(ROOT/"src/client/AnimalAnimator.client.luau").read_text(),(ROOT/"src/shared/Config.luau").read_text()]
    spec=(ROOT/"tests/animation.spec.luau").read_text()
    runner="local run=(function()\n"+spec+"\nend)()\nrun("+",\n".join(map(long_string,sources))+")\n"
    with tempfile.TemporaryDirectory(prefix="evolution-animation-") as directory:
        path=Path(directory)/"run.luau"
        path.write_text(runner)
        subprocess.run([args.luau,str(path)],cwd=ROOT,check=True)


if __name__=="__main__":
    main()
