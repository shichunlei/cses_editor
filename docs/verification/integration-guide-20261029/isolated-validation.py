from pathlib import Path
from urllib.parse import urlparse,unquote
import tempfile,subprocess,shutil,json,hashlib,zipfile,re
root=Path('/System/Volumes/Data/workspace/cses_editor');evidence=root/'docs/verification/integration-guide-20261029';temp=Path(tempfile.mkdtemp(prefix='cses-public-host-')).resolve();dist=temp/'cses_editor';host=temp/'cses_editor_host_sample';dist.mkdir()
for name in ['lib','assets','third_party']:shutil.copytree(root/name,dist/name,ignore=shutil.ignore_patterns('.DS_Store'))
for name in ['pubspec.yaml','pubspec.lock','README.md']:shutil.copyfile(root/name,dist/name)
results={'temporary_workspace':str(temp),'distribution_has_example':(dist/'example').exists(),'distribution_files':['lib','assets','third_party','pubspec.yaml','pubspec.lock','README.md'],'steps':{}}
def run(name,args,cwd):
 with (evidence/(name+'.txt')).open('w') as output:
  p=subprocess.run(args,cwd=cwd,stdout=output,stderr=subprocess.STDOUT)
 results['steps'][name]=p.returncode
 (evidence/'isolated-result.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 if p.returncode:raise SystemExit(f'{name} failed: {p.returncode}')
run('isolated-create',['flutter','create','--platforms=android','--empty','--org','com.cses.integration','--project-name','cses_editor_host_sample',str(host)],temp)
sample=root/'docs/integration_app'
shutil.rmtree(host/'lib');shutil.copytree(sample/'lib',host/'lib',ignore=shutil.ignore_patterns('.DS_Store'))
if (host/'test').exists():shutil.rmtree(host/'test')
shutil.copytree(sample/'test',host/'test')
shutil.copyfile(sample/'analysis_options.yaml',host/'analysis_options.yaml')
(host/'pubspec.yaml').write_text((sample/'pubspec.yaml').read_text().replace('path: ../..','path: ../cses_editor'))
run('isolated-pub-get',['flutter','pub','get','--offline'],host)
run('isolated-analysis',['flutter','analyze','--no-pub'],host)
run('isolated-tests',['flutter','test','--no-pub'],host)
config=host/'.dart_tool/package_config.json';packages=json.loads(config.read_text())['packages'];forbidden=re.compile(r'(cses_document_collab|cses_offline_example|flutter_rust_bridge|cses_collab|cses_common|sqflite|sqlite3|yrs)')
assert not any(forbidden.search(x['name']) for x in packages)
resolved={}
for p in packages:
 uri=urlparse(p['rootUri']);path=Path(unquote(uri.path));path=(config.parent/path).resolve() if not path.is_absolute() else path.resolve()
 assert not path.is_relative_to(root),str(path)
 if p['name'] in ['cses_editor','cses_editor_host_sample','appflowy_editor']:resolved[p['name']]=str(path)
assert resolved['cses_editor']==str(dist)
assert not (dist/'example').exists()
for f in (host/'lib').rglob('*.dart'):
 text=f.read_text();assert not re.search(r"(?:import|export)\s+['\"]package:cses_editor/src/",text);assert 'cses_offline_example' not in text
results['resolved_packages']=resolved;results['package_names']=[x['name'] for x in packages];results['original_workspace_dependency']=False;results['example_dependency']=False;results['public_imports_only']=True
run('isolated-android-build',['flutter','build','apk','--debug','--no-pub','--target-platform','android-arm64'],host)
apk=host/'build/app/outputs/flutter-apk/app-debug.apk';results['apk']={'path':str(apk),'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'bytes':apk.stat().st_size}
run('isolated-apk-independence',['python3',str(root/'tool/verify_independence.py'),str(apk)],root)
shutil.copyfile(host/'pubspec.lock',evidence/'isolated-host-lock.txt')
results['passed']=True
(evidence/'isolated-result.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':True,'temporary_workspace':str(temp)},ensure_ascii=False))
