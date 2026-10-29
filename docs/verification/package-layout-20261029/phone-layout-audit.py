from pathlib import Path
import json,re
r=Path('/System/Volumes/Data/workspace/cses_editor');old=r.parent/'cses_offline_editor';out=r/'docs/verification/package-layout-20261029/phone-path-audit.json'
files=[]
for folder in ['lib','test','tool','example/lib','example/test','example/integration_test','example/test_driver','example/android','example/ios']:
 for p in (r/folder).rglob('*'):
  if not p.is_file() or any(part in {'build','.dart_tool','.gradle','Pods','.symlinks','ephemeral','__pycache__'} for part in p.relative_to(r).parts):continue
  if p.suffix in {'.dart','.py','.mjs','.yaml','.json','.xml','.kts','.gradle','.properties','.plist','.xcconfig','.pbxproj','.xcscheme','.sh'}:files.append(p)
files += [r/x for x in ['pubspec.yaml','pubspec.lock','example/pubspec.yaml','example/pubspec.lock','example/.metadata','example/.dart_tool/package_config.json','.dart_tool/package_config.json','example/ios/Flutter/Generated.xcconfig','example/ios/Flutter/flutter_export_environment.sh'] if (r/x).is_file()]
issues=[];allowed=[]
for p in set(files):
 try:text=p.read_text()
 except UnicodeDecodeError:continue
 for i,line in enumerate(text.splitlines(),1):
  if 'cses_offline_editor' in line or '../packages/cses_editor' in line or 'packages/cses_editor/lib' in line:
   issues.append({'file':str(p.relative_to(r)),'line':i,'text':line.strip()})
  elif 'packages/cses_editor/assets/' in line:
   allowed.append({'file':str(p.relative_to(r)),'line':i,'reason':'Flutter package asset URI, not a disk dependency'})
roots={}
for folder in ['.','example']:
 base=r/folder;config=base/'.dart_tool/package_config.json';entry=next(p for p in json.loads(config.read_text())['packages'] if p['name']=='cses_editor');resolved=(config.parent/entry['rootUri']).resolve();roots[folder]=str(resolved)
 if resolved!=r:issues.append({'file':str(config),'reason':'wrong root resolution'})
report={'root':str(r),'scanned_text_files':len(set(files)),'old_root_exists':old.exists(),'legacy_packages_directory_exists':(r/'packages').exists(),'issues':issues,'allowed_asset_references':allowed,'resolved_roots':roots,'passed':not issues and not old.exists() and not (r/'packages').exists(),'historical_records':'docs/verification and source provenance retain original paths as evidence'}
out.write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
assert report['passed']
