from pathlib import Path
import shutil,json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
target=b/'allocation17750-candidate'
assert not target.exists()
shutil.copytree(b/'allocation17748-candidate',target)
p=target/'text/platform_io.slg';t=p.read_text(encoding='utf-8')
old='    "$(prefix)_allocation_failed" -> materialize(names!) => failureIdentity'
assert t.count(old)==1
t=t.replace(old,'    Arena(0) => failureNames!\n    "$(prefix)_allocation_failed" -> materialize(failureNames!) => failureIdentity')
p.write_text(t,encoding='utf-8')
(b/'allocation17750-sources.txt').write_text((b/'allocation17748-sources.txt').read_text().replace('allocation17748-candidate','allocation17750-candidate'),encoding='utf-8')
m=json.loads((b/'allocation17748-provider-map.json').read_text())
(b/'allocation17750-provider-map.json').write_text(json.dumps({k:v.replace('allocation17748-candidate','allocation17750-candidate') for k,v in m.items()},indent=2)+'\n',encoding='utf-8')
