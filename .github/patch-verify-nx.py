from pathlib import Path

path = Path('.github/verify-nx.sh')
text = path.read_text()
text = text.replace(
    "const { createProjectGraphAsync, parseJson } = require('@nx/devkit');",
    "const { createProjectGraphAsync, parseJson, visitNotIgnoredFiles } = require('@nx/devkit');",
)
text = text.replace(
    '"baseUrl": ".",\n    "paths":',
    '"baseUrl": ".",\n    "ignoreDeprecations": "6.0",\n    "paths":',
)
text = text.replace("'^production'", "'^default'")
text = text.replace(
    "echo '=== incompatible Nx-style flag control ==='\n  set +e",
    "echo '=== incompatible Nx-style flag control ==='\n  rm -f .nx/typecheck/next-app.tsbuildinfo\n  set +e",
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
text = text.replace(old, new)
text = text.replace(
    "if (!t.command.includes('--build tsconfig.json --emitDeclarationOnly')) {\n  throw new Error(`Unexpected built-in leaf command: ${t.command}`);\n}",
    "const command = t.options?.command ?? t.command;\nif (!command.includes('--build tsconfig.json --emitDeclarationOnly')) {\n  throw new Error(`Unexpected built-in leaf command: ${command}`);\n}",
)
path.write_text(text)
