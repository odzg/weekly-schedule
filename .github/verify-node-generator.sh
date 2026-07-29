#!/usr/bin/env bash
set -euo pipefail

rm -rf nx-node-generator-verification
mkdir nx-node-generator-verification
cd nx-node-generator-verification

cat > package.json <<'JSON'
{
  "name": "nx-node-generator-verification",
  "version": "0.0.0",
  "private": true,
  "workspaces": ["apps/*"],
  "devDependencies": {
    "@nx/js": "23.1.0",
    "@nx/node": "23.1.0",
    "nx": "23.1.0",
    "typescript": "6.0.3"
  }
}
JSON

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
    }
  ],
  "sync": { "applyChanges": true }
}
JSON

cat > tsconfig.base.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "strict": true,
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "skipLibCheck": true
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "files": [],
  "references": []
}
JSON

npm install --ignore-scripts

export NX_DAEMON=false
export NX_TUI=false

mkdir -p .github-output
{
  echo '=== versions ==='
  npx nx --version
  npx tsc --version

  echo '=== official @nx/node application generation ==='
  npx nx generate @nx/node:application apps/generated-node-app \
    --bundler=esbuild \
    --linter=none \
    --unitTestRunner=none \
    --e2eTestRunner=none \
    --useProjectJson=true \
    --skipFormat=true \
    --no-interactive

  echo '=== install generator-added dependencies ==='
  npm install --ignore-scripts

  echo '=== generated app files ==='
  find apps/generated-node-app -type f | sort

  echo '=== generated TypeScript configs (verbatim) ==='
  while IFS= read -r file; do
    echo "--- $file ---"
    cat "$file"
  done < <(find apps/generated-node-app -name 'tsconfig*.json' -type f | sort)

  echo '=== generated project configuration (verbatim) ==='
  if test -f apps/generated-node-app/project.json; then
    cat apps/generated-node-app/project.json
  fi
  if test -f apps/generated-node-app/package.json; then
    cat apps/generated-node-app/package.json
  fi

  echo '=== actual nx sync ==='
  npx nx sync
  npx nx sync:check

  echo '=== inferred project JSON ==='
  npx nx show project generated-node-app --json | tee .github-output/generated-node-app-project.json

  echo '=== assert exact inferred typecheck policy ==='
  node - <<'NODE'
const fs = require('fs');
const project = JSON.parse(fs.readFileSync('.github-output/generated-node-app-project.json', 'utf8'));
const target = project.targets?.typecheck;
if (!target) throw new Error('Officially generated Node app has no inferred typecheck target');
const command = target.options?.command ?? target.command;
console.log(`INFERRED_TYPECHECK_COMMAND=${command}`);
console.log(`INFERRED_TYPECHECK_DEPENDS_ON=${JSON.stringify(target.dependsOn)}`);
console.log(`INFERRED_TYPECHECK_OUTPUTS=${JSON.stringify(target.outputs)}`);
if (command !== 'tsc --build tsconfig.json --emitDeclarationOnly') {
  throw new Error(`Unexpected inferred command: ${command}`);
}
NODE

  echo '=== effective compiler configuration for app config ==='
  npx tsc --project apps/generated-node-app/tsconfig.app.json --showConfig | tee .github-output/generated-node-app-tsconfig-app-show-config.json

  echo '=== inferred typecheck run through actual Nx ==='
  rm -rf dist .nx apps/generated-node-app/dist
  npx nx run generated-node-app:typecheck --skip-nx-cache --verbose | tee .github-output/generated-node-app-typecheck.log

  echo '=== emitted TypeScript outputs ==='
  find apps/generated-node-app dist .nx \
    -type f \( -name '*.d.ts' -o -name '*.d.ts.map' -o -name '*.js' -o -name '*.js.map' -o -name '*.tsbuildinfo' \) \
    2>/dev/null | sort | tee .github-output/generated-node-app-emitted-outputs.txt

  echo '=== verify declaration-only result ==='
  test -s .github-output/generated-node-app-emitted-outputs.txt
  grep -q '\.d\.ts$' .github-output/generated-node-app-emitted-outputs.txt
  ! grep -E '/main\.js$' .github-output/generated-node-app-emitted-outputs.txt

  echo '=== terminal-project evidence ==='
  npx nx graph --file=.github-output/project-graph.json
  node - <<'NODE'
const fs = require('fs');
const raw = JSON.parse(fs.readFileSync('.github-output/project-graph.json', 'utf8'));
const graph = raw.graph ?? raw;
const reverse = [];
for (const [source, deps] of Object.entries(graph.dependencies ?? {})) {
  for (const dep of deps) {
    if (dep.target === 'generated-node-app') reverse.push(source);
  }
}
console.log(`GENERATED_NODE_APP_REVERSE_DEPENDENTS=${JSON.stringify(reverse)}`);
if (reverse.length) throw new Error(`Generated app is not terminal: ${reverse.join(', ')}`);
NODE

  echo '=== final sync check ==='
  npx nx sync:check
} 2>&1 | tee .github-output/full.log
