#!/usr/bin/env python3
"""Run immutable public-API fixtures against reference, 0.1.0 and candidate.
Usage: python3 Validation/compare-presentation.py OUTPUT_DIRECTORY
Optional final arguments select revisions to rerun under the same source hashes.
The candidate and published 0.1.0 run their entire macOS suites. The reference
runs the portable fixture, including the measured-height improvement (old must fail).
Artifacts and an auditable result matrix stay outside the repository.
"""
import hashlib
import html
import io
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tarfile

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
fixture_name = 'Tests/A1R2BannerTests/PresentationSemanticsTests.swift'
fixture = (root / fixture_name).read_bytes()
fixture_hash = hashlib.sha256(fixture).hexdigest()
revisions = {'reference': 'd6807c26b335537fb2306f0d8114bbafcfad3aae',
             'published': '29d68a5c40b424af0001537ed215c284c76ceecb', 'candidate': None}
regressions = ['testInsertionAndRemovalTravelAcrossPositionsAndEdges',
               'testSignedStackOffsetAndRestingAnchors',
               'testScaledSignedOffsetIsPresentationTranslation',
               'testStackExitReservesSpaceUntilQueueRemoval',
               'testMixedSingletonDoesNotReserveStackSpace',
               'testStackSpacingOrderingAndCrossAnchorZOrder']
controls = ['testIPTVRepresentativeTransitions']
adaptive = ['testAdaptiveMeasuredStacksIgnoreInaccurateHeightHints']

def source_hashes():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in ['Sources', 'Tests'] for p in sorted((root / folder).rglob('*.swift'))}

initial_sources = source_hashes()
results = {'fixture_sha256': fixture_hash, 'candidate_sources': initial_sources, 'revisions': {}}
selected = sys.argv[2:] or ['candidate', 'reference', 'published']
if sys.argv[2:] and (output / 'results.json').exists():
    previous = json.loads((output / 'results.json').read_text())
    if previous['fixture_sha256'] != fixture_hash or previous['candidate_sources'] != initial_sources:
        raise SystemExit('Cannot reuse results after source or fixture changes.')
    results = previous
unexpected = False
for name in selected:
    revision = revisions[name]
    package = output / name if revision else root
    if revision:
        package.mkdir(exist_ok=True)
        archive = subprocess.check_output(['git', '-C', str(root), 'archive', revision])
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(package)
        (package / fixture_name).write_bytes(fixture)
    if (package / fixture_name).read_bytes() != fixture or source_hashes() != initial_sources:
        raise SystemExit('Sources changed during validation; start a new immutable run.')
    environment = os.environ | {'A1R2_PRESENTATION_OUTPUT': str(output / (name + '-images')),
                                'NSUnbufferedIO': 'YES'}
    command = ['swift', 'test', '--package-path', str(package), '--scratch-path', str(output / (name + '-build'))]
    if name == "reference":
        command += ['--filter', 'PresentationSemanticsTests']
    log_path = output / (name + '.log')
    with log_path.open('w') as log:
        process = subprocess.Popen(command, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            returncode = process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            returncode = 124
    report = log_path.read_text()
    statuses = dict(re.findall(r"Test Case '-\[A1R2BannerTests\.PresentationSemanticsTests (\w+)\]' (passed|failed)", report))
    expected = {test: ('failed' if name == 'published' else 'passed') for test in regressions}
    expected.update({test: 'passed' for test in controls})
    expected.update({test: ('failed' if name == 'reference' else 'passed') for test in adaptive})
    adaptive_statuses = dict(re.findall(r"Test Case '-\[A1R2BannerTests\.HostedLayoutTests (\w+)\]' (passed|failed|skipped)", report))
    adaptive_valid = name == 'reference' or (len(adaptive_statuses) >= 17 and
        all(status == 'passed' or (test == 'testGlassForegroundRenderingAndOverride' and status == 'skipped')
            for test, status in adaptive_statuses.items()))
    valid = all(statuses.get(test) == status for test, status in expected.items())
    valid &= adaptive_valid
    valid &= returncode == (0 if name == 'candidate' else 1)
    valid &= source_hashes() == initial_sources
    unexpected |= not valid
    results['revisions'][name] = {'revision': revision, 'returncode': returncode,
                                  'tests': statuses, 'adaptive_hosted_tests': adaptive_statuses, 'expected': expected, 'valid': valid,
                                  'command': command, 'fixture_sha256': fixture_hash}
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'{name}: exit {returncode}; expected matrix {"PASS" if valid else "FAIL"}; {log_path}', flush=True)

phases = ['before', 'early', 'mid', 'rest', 'exit-start', 'exit-mid', 'removed']
images = {p.name for name in revisions for p in (output / (name + '-images')).glob('*.png')}
def image_order(filename):
    for index, phase in enumerate(phases):
        suffix = '-' + phase + '.png'
        if filename.endswith(suffix):
            return filename[:-len(suffix)], index
    return filename, -1
rows = []
for filename in sorted(images, key=image_order):
    cells = ''.join(f'<td><img loading="lazy" src="{name}-images/{html.escape(filename)}" alt="{name}: {html.escape(filename)}"></td>' for name in revisions)
    rows.append(f'<tr><th>{html.escape(filename)}</th>{cells}</tr>')
(output / 'comparison.html').write_text('<!doctype html><meta charset="utf-8"><title>Banner comparison</title><style>body{font:14px system-ui}table{border-collapse:collapse}td,th{border:1px solid #aaa;padding:4px}img{max-width:400px;height:auto}</style><h1>Reference / 0.1.0 / candidate</h1><p>Raw runtime frames; wall-clock phases are approximate. See results.json for immutable fixture/source hashes and per-test expectations.</p><table><tr><th>Fixture / phase</th><th>d6807c2</th><th>0.1.0</th><th>candidate</th></tr>' + ''.join(rows) + '</table>')
print(output / 'comparison.html')
unexpected |= any(not value['valid'] for value in results['revisions'].values())
unexpected |= set(results['revisions']) != set(revisions)
if unexpected:
    raise SystemExit('Unexpected result matrix; inspect results.json and logs.')
