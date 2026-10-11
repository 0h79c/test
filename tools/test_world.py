"""Execute the actual World module against the canonical geometry in Luau."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def long(value):
    delimiter='='
    while ']'+delimiter+']' in value:delimiter+='='
    return '['+delimiter+'['+value+']'+delimiter+']'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau',default='luau')
    args=parser.parse_args()
    spec=(ROOT/'tests/world.spec.luau').read_text(encoding='utf-8')
    inputs=[ROOT/'src/server/World.luau',ROOT/'src/shared/WorldLayout.luau',ROOT/'src/shared/WorldConfig.luau']
    runner='local run = (function()\n'+spec+'\nend)()\nrun('+','.join(long(p.read_text(encoding='utf-8')) for p in inputs)+')\n'
    with tempfile.TemporaryDirectory(prefix='evolution-world-') as directory:
        path=Path(directory)/'run.luau'
        path.write_text(runner,encoding='utf-8')
        subprocess.run([args.luau,str(path)],cwd=ROOT,check=True)

if __name__=='__main__':main()
