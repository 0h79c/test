"""Execute actual exploration clients against UI/service mocks (no rendering)."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def long_string(value):
    delimiter = '='
    while ']' + delimiter + ']' in value:
        delimiter += '='
    return '[' + delimiter + '[' + value + ']' + delimiter + ']'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', default='luau')
    args = parser.parse_args()
    files = ('src/shared/Config.luau', 'src/shared/WorldConfig.luau',
             'src/client/Main.client.luau', 'src/client/WorldFX.client.luau')
    spec = (ROOT / 'tests/presentation.spec.luau').read_text(encoding='utf-8')
    runner = 'local run = (function()\n' + spec + '\nend)()\nrun(' + ',\n'.join(
        long_string((ROOT / file).read_text(encoding='utf-8')) for file in files) + ')\n'
    with tempfile.TemporaryDirectory(prefix='evolution-presentation-') as directory:
        path = Path(directory) / 'run.luau'
        path.write_text(runner, encoding='utf-8')
        subprocess.run([args.luau, str(path)], cwd=ROOT, check=True)

if __name__ == '__main__':
    main()
