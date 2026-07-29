from pathlib import Path

path = Path('.github/verify-nx.sh')
text = path.read_text()
text = text.replace(
    "const { createProjectGraphAsync, parseJson } = require('@nx/devkit');",
    "const { createProjectGraphAsync, parseJson, visitNotIgnoredFiles } = require('@nx/devkit');",
)
old = """  const files = (rootNode.data.files || [])
    .map((x) => x.file.replaceAll('\\\\', '/'))
    .filter((x) => EXT.test(x))
    .filter((x) => x !== ROOT && x !== SOLUTION)
    .sort();"""
new = """  const nestedRoots = Object.values(graph.nodes)
    .map((n) => n.data.root.replaceAll('\\\\', '/'))
    .filter((root) => root !== '.')
    .sort((a, b) => b.length - a.length);
  const files = [];
  visitNotIgnoredFiles(tree, '.', (path) => {
    const normalized = path.replaceAll('\\\\', '/').replace(/^\\.\\//, '');
    if (!EXT.test(normalized) || normalized === ROOT || normalized === SOLUTION) return;
    if (nestedRoots.some((root) => normalized === root || normalized.startsWith(`${root}/`))) return;
    files.push(normalized);
  });
  files.sort();"""
if old not in text:
    raise SystemExit('Expected generator block not found')
path.write_text(text.replace(old, new))
