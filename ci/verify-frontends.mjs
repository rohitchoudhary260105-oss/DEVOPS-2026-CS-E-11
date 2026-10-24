
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));

const checks = [
  {
    name: 'Public frontend typecheck',
    directory: 'frontend-demo/public-client',
    command: 'typecheck',
  },
  {
    name: 'Public frontend production build',
    directory: 'frontend-demo/public-client',
    command: 'build',
  },
  {
    name: 'Admin frontend typecheck',
    directory: 'frontend-demo/admin-client',
    command: 'typecheck',
  },
  {
    name: 'Admin frontend production build',
    directory: 'frontend-demo/admin-client',
    command: 'build',
  },
];

function runCheck(check) {
  const startedAt = Date.now();

  const isWindows = process.platform === 'win32';
  const executable = isWindows
    ? process.env.ComSpec || 'cmd.exe'
    : 'npm';

  const args = isWindows
    ? ['/d', '/s', '/c', `npm.cmd run ${check.command}`]
    : ['run', check.command];

  const result = spawnSync(executable, args, {
    cwd: resolve(root, check.directory),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });

  const output = [
    result.stdout,
    result.stderr,
    result.error?.message,
  ]
    .filter(Boolean)
    .join('\n')
    .trim();

  return {
    ...check,
    passed: result.status === 0 && !result.error,
    durationMs: Date.now() - startedAt,
    output,
  };
}

// Run all independent checks concurrently.
const results = await Promise.all(
  checks.map((check) =>
    Promise.resolve().then(() => runCheck(check))
  )
);

for (const result of results) {
  console.log(
    `${result.passed ? 'PASS' : 'FAIL'} | ${result.name} | ${result.durationMs}ms`
  );

  if (!result.passed && result.output) {
    console.error(result.output);
  }
}

const failed = results.filter((result) => !result.passed);

console.log(
  `\nSummary: ${results.length - failed.length}/${results.length} checks passed.`
);

if (failed.length > 0) {
  process.exitCode = 1;
}
