#!/usr/bin/env bash
set -euo pipefail

rm -rf nx-verification
mkdir nx-verification
cd nx-verification

cat > package.json <<'JSON'
{
  "name": "nx-typescript-verification",
  "private": true,
  "version": "0.0.0",
  "workspaces": ["apps/*", "packages/*", "tools/*"],
  "scripts": {},
  "devDependencies": {
    "@nx/devkit": "23.1.0",
    "@nx/js": "23.1.0",
    "jsonc-parser": "3.3.1",
    "nx": "23.1.0",
    "typescript": "6.0.3"
  },
  "nx": {
    "name": "root",
    "projectType": "application"
  }
}
JSON
npm install --ignore-scripts

mkdir -p packages/lib/src apps/leaf/src apps/next-app/src tools/nx-typescript-extensions/src/generators/sync-root-typescript .github-output

cat > nx.json <<'JSON'
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "plugins": [
    {
      "plugin": "@nx/js/typescript",
      "options": {
        "typecheck": { "targetName": "typecheck", "configName": "tsconfig.json" },
        "build": false
      }
    },
    {
      "plugin": "@workspace/nx-typescript-extensions",
      "options": {
        "projectTargetName": "typecheck-project",
        "buildTargetName": "typecheck-build"
      }
    }
  ],
  "sync": {
    "applyChanges": true,
    "globalGenerators": [
      "@nx/js:typescript-sync",
      "@workspace/nx-typescript-extensions:sync-root-typescript"
    ]
  },
  "targetDefaults": {
    "typecheck": { "cache": true },
    "typecheck-project": { "cache": true },
    "typecheck-build": { "cache": true }
  }
}
JSON

cat > tsconfig.base.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": { "@demo/lib": ["packages/lib/src/index.ts"] }
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "files": [],
  "references": []
}
JSON

cat > root-visible.ts <<'TS'
import { greet } from '@demo/lib';
export const rootGreeting: string = greet({ name: 'Root' });
TS
cat > root-visible.js <<'JS'
// @ts-check
/** @type {number} */
const rootNumber = 42;
module.exports = { rootNumber };
JS
cat > root-visible.json <<'JSON'
{"enabled": true}
JSON
cat > ignored-root-error.ts <<'TS'
const ignoredRootError: string = 123;
TS
mkdir ignored-folder
cat > ignored-folder/ignored-folder-error.ts <<'TS'
const ignoredFolderError: boolean = 'wrong';
TS
cat > .gitignore <<'EOF'
node_modules/
dist/
.nx/
ignored-root-error.ts
ignored-folder/
EOF

cat > packages/lib/package.json <<'JSON'
{
  "name": "@demo/lib",
  "version": "0.0.0",
  "private": true,
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "nx": { "name": "lib", "projectType": "library" }
}
JSON
cat > packages/lib/tsconfig.json <<'JSON'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "tsBuildInfoFile": "dist/lib.tsbuildinfo"
  },
  "include": ["src/**/*.ts"]
}
JSON
cat > packages/lib/src/index.ts <<'TS'
export interface User { name: string }
export function greet(user: User): string { return `Hello ${user.name}`; }
TS

cat > apps/leaf/package.json <<'JSON'
{
  "name": "leaf-app",
  "version": "0.0.0",
  "private": true,
  "dependencies": { "@demo/lib": "0.0.0" },
  "nx": { "name": "leaf", "projectType": "application" }
}
JSON
cat > apps/leaf/tsconfig.json <<'JSON'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "tsBuildInfoFile": "dist/leaf.tsbuildinfo"
  },
  "references": [{ "path": "../../packages/lib" }],
  "include": ["src/**/*.ts"]
}
JSON
cat > apps/leaf/src/main.ts <<'TS'
import { greet } from '@demo/lib';
export const leafGreeting = greet({ name: 'Leaf' });
TS

cat > apps/next-app/package.json <<'JSON'
{
  "name": "next-app",
  "version": "0.0.0",
  "private": true,
  "dependencies": { "@demo/lib": "0.0.0" },
  "nx": { "name": "next-app", "projectType": "application" }
}
JSON
cat > apps/next-app/next.config.js <<'JS'
module.exports = {};
JS
cat > apps/next-app/tsconfig.json <<'JSON'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "noEmit": true,
    "emitDeclarationOnly": false,
    "incremental": true,
    "jsx": "preserve",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowJs": true,
    "resolveJsonModule": true,
    "rootDir": "src",
    "tsBuildInfoFile": "../../.nx/typecheck/next-app.tsbuildinfo"
  },
  "references": [{ "path": "../../packages/lib" }],
  "include": ["src/**/*.ts", "src/**/*.tsx", "src/**/*.js"]
}
JSON
cat > apps/next-app/src/jsx.d.ts <<'TS'
declare namespace JSX { interface IntrinsicElements { main: unknown } }
TS
cat > apps/next-app/src/page.tsx <<'TSX'
import { greet } from '@demo/lib';
export default function Page() { return <main>{greet({ name: 'Next' })}</main>; }
TSX

cat > tools/nx-typescript-extensions/package.json <<'JSON'
{
  "name": "@workspace/nx-typescript-extensions",
  "version": "0.0.0",
  "private": true,
  "type": "commonjs",
  "main": "./src/index.js",
  "generators": "./generators.json",
  "dependencies": { "jsonc-parser": "3.3.1" },
  "nx": { "name": "nx-typescript-extensions", "projectType": "library" }
}
JSON
cat > tools/nx-typescript-extensions/generators.json <<'JSON'
{
  "generators": {
    "sync-root-typescript": {
      "factory": "./src/generators/sync-root-typescript/generator",
      "schema": "./src/generators/sync-root-typescript/schema.json",
      "description": "Synchronize root TypeScript project"
    }
  }
}
JSON
cat > tools/nx-typescript-extensions/src/generators/sync-root-typescript/schema.json <<'JSON'
{"type":"object","properties":{}}
JSON

cat > tools/nx-typescript-extensions/src/index.js <<'JS'
const { createNodesFromFiles } = require('@nx/devkit');
const { existsSync } = require('node:fs');
const { basename, dirname, join } = require('node:path');

function hasNextConfig(workspaceRoot, projectRoot) {
  return ['js', 'cjs', 'mjs', 'ts'].some((ext) =>
    existsSync(join(workspaceRoot, projectRoot, `next.config.${ext}`))
  );
}

function target(command, projectRoot, configName, syncGenerators, description) {
  return {
    cache: true,
    command,
    dependsOn: ['^typecheck'],
    inputs: ['{projectRoot}/**/*', '^production', '{workspaceRoot}/.gitignore'],
    options: { cwd: projectRoot },
    outputs: projectRoot === '.'
      ? ['{workspaceRoot}/.nx/typecheck/tsconfig.root.tsbuildinfo']
      : ['{workspaceRoot}/.nx/typecheck/next-app.tsbuildinfo'],
    syncGenerators,
    metadata: { technologies: ['typescript'], description }
  };
}

const implementation = [
  '**/{tsconfig.root.json,tsconfig.json}',
  async (paths, options, context) => createNodesFromFiles((configPath) => {
    const root = dirname(configPath);
    const name = basename(configPath);
    const isRoot = root === '.' && name === 'tsconfig.root.json';
    const isNext = root !== '.' && name === 'tsconfig.json' && hasNextConfig(context.workspaceRoot, root);
    if (!isRoot && !isNext) return {};
    const sync = ['@nx/js:typescript-sync', '@workspace/nx-typescript-extensions:sync-root-typescript'];
    return { projects: { [root]: { targets: {
      [options.projectTargetName || 'typecheck-project']: target(
        `tsc --project ${name} --noEmit`, root, name, sync, 'Project-mode no-emit typecheck'
      ),
      [options.buildTargetName || 'typecheck-build']: target(
        `tsc --build ${name}`, root, name, sync, 'Build-mode leaf no-emit typecheck'
      )
    } } } };
  }, paths, options, context)
];
exports.createNodes = implementation;
exports.createNodesV2 = implementation;
JS

cat > tools/nx-typescript-extensions/src/generators/sync-root-typescript/generator.js <<'JS'
const { createProjectGraphAsync, parseJson } = require('@nx/devkit');
const { applyEdits, modify } = require('jsonc-parser');

const ROOT = 'tsconfig.root.json';
const SOLUTION = 'tsconfig.json';
const EXT = /\.(?:[cm]?[tj]sx?|json)$/i;

function read(tree, path) { return parseJson(tree.read(path, 'utf-8')); }
function patch(tree, path, keyPath, value) {
  const current = tree.exists(path) ? tree.read(path, 'utf-8') : '{}\n';
  const next = applyEdits(current, modify(current, keyPath, value, {
    formattingOptions: { insertSpaces: true, tabSize: 2, eol: '\n' }
  }));
  if (next === current) return false;
  tree.write(path, next);
  return true;
}

module.exports = async function generator(tree) {
  const graph = await createProjectGraphAsync();
  const rootNode = Object.values(graph.nodes).find((n) => n.data.root === '.');
  if (!rootNode) throw new Error('Missing Nx root project');
  const files = (rootNode.data.files || [])
    .map((x) => x.file.replaceAll('\\', '/'))
    .filter((x) => EXT.test(x))
    .filter((x) => x !== ROOT && x !== SOLUTION)
    .sort();
  let changed = false;
  changed = patch(tree, ROOT, ['extends'], './tsconfig.base.json') || changed;
  const opts = {
    allowJs: true,
    checkJs: true,
    composite: true,
    declaration: true,
    noEmit: true,
    resolveJsonModule: true,
    rootDir: '.',
    tsBuildInfoFile: './.nx/typecheck/tsconfig.root.tsbuildinfo'
  };
  for (const [key, value] of Object.entries(opts)) {
    changed = patch(tree, ROOT, ['compilerOptions', key], value) || changed;
  }
  changed = patch(tree, ROOT, ['files'], files) || changed;
  changed = patch(tree, ROOT, ['references'], [{ path: './packages/lib' }]) || changed;
  const solution = read(tree, SOLUTION);
  const refs = (solution.references || []).filter((r) => r.path !== './tsconfig.root.json');
  refs.push({ path: './tsconfig.root.json' });
  changed = patch(tree, SOLUTION, ['references'], refs) || changed;
  if (changed) return { outOfSyncMessage: 'Root TypeScript config out of sync' };
};
JS

npm install --ignore-scripts

export NX_DAEMON=false
export NX_TUI=false

{
  echo '=== versions ==='
  npx nx --version
  npx tsc --version

  echo '=== actual nx sync ==='
  npx nx sync
  npx nx sync:check

  echo '=== inferred project JSON ==='
  npx nx show project root --json > .github-output/root-project.json
  npx nx show project next-app --json > .github-output/next-project.json
  npx nx show project leaf --json > .github-output/leaf-project.json
  cat .github-output/root-project.json
  cat .github-output/next-project.json
  cat .github-output/leaf-project.json

  echo '=== generated root config ==='
  cat tsconfig.root.json
  grep -q 'root-visible.ts' tsconfig.root.json
  grep -q 'root-visible.js' tsconfig.root.json
  grep -q 'root-visible.json' tsconfig.root.json
  ! grep -q 'ignored-root-error.ts' tsconfig.root.json
  ! grep -q 'ignored-folder-error.ts' tsconfig.root.json
  ! grep -q 'apps/next-app' tsconfig.root.json
  ! grep -q 'packages/lib/src' tsconfig.root.json

  echo '=== built-in ordinary leaf inference ==='
  node - <<'NODE'
const fs = require('fs');
const p = JSON.parse(fs.readFileSync('.github-output/leaf-project.json','utf8'));
const t = p.targets.typecheck;
console.log(JSON.stringify(t, null, 2));
if (!t.command.includes('--build tsconfig.json --emitDeclarationOnly')) {
  throw new Error(`Unexpected built-in leaf command: ${t.command}`);
}
NODE

  echo '=== built-in leaf run and outputs ==='
  rm -rf packages/lib/dist apps/leaf/dist .nx/typecheck
  npx nx run leaf:typecheck --skip-nx-cache --verbose
  find packages/lib/dist apps/leaf/dist -type f | sort
  test -f apps/leaf/dist/main.d.ts
  test -f apps/leaf/dist/leaf.tsbuildinfo

  echo '=== project mode root clean/warm ==='
  rm -rf packages/lib/dist .nx/typecheck
  npx nx run root:typecheck-project --skip-nx-cache --verbose
  npx nx run root:typecheck-project --skip-nx-cache --verbose

  echo '=== build mode root clean/warm ==='
  rm -rf packages/lib/dist .nx/typecheck
  npx nx run root:typecheck-build --skip-nx-cache --verbose
  npx nx run root:typecheck-build --skip-nx-cache --verbose
  test -f .nx/typecheck/tsconfig.root.tsbuildinfo
  test ! -f root-visible.d.ts

  echo '=== project mode next clean/warm ==='
  rm -rf packages/lib/dist .nx/typecheck
  npx nx run next-app:typecheck-project --skip-nx-cache --verbose
  npx nx run next-app:typecheck-project --skip-nx-cache --verbose

  echo '=== build mode next clean/warm ==='
  rm -rf packages/lib/dist .nx/typecheck
  npx nx run next-app:typecheck-build --skip-nx-cache --verbose
  npx nx run next-app:typecheck-build --skip-nx-cache --verbose
  test -f .nx/typecheck/next-app.tsbuildinfo
  test ! -f apps/next-app/src/page.d.ts

  echo '=== incompatible Nx-style flag control ==='
  set +e
  npx tsc --build apps/next-app/tsconfig.json --emitDeclarationOnly --pretty false > .github-output/incompatible-control.log 2>&1
  ec=$?
  set -e
  cat .github-output/incompatible-control.log
  test "$ec" -ne 0

  echo '=== ignored-file negative control ==='
  cp tsconfig.root.json .github-output/tsconfig.root.negative.json
  node - <<'NODE'
const fs = require('fs');
const path = '.github-output/tsconfig.root.negative.json';
const c = JSON.parse(fs.readFileSync(path, 'utf8'));
c.extends = '../tsconfig.base.json';
c.files = ['../ignored-root-error.ts', '../ignored-folder/ignored-folder-error.ts'];
c.references = [];
c.compilerOptions.rootDir = '..';
c.compilerOptions.tsBuildInfoFile = '../.nx/typecheck/negative.tsbuildinfo';
fs.writeFileSync(path, JSON.stringify(c, null, 2));
NODE
  set +e
  npx tsc --project .github-output/tsconfig.root.negative.json --pretty false > .github-output/ignored-negative.log 2>&1
  ec=$?
  set -e
  cat .github-output/ignored-negative.log
  test "$ec" -ne 0

  echo '=== final sync idempotence ==='
  npx nx sync:check
} 2>&1 | tee .github-output/full.log

cp tsconfig.root.json .github-output/tsconfig.root.json
cp tsconfig.json .github-output/tsconfig.solution.json

tar -czf ../nx-verification-results.tgz .github-output
