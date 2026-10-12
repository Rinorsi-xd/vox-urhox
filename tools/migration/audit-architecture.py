"""Read user Lua only; report literal local dependencies and ownership boundaries.

This is a static inventory, not proof of runtime independence or memory safety.
Engine reference trees are deliberately excluded.
"""
from pathlib import Path
import json
import re
import subprocess

root = Path(__file__).resolve().parents[2]
files = {str(p.relative_to(root / 'scripts')).replace('\\', '/')[:-4].replace('/', '.'): p
         for p in (root / 'scripts').rglob('*.lua')}
pattern = re.compile(r'''\brequire\s*\(?\s*["']([^"']+)["']''')
graph, counts = {}, {}
for name, path in files.items():
    text = path.read_text(encoding='utf-8-sig')
    counts[name] = len(text.splitlines())
    graph[name] = sorted({m.replace('/', '.') for m in pattern.findall(text)} & files.keys())

# Strongly connected components expose cycles including deferred literal requires.
counter = 0
indices, low, stack, active, cycles = {}, {}, [], set(), []
def visit(node):
    global counter
    indices[node] = low[node] = counter
    counter += 1
    stack.append(node)
    active.add(node)
    for dependency in graph[node]:
        if dependency not in indices:
            visit(dependency)
            low[node] = min(low[node], low[dependency])
        elif dependency in active:
            low[node] = min(low[node], indices[dependency])
    if low[node] == indices[node]:
        component = []
        while True:
            member = stack.pop()
            active.remove(member)
            component.append(member)
            if member == node:
                break
        if len(component) > 1 or node in graph[node]:
            cycles.append(sorted(component))
for node in graph:
    if node not in indices:
        visit(node)

boundaries = [{'source': a, 'dependency': b} for a, edges in graph.items() for b in edges
              if a.split('.')[0] in ('build', 'combat', 'drive', 'physics')
              and b.split('.')[0] in ('app', 'render', 'ui', 'controls')]
git = subprocess.run(['git', '-C', str(root), 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
report = dict(scope='scripts/**/*.lua; literal require edges only; no engine reference code',
              modules=len(files), edges=sum(map(len, graph.values())),
              largest_modules=[dict(module=n, lines=c) for n, c in sorted(counts.items(), key=lambda x: -x[1])[:12]],
              modules_over_1500=[n for n, c in counts.items() if c > 1500], cycles=cycles,
              simulation_to_presentation=boundaries,
              git_repository=git.stdout.strip() if git.returncode == 0 else None,
              dependencies=graph)
output = root / 'docs/migration/evidence/architecture-audit.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'dependencies'}, ensure_ascii=False, indent=2))
