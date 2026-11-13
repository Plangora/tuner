import { createPrivateKey, sign } from 'node:crypto';

async function main() {
  for (const name of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_CONTENT']) {
    if (!process.env[name]) throw new Error(`Missing CI credential: ${name}`);
  }
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const data = [
    encode({ alg: 'ES256', kid: process.env.ASC_KEY_ID, typ: 'JWT' }),
    encode({ iss: process.env.ASC_ISSUER_ID, iat: now, exp: now + 300, aud: 'appstoreconnect-v1' }),
  ].join('.');
  const key = createPrivateKey(Buffer.from(process.env.ASC_KEY_CONTENT, 'base64'));
  const signature = sign('sha256', Buffer.from(data), { key, dsaEncoding: 'ieee-p1363' });
  const token = `${data}.${signature.toString('base64url')}`;

  async function get(path, params) {
    const url = new URL(`https://api.appstoreconnect.apple.com/v1/${path}`);
    for (const [name, value] of Object.entries(params)) url.searchParams.set(name, value);
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(30000),
    });
    const body = await response.json();
    if (!response.ok) {
      if (body.errors?.some(error => error.code === 'FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED')) {
        throw new Error('Apple requires the account holder to accept a pending or expired agreement at https://appstoreconnect.apple.com/business. Accept it, then retry the iOS job; do not rotate signing keys or change the bundle ID.');
      }
      const errors = body.errors?.map(error => `${error.code}: ${error.detail ?? error.title}`).join('; ');
      throw new Error(`Apple API HTTP ${response.status}: ${errors ?? 'Unexpected response'}`);
    }
    return body;
  }

  const apps = await get('apps', { 'filter[bundleId]': 'com.plangora.tuner' });
  if (apps.data.length !== 1) throw new Error('API key cannot see exactly one Tuner app. Check its app access and team.');
  const app = apps.data[0];
  console.log('Visible app:', JSON.stringify({ id: app.id, name: app.attributes.name, bundleId: app.attributes.bundleId }));
  if (process.env.ASC_BUILD_NUMBER) {
    const builds = await get('builds', {
      'filter[app]': app.id,
      'filter[version]': process.env.ASC_BUILD_NUMBER,
      include: 'preReleaseVersion',
    });
    console.log('Existing builds:', JSON.stringify(builds.data.map(build => ({
      id: build.id,
      version: build.attributes.version,
      processingState: build.attributes.processingState,
      preReleaseVersion: build.relationships.preReleaseVersion.data,
    }))));
    console.log('Marketing versions:', JSON.stringify(builds.included?.map(version => ({ id: version.id, version: version.attributes.version })) ?? []));
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
