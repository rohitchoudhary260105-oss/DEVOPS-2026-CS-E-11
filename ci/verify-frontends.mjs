import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const checks = [
  { name: 'Public frontend typecheck', directory: 'frontend-demo/public-client', command: 'typecheck' },
  { name: 'Public frontend production build', directory: 'frontend-demo/public-client', command: 'build' },
  { name: 'Admin frontend typecheck', directory: 'frontend-demo/admin-client', command: 'typecheck' },
  { name: 'Admin frontend production build', directory: 'frontend-demo/admin-client', command: 'build' },
];

const results = checks.map((check) => {
  const startedAt = Date.now();
  const executable = process.platform === 'win32' ? (process.env.ComSpec || 'cmd.exe') : npmCommand;
  const args = process.platform === 'win32'
    ? ['/d', '/s', '/c', `${npmCommand} run ${check.command}`]
    : ['run', check.command];
  const result = spawnSync(executable, args, {
    cwd: resolve(root, check.directory),
    encoding: 'utf8',
  });
  const output = [result.stdout, result.stderr, result.error?.message]
    .filter(Boolean)
    .join('\n')
    .trim();

  return {
    ...check,
    passed: result.status === 0 && !result.error,
    durationMs: Date.now() - startedAt,
    output,
  };
});
