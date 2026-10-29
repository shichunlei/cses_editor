"""Run isolated device UI scenarios, capture native IME screenshots, restore settings."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
STAGE = ROOT / '.dart_tool/modal-device-example'
SERIAL = '10AF5304SJ0062L'
TEST_ID = 'com.cses.offline.modal_ui_verification'


def adb(*args, binary=False):
    return subprocess.check_output(['adb', '-s', SERIAL, *args], text=not binary)


def prepare():
    shutil.copytree(ROOT / 'example', STAGE, dirs_exist_ok=True, ignore=shutil.ignore_patterns('build', '.dart_tool', '.gradle', '.kotlin', '.cxx', 'Pods', '.symlinks', 'ephemeral', '.packages', 'ios', 'macos', 'web', 'windows', 'linux'))
    pubspec = STAGE / 'pubspec.yaml'
    pubspec.write_text(pubspec.read_text().replace('path: ..\n', 'path: ../..\n'))
    gradle = STAGE / 'android/app/build.gradle.kts'
    gradle.write_text(gradle.read_text().replace('com.cses.offline.cses_offline_example', TEST_ID))
    for activity in (STAGE / 'android/app/src/main/kotlin').rglob('MainActivity.kt'):
        activity.write_text(activity.read_text().replace('com.cses.offline.cses_offline_example', TEST_ID))
    if os.environ.get('REBUILD_UI', '1') == '1':
        for generated in [STAGE / 'build', STAGE / '.dart_tool/flutter_build']:
            if generated.exists():
                shutil.rmtree(generated)
    with (OUT / 'pub-get.log').open('w') as log:
        subprocess.run(['flutter', 'pub', 'get'], cwd=STAGE, stdout=log, stderr=subprocess.STDOUT, check=True)


def main():
    original = {
        'size': adb('shell', 'wm', 'size').strip(),
        'density': adb('shell', 'wm', 'density').strip(),
        'font_scale': adb('shell', 'settings', 'get', 'system', 'font_scale').strip(),
    }
    (OUT / 'device-before.json').write_text(json.dumps(original, indent=2))
    scenarios = [('normal', None, '1.0'), ('narrow-large', '540', '1.6'), ('narrow-largest', '540', '2.0')]
    selected = os.environ.get('UI_SCENARIOS')
    if selected:
        scenarios = [case for case in scenarios if case[0] in selected.split(',')]
    results = []
    try:
        prepare()
        for name, density, font in scenarios:
            adb('shell', 'wm', 'density', density or 'reset')
            adb('shell', 'settings', 'put', 'system', 'font_scale', font)
            time.sleep(2)
            case = OUT / name
            case.mkdir(exist_ok=True)
            env = dict(os.environ, CSES_VERIFICATION_DIR=str(case))
            command = ['flutter', 'drive', '--no-pub', '-d', SERIAL,
                       '--driver=test_driver/integration_test.dart',
                       '--target=integration_test/modal_ui_device_test.dart',
                       '--dart-define=UI_SCENARIO=' + name]
            print('RUN ' + name, flush=True)
            with (case / 'device.log').open('w') as log:
                proc = subprocess.Popen(command, cwd=STAGE, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
                for line in proc.stdout:
                    log.write(line)
                    log.flush()
                    if any(word in line for word in ['Running Gradle', 'Built ', 'Installing ', 'DEVICE_', 'Exception', 'Error', 'failed', 'passed', 'FAIL', 'RenderFlex']):
                        print(line.rstrip(), flush=True)
                    capture = re.search(r'DEVICE_CAPTURE:([a-z0-9-]+)', line)
                    if capture:
                        image = adb('exec-out', 'screencap', '-p', binary=True)
                        (case / (capture[1] + '-native.png')).write_bytes(image)
                        print('SAVED native ' + capture[1], flush=True)
                code = proc.wait()
            if code == 0 and 'All tests passed.' not in (case / 'device.log').read_text():
                code = 1
            results.append({'scenario': name, 'density': density or 'physical', 'font_scale': font, 'exit_code': code})
            (OUT / 'results.json').write_text(json.dumps(results, indent=2))
            if code:
                break
    finally:
        override = re.search(r'Override density: (\d+)', original['density'])
        adb('shell', 'wm', 'density', override[1] if override else 'reset')
        if original['font_scale'] == 'null':
            adb('shell', 'settings', 'delete', 'system', 'font_scale')
        else:
            adb('shell', 'settings', 'put', 'system', 'font_scale', original['font_scale'])
        # Only the unique temporary package is removed; the installed example is untouched.
        subprocess.run(['adb', '-s', SERIAL, 'uninstall', TEST_ID], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        restored = {'density': adb('shell', 'wm', 'density').strip(), 'font_scale': adb('shell', 'settings', 'get', 'system', 'font_scale').strip()}
        (OUT / 'device-restored.json').write_text(json.dumps(restored, indent=2))
        print('RESTORED ' + json.dumps(restored), flush=True)


if __name__ == '__main__':
    main()
