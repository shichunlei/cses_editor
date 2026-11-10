"""Audit standalone sources, local package edges, resolved graph and optional APK."""
from pathlib import Path
from urllib.parse import unquote, urlparse
import os
import argparse
import json
import re
import zipfile

FORBIDDEN = re.compile(
    r"(?:cses_document_collab|cses_mobile_collab_demo|cses_common|"
    r"flutter_rust_bridge|cses_collab_core|sqflite|sqlite3|yrs)(?:_|$)"
)
PACKAGES = ('.', 'example')
EDITOR_FORK = 'applowy_editor_fork'
PUB_DEV_URL = 'https://pub.dev'
IGNORED = {'.git', '.dart_tool', '.gradle', '.symlinks', 'build', 'Pods', 'ephemeral'}


def _uri_path(base, value):
    """Resolve URI paths against base, including escaped spaces and file URIs."""
    parsed = urlparse(value)
    if parsed.scheme not in ('', 'file') or parsed.netloc not in ('', 'localhost'):
        raise ValueError(f'Unsupported local dependency URI: {value}')
    path = Path(unquote(parsed.path))
    return (path if path.is_absolute() else base / path).resolve()


def audit_project(root, apk=None):
    """Return an audit report without mutating the project or its dependencies."""
    root = Path(root).resolve()
    issues = []
    checked_dart = 0
    checked_configs = 0
    source_roots = [(root / 'lib', root, ''), (root / 'test', root, ''),
                    (root / 'example', root, ''), (root / 'pubspec.yaml', root, ''),
                    (root / 'pubspec_overrides.yaml', root, '')]
    editor_fork_locks = {}
    scanned_fork_roots = set()
    hosted_cache = Path(os.environ.get('PUB_CACHE', str(Path.home() / '.pub-cache'))) / 'hosted' / 'pub.dev'
    if (root / 'packages').exists():
        issues.append('Legacy packages layout must be removed; cses_editor is the root package')
    for folder in PACKAGES:
        lock = root / folder / 'pubspec.lock'
        local_packages = set()
        fork_release = None
        if not lock.exists():
            issues.append(f'Run flutter pub get in {folder}: missing pubspec.lock')
        else:
            # Pub writes a fixed block layout; this is the resolved source authority,
            # including transitive local packages that are absent from pubspec.yaml.
            for block in re.finditer(r'^  ([\w]+):\n(.*?)(?=^  [\w]+:|\Z)', lock.read_text(), re.M | re.S):
                if FORBIDDEN.match(block[1]):
                    issues.append(f'{folder}: forbidden locked dependency {block[1]}')
                if block[1] == 'appflowy_editor':
                    issues.append(f'{folder}: use {EDITOR_FORK} in place of appflowy_editor')
                if block[1] == EDITOR_FORK:
                    fields = {
                        key: value.strip().strip('"\'')
                        for key, value in re.findall(
                            r'^ {4,6}(name|url|sha256|source|version): (.+)$', block[2], re.M
                        )
                    }
                    if (fields.get('source') != 'hosted' or fields.get('url') != PUB_DEV_URL
                            or fields.get('name') != EDITOR_FORK
                            or not re.fullmatch(r'[0-9a-f]{64}', fields.get('sha256', ''))
                            or not re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][\w.+-]+)?', fields.get('version', ''))):
                        issues.append(f'{folder}: {EDITOR_FORK} must resolve to a pub.dev release with a checksum')
                    else:
                        fork_release = fields
                        editor_fork_locks[folder] = fields
                if re.search(r'^    source: path\s*$', block[2], re.M):
                    local_packages.add(block[1])
                    value = re.search(r'^      path: (.+)$', block[2], re.M)
                    if value:
                        raw = value[1].strip()
                        raw = json.loads(raw) if raw.startswith('"') else raw.strip("'")
                        try:
                            if not _uri_path(lock.parent, raw).is_relative_to(root):
                                issues.append(f'{folder}: external locked path {raw}')
                        except ValueError as error:
                            issues.append(str(error))
        path = root / folder / '.dart_tool/package_config.json'
        if not path.exists():
            issues.append(f'Run flutter pub get in {folder}')
            continue
        packages = json.loads(path.read_text())['packages']
        if fork_release and all(package['name'] != EDITOR_FORK for package in packages):
            issues.append(f'{folder}: {EDITOR_FORK} is missing from the resolved package config')
        for package in packages:
            if FORBIDDEN.match(package['name']):
                issues.append(f'{folder}: forbidden dependency {package["name"]}')
            if package['name'] in local_packages | {'cses_editor', 'cses_offline_example'}:
                try:
                    source = _uri_path(path.parent, package['rootUri'])
                    if not source.is_relative_to(root):
                        issues.append(f'{folder}: external workspace dependency {source}')
                    if package['name'] == 'cses_editor' and source != root:
                        issues.append(f'{folder}: cses_editor must resolve to the project root')
                except ValueError as error:
                    issues.append(str(error))
            if package['name'] == EDITOR_FORK:
                try:
                    source = _uri_path(path.parent, package['rootUri'])
                    if fork_release is None:
                        issues.append(f'{folder}: {EDITOR_FORK} is missing a valid pub.dev lock entry')
                        continue
                    expected = hosted_cache.resolve() / f"{EDITOR_FORK}-{fork_release['version']}"
                    if source != expected or not (source / 'pubspec.yaml').is_file():
                        issues.append(f'{folder}: {EDITOR_FORK} must resolve from the locked pub.dev cache directory')
                        continue
                    if source not in scanned_fork_roots:
                        scanned_fork_roots.add(source)
                        prefix = f'pub.dev:{EDITOR_FORK}/'
                        source_roots.extend([(source / 'lib', source, prefix), (source / 'pubspec.yaml', source, prefix)])
                except ValueError as error:
                    issues.append(str(error))

    if len({(release['version'], release['sha256']) for release in editor_fork_locks.values()}) > 1:
        issues.append(f'Local consumers disagree on the {EDITOR_FORK} release')
    for folder, base, prefix in source_roots:
        for path in (folder.rglob('*') if folder.is_dir() else [folder]):
            if any(part in IGNORED for part in path.relative_to(base).parts):
                continue
            if path.is_symlink() and not path.resolve().is_relative_to(base):
                issues.append(f'External source symlink: {prefix}{path.relative_to(base)}')
            if not path.is_file():
                continue
            text = None
            if path.suffix == '.dart':
                checked_dart += 1
                text = path.read_text()
                # Only active directives count, not provenance or DartDoc examples.
                text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.M)
                text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
                for directive in re.finditer(r'^\s*(?:import|export|part)\s+([^;]+);', text, re.M):
                    for reference in re.findall(r"['\"]([^'\"]+)['\"]", directive[1]):
                        package = reference.removeprefix('package:').split('/')[0]
                        if '/native/' in reference or (reference.startswith('package:') and FORBIDDEN.match(package)):
                            issues.append(f'{prefix}{path.relative_to(base)}: {reference}')
            if path.name in ('pubspec.yaml', 'pubspec_overrides.yaml'):
                checked_configs += 1
                text = path.read_text()
                if re.search(r'^\s+ffiPlugin:\s*true\b', text, re.M):
                    issues.append(f'{prefix}{path.relative_to(base)}: ffiPlugin found')
                # Dependency names are two-space YAML keys; path entries nest deeper.
                for name in re.findall(r'^  ([\w]+):', text, re.M):
                    if FORBIDDEN.match(name):
                        issues.append(f'{prefix}{path.relative_to(base)}: forbidden dependency {name}')
                for value in re.findall(r'^ {4,}path:\s*([^\n#]+)', text, re.M):
                    value = value.strip().strip("'\"")
                    try:
                        target = _uri_path(path.parent, value)
                        if not target.is_relative_to(root):
                            issues.append(f'{prefix}{path.relative_to(base)}: external path {value}')
                    except ValueError as error:
                        issues.append(str(error))
            if path.name.endswith(('.gradle', '.gradle.kts', '.podspec', '.xcconfig')) or path.name in ('Cargo.toml', 'CMakeLists.txt', 'Podfile'):
                checked_configs += 1
                for value in re.findall(r'cses_document_collab|cses_mobile_collab_demo|cses_common|flutter_rust_bridge|cses_collab_core', path.read_text()):
                    issues.append(f'{prefix}{path.relative_to(base)}: native configuration references {value}')


    report = {'source_boundary': not issues, 'checked_dart_files': checked_dart,
              'checked_build_configs': checked_configs, 'editor_fork_locks': editor_fork_locks, 'issues': issues}
    if apk is not None:
        apk = Path(apk)
        with zipfile.ZipFile(apk) as archive:
            libraries = [name for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')]
            report.update(apk=str(apk), libraries=libraries)
            for name in libraries:
                if re.search(r'cses|collab|rust|yrs|sqlite', name, re.I):
                    issues.append(f'Unexpected native library: {name}')
            for name in archive.namelist():
                if name.endswith('.dex'):
                    data = archive.read(name)
                    for marker in (b'CsesDocumentCollabPlugin', b'cses_collab_core', b'flutter_rust_bridge', b'com/tekartik/sqflite'):
                        if marker in data:
                            issues.append(f'{name}: {marker.decode()}')
    report['passed'] = not issues
    return report


def main():
    """Print machine-readable evidence and fail on any broken boundary."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', nargs='?')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    report = audit_project(args.root, args.apk)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
