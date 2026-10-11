"""Dependency-free public-source integrity and privacy-pattern check."""
from pathlib import Path
from urllib.parse import unquote
import json,re,sys

ROOT=Path(__file__).resolve().parents[1]
SKIP={'.git','.godot','.tools','build','evidence','.publication','__pycache__'}
required=['README.md','README.zh-CN.md','LICENSE','NOTICE.md','CONTRIBUTING.md',
          'SECURITY.md','CHANGELOG.md','project.godot','export_presets.cfg',
          'docs/english/PLAYING.md','docs/english/BUILDING.md',
          'docs/english/ARCHITECTURE.md','docs/english/ASSET_PROVENANCE.md',
          'docs/public-demo/index.html','tests/public_smoke.gd','tests/combat_smoke.gd']
failures=[]
def check(condition,label):
    if not condition:failures.append(label)
for name in required:check((ROOT/name).is_file(),'Missing required file: '+name)
files=[p for p in ROOT.rglob('*') if p.is_file() and not (set(p.relative_to(ROOT).parts)&SKIP)]
patterns={
 'absolute Windows directory':r'(?i)\b[A-Z]:[/\\](?!/)',
 'personal Unix directory':r'/(?:Users|home)/[A-Za-z0-9_.-]+/',
 'credential-bearing URL':r'https?://[^/\s:@]+:[^/\s@]+@',
 'conversation identifier':r'(?i)(?:thread|conversation)[_-]?id["\s:=]+[0-9a-f]{8}-[0-9a-f-]{27,}',
 'GitHub credential':r'gh[pousr]_[A-Za-z0-9]{25,}',
 'API credential':r'sk-[A-Za-z0-9_-]{32,}',
 'private key':r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----',
}
texts={}
for path in files:
    name=path.relative_to(ROOT).as_posix()
    check(path.stat().st_size<99_000_000,'Oversized Git object: '+name)
    data=path.read_bytes()
    textual=path.suffix in {'.md','.html','.gd','.gdshader','.json','.cfg','.godot','.py','.ps1','.yml','.svg','.txt','.tscn','.tres','.import','.uid'} or path.name in {'LICENSE','.gitignore','.gitattributes','.editorconfig'}
    content=data.decode('utf-8',errors='ignore') if textual else '\n'.join(s.decode('ascii') for s in re.findall(rb'[\x20-\x7e]{16,}',data))
    for kind,pattern in patterns.items():
        check(not re.search(pattern,content),kind+': '+name)
    if path.suffix in {'.md','.html','.gd','.json','.cfg','.godot','.py','.ps1','.yml'}:texts[path]=content
for path,text in texts.items():
    if path.suffix in {'.md','.html'}:
        links=re.findall(r'\]\(([^)]+)\)',text) if path.suffix=='.md' else re.findall(r'(?:href|src)=["\']([^"\']+)',text)
        for raw in links:
            value=raw.split('#')[0].split('?')[0].strip('<>')
            if not value or re.match(r'^(?:https?:|mailto:|data:)',value):continue
            check(not value.startswith('file:'),'Local file URL: '+path.name)
            check((path.parent/unquote(value)).is_file(),'Broken document link in '+path.relative_to(ROOT).as_posix()+': '+value)
    if path.suffix=='.gd':
        for target in re.findall(r'(?:preload|load)\(["\']res://([^"\']+)["\']\)',text):
            check((ROOT/target).exists(),'Missing script dependency: '+target)
for registry in ['assets/ui/integration/material-registry.json','assets/ui/r03/material-registry.json']:
    if (ROOT/registry).exists():
        for asset in json.loads((ROOT/registry).read_text(encoding='utf-8-sig'))['assets']:
            if asset.get('rerender'):check((ROOT/asset['rerender']).is_file(),'Missing UI runtime image: '+asset['id'])
bank=ROOT/'assets/audio/bank.json'
if bank.exists():
    for cue in json.loads(bank.read_text(encoding='utf-8-sig'))['cues'].values():
        for resource in cue['files']:check((ROOT/resource.removeprefix('res://')).is_file(),'Missing runtime sound')
project=(ROOT/'project.godot').read_text(encoding='utf-8') if (ROOT/'project.godot').exists() else ''
check('scenes/frontend/main.tscn' in project,'Incorrect main scene')
check('[editor_plugins]' not in project,'Private evidence plugins must not be enabled')
check('.tools/' not in (ROOT/'export_presets.cfg').read_text(encoding='utf-8'),'Export depends on workstation tools')
result={'success':not failures,'checked_files':len(files),'failures':failures,
        'scope':'Static resource, documentation, size and privacy patterns. Not a claim that all possible private data can be detected automatically.'}
print(json.dumps(result,indent=2))
sys.exit(1 if failures else 0)
