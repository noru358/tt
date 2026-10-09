"""Run isolated, sequential Godot 4.6 tests. No third-party Python packages.
Usage: python3 tests/run_suites.py --godot /path/to/Godot --output /scratch/path
"""
import argparse, json, os, pathlib, shutil, subprocess, sys, tempfile
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot', default='godot')
p.add_argument('--output', default=None)
p.add_argument('--suites', nargs='+')
a = p.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
output = pathlib.Path(a.output or tempfile.mkdtemp(prefix='gate1-tests-')).resolve()
output.mkdir(parents=True, exist_ok=True)
suites = a.suites or ['PlayerSuite','ControlsRevisionSuite','CombatFeelSuite','DefenseInputSuite','InputComboSuite','ReviewFixSuite','ReviewBalanceProbe','RegistrySuite','GrowthSuite','BossSuite','BattleFlowSuite','IndependentReviewSuite','MagicBowSuite','GolemCutoutSuite','GolemMobilitySuite','MovementToySuite','MovementAuditSuite','MovementRoomSet02Suite','MovementRoomSet02Probe','GolemBashToySuite','GolemBashRouteProbe']
subprocess.run([sys.executable,str(project/'tests/make_fixtures.py'),str(output/'fixtures')],check=True)
import_dir = pathlib.Path(tempfile.mkdtemp(prefix='import-',dir=output))
import_env = dict(os.environ, GATE1_TEST_SAVE=str(import_dir/'save.json'), GATE1_TEST_TUNING=str(import_dir/'tuning.json'))
with (import_dir/'import.log').open('w') as log:
    subprocess.run([a.godot,'--headless','--editor','--import','--quit','--path',str(project)],env=import_env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
if 'SCRIPT ERROR' in (import_dir/'import.log').read_text():
    sys.exit('Godot script import failed; inspect '+str(import_dir/'import.log'))
results = []
for suite in suites:
    folder = pathlib.Path(tempfile.mkdtemp(prefix=suite+'-',dir=output))
    env = dict(os.environ, GATE1_TEST_SAVE=str(folder/'save.json'), GATE1_TEST_TUNING=str(folder/'tuning.json'), GATE1_TEST_REORDER=str(folder/'reorder.json'))
    if suite.startswith('Movement'):
        shutil.copytree(project/'toys/movement/rooms', folder/'rooms')
        shutil.copy2(project/'toys/movement/movement_tuning.json', folder/'movement_tuning.json')
        env.update(MOVEMENT_TEST_ROOMS=str(folder/'rooms'), MOVEMENT_TEST_TUNING=str(folder/'movement_tuning.json'), MOVEMENT_TEST_LOG=str(folder/'movement.jsonl'))
    if suite.startswith('GolemBash'):
        shutil.copy2(project/'toys/movement/movement_tuning.json', folder/'movement_tuning.json')
        shutil.copy2(project/'toys/golem_bash/golem_bash_tuning.json', folder/'golem_bash_tuning.json')
        env.update(MOVEMENT_TEST_TUNING=str(folder/'movement_tuning.json'), GOLEM_BASH_TEST_TUNING=str(folder/'golem_bash_tuning.json'), GOLEM_BASH_TEST_LOG=str(folder/'golem_bash.jsonl'))
    command = [a.godot,'--headless','--fixed-fps','60','--path',str(project),'res://tests/'+suite+'.tscn']
    if suite == 'RegistrySuite': command += ['--','--manifest='+str(output/'fixtures/manifest.json')]
    logpath = folder/'result.log'
    with logpath.open('w') as log:
        try:
            code = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180).returncode
        except subprocess.TimeoutExpired:
            code = -1
    text = logpath.read_text()
    lines = [line for line in text.splitlines() if any(s in line for s in ['RESULT','FAIL:','SCRIPT ERROR','REVIEW_BALANCE '])]
    passed = code == 0 and 'SCRIPT ERROR' not in text and 'FAIL:' not in text and 'RESULT' in text
    print(suite, 'PASS' if passed else 'FAIL', '\n'+'\n'.join(lines),flush=True)
    results.append(dict(suite=suite,passed=passed,exit_code=code,log=str(logpath),summary=lines))
(output/'summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
sys.exit(0 if all(r['passed'] for r in results) else 1)
