const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

test('global executable resolves chained relative symlinks from an unrelated directory and preserves old entries', {skip: process.platform === 'win32'}, (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'opendash-installer-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const source = path.join(root, 'source with spaces');
  const dist = path.join(root, 'gui', 'dist');
  const bin = path.join(root, 'bin');
  const cwd = path.join(root, 'unrelated');
  for (const dir of [source, dist, bin, cwd, path.join(dist, 'opendash')]) fs.mkdirSync(dir, {recursive: true});
  const installer = path.resolve(__dirname, '..', 'install-opendash.sh');
  // Preserve the checkout's mode: this catches non-executable releases.
  fs.copyFileSync(installer, path.join(source, 'install-opendash.sh'));
  fs.chmodSync(path.join(source, 'install-opendash.sh'), fs.statSync(installer).mode & 0o777);
  const html = fs.readFileSync(path.resolve(__dirname, '..', 'opendash.html'));
  fs.writeFileSync(path.join(source, 'opendash.html'), html);
  fs.writeFileSync(path.join(dist, 'index.html'), 'original GUI');
  fs.writeFileSync(path.join(dist, 'opendash.html'), 'old root');
  fs.writeFileSync(path.join(dist, 'opendash', 'index.html'), 'old nested');
  fs.symlinkSync('../source with spaces/install-opendash.sh', path.join(bin, 'inner'));
  fs.symlinkSync('inner', path.join(bin, 'install-opendash'));
  const result = spawnSync(path.join(bin, 'install-opendash'), [dist], {
    cwd, env: {...process.env, SKIP_VERIFY: '1', NO_AUTO_OPEN: '1'}, encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  assert.deepEqual(fs.readFileSync(path.join(dist, 'opendash.html')), html);
  assert.deepEqual(fs.readFileSync(path.join(dist, 'opendash', 'index.html')), html);
  assert.equal(fs.readFileSync(path.join(dist, 'index.html'), 'utf8'), 'original GUI');
  const backups = path.join(source, 'deployment-backups');
  const backup = path.join(backups, fs.readdirSync(backups)[0]);
  assert.equal(fs.readFileSync(path.join(backup, 'opendash.html'), 'utf8'), 'old root');
  assert.equal(fs.readFileSync(path.join(backup, 'index.html'), 'utf8'), 'old nested');
});
