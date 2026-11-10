"""Regression coverage for dependency paths that the original audit missed."""
import json
import os
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest
from verify_independence import audit_project, _uri_path


class IndependenceAuditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ('.', 'example'):
            path = self.root / folder
            (path / '.dart_tool').mkdir(parents=True)
            (path / 'lib').mkdir()
            (path / 'pubspec.lock').write_text('packages: {}\n')
            (path / 'pubspec.yaml').write_text('name: sample\ndependencies:\n  path: ^1.9.1\n')
            (path / '.dart_tool/package_config.json').write_text(json.dumps({'packages': []}))

    def test_clean_graph_and_provenance_comments_pass(self):
        (self.root / 'example/lib/main.dart').write_text("/// import 'package:cses_document_collab/old.dart';\nimport 'dart:async';")
        self.assertTrue(audit_project(self.root)['passed'])

    def test_local_conditional_import_is_checked(self):
        (self.root / 'lib/bad.dart').write_text("import 'stub.dart'\n if (dart.library.io) 'package:cses_common/runtime.dart';")
        self.assertFalse(audit_project(self.root)['passed'])

    def test_any_declared_external_path_is_rejected(self):
        (self.root / 'example/pubspec_overrides.yaml').write_text('dependency_overrides:\n  other_library:\n    path: ../../outside\n')
        self.assertFalse(audit_project(self.root)['passed'])

    def test_native_configuration_is_checked(self):
        (self.root / 'example/Podfile').write_text("pod 'cses_collab_core'")
        self.assertFalse(audit_project(self.root)['passed'])

    def test_indirect_sqlite_variant_is_rejected(self):
        path = self.root / 'example/.dart_tool/package_config.json'
        path.write_text(json.dumps({'packages': [{'name': 'sqflite_android', 'rootUri': 'file:///cache/plugin'}]}))
        self.assertFalse(audit_project(self.root)['passed'])

    def test_file_uri_inside_project_and_escaped_space_pass(self):
        path = self.root / '.dart_tool/package_config.json'
        destination = self.root / 'with space'
        destination.mkdir()
        path.write_text(json.dumps({'packages': [{'name': 'cses_editor', 'rootUri': self.root.as_uri()}]}))
        self.assertEqual(_uri_path(self.root, destination.as_uri()), destination.resolve())
        self.assertTrue(audit_project(self.root)['passed'])

    def test_transitive_external_locked_path_is_rejected(self):
        (self.root / 'example/pubspec.lock').write_text(
            'packages:\n  innocent_name:\n    description:\n      path: "../../outside"\n'
            '      relative: true\n    source: path\n    version: "1.0.0"\n')
        self.assertFalse(audit_project(self.root)['passed'])

    def _hosted_editor_fork(self, contents="import 'dart:async';"):
        cache = self.root / 'pub-cache'
        source = cache / 'hosted/pub.dev/applowy_editor_fork-6.2.1'
        (source / 'lib').mkdir(parents=True)
        (source / 'lib/editor.dart').write_text(contents)
        (source / 'pubspec.yaml').write_text('name: applowy_editor_fork\n')
        checksum = 'a' * 64
        lock = (
            'packages:\n  applowy_editor_fork:\n    description:\n'
            '      name: applowy_editor_fork\n      url: "https://pub.dev"\n'
            f'      sha256: "{checksum}"\n'
            '    source: hosted\n    version: "6.2.1"\n'
        )
        for folder in ('.', 'example'):
            (self.root / folder / 'pubspec.lock').write_text(lock)
            (self.root / folder / '.dart_tool/package_config.json').write_text(json.dumps({
                'packages': [{'name': 'applowy_editor_fork', 'rootUri': source.as_uri()}]
            }))
        context = patch.dict(os.environ, {'PUB_CACHE': str(cache)})
        context.start()
        self.addCleanup(context.stop)

    def test_hosted_editor_fork_is_accepted(self):
        self._hosted_editor_fork()
        self.assertTrue(audit_project(self.root)['passed'])

    def test_hosted_editor_fork_runtime_sources_are_checked(self):
        self._hosted_editor_fork("import 'package:cses_common/runtime.dart';")
        self.assertFalse(audit_project(self.root)['passed'])

    def test_editor_fork_host_must_match(self):
        self._hosted_editor_fork()
        lock = self.root / 'example/pubspec.lock'
        lock.write_text(lock.read_text().replace('https://pub.dev', 'https://other.example'))
        self.assertFalse(audit_project(self.root)['passed'])

    def test_editor_fork_cache_directory_must_match_locked_version(self):
        self._hosted_editor_fork()
        lock = self.root / 'example/pubspec.lock'
        lock.write_text(lock.read_text().replace('6.2.1', '6.2.2'))
        self.assertFalse(audit_project(self.root)['passed'])

    def test_vendored_directory_is_rejected(self):
        (self.root / 'packages/appflowy_editor').mkdir(parents=True)
        self.assertFalse(audit_project(self.root)['passed'])

    def test_example_must_resolve_editor_at_root(self):
        path = self.root / 'example/.dart_tool/package_config.json'
        nested = self.root / 'nested'
        nested.mkdir()
        path.write_text(json.dumps({'packages': [{'name': 'cses_editor', 'rootUri': nested.as_uri()}]}))
        self.assertFalse(audit_project(self.root)['passed'])

    def test_source_symlink_cannot_reach_original_workspace(self):
        outside = self.root.parent / 'outside-library'
        (self.root / 'example/lib/linked.dart').symlink_to(outside)
        self.assertFalse(audit_project(self.root)['passed'])


if __name__ == '__main__':
    unittest.main()
