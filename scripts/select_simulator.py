#!/usr/bin/env python3
"""Select an installed iPhone runtime for the SDK actually used by Xcode."""
import json
import os
import re
import subprocess


def choose_device(devices, sdk_version):
    sdk = tuple(map(int, sdk_version.split('.')[:2]))
    candidates = []
    for runtime, group in devices.items():
        match = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-\d+)?', runtime)
        if not match or tuple(map(int, match.groups())) != sdk:
            continue
        candidates.extend(d for d in group if d.get('isAvailable', True) and 'iPhone' in d['name'])
    if not candidates:
        raise RuntimeError(f'No installed iPhone simulator matches iOS SDK {sdk_version}. Check the pinned Xcode image.')
    # Prefer the user's screen size; otherwise use an existing Pro Max. Never download a runtime.
    candidates.sort(key=lambda d: (d['name'] != 'iPhone 11 Pro Max', 'Pro Max' not in d['name'], d['name'], d['udid']))
    return candidates[0]


def main():
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True).strip()
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], text=True))['devices']
    device = choose_device(devices, sdk)
    print(f"Testing on {device['name']} with iOS {sdk}: {device['udid']}", flush=True)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('id=' + device['udid'] + '\n')
    if device.get('state') != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True, timeout=60)


if __name__ == '__main__':
    main()
