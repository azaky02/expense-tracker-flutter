/**
 * Builds the single-folder package for Windows/IIS hosting (SmarterASP.NET), same layout as ServiceOS:
 *   publish/server.mjs    – the API bundled into one file (no node_modules to upload)
 *   publish/migrations/   – SQL migrations (applied automatically at start: AUTO_MIGRATE=on)
 *   publish/web.config    – IIS httpPlatformHandler → node server.mjs
 *   publish/.env          – settings to fill in (database, registration). The JWT secret is generated here.
 *   publish/README-DEPLOY.txt
 * Usage: node tools/publish.mjs [outDir]      (default: ../../ExpenseTracker-SmarterASP/server)
 * An existing .env in outDir is kept, so re-publishing never overwrites your database settings or secret.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.resolve(process.argv[2] ?? path.join(root, '..', '..', 'ExpenseTracker-SmarterASP', 'server'));
const keepEnv = fs.existsSync(path.join(out, '.env')) ? fs.readFileSync(path.join(out, '.env'), 'utf8') : null;

for (const entry of fs.existsSync(out) ? fs.readdirSync(out) : []) {
  if (entry === '.env' || entry === 'data' || entry === 'public') continue; // keep settings and runtime data
  fs.rmSync(path.join(out, entry), { recursive: true, force: true });
}
fs.mkdirSync(path.join(out, 'data', 'logs'), { recursive: true });
fs.writeFileSync(path.join(out, 'data', 'logs', '.keep'), '');

console.log('1/3 bundling the API…');
await build({
  entryPoints: [path.join(root, 'src/server.ts')],
  outfile: path.join(out, 'server.mjs'),
  bundle: true, platform: 'node', format: 'esm', target: 'node18', minify: false, sourcemap: false, legalComments: 'none',
  external: ['pg-native'],
  // CommonJS dependencies inside an ES module bundle need require / __dirname.
  banner: { js: "import { createRequire as __cr } from 'node:module'; import { fileURLToPath as __fu } from 'node:url'; import { dirname as __dn } from 'node:path'; const require = __cr(import.meta.url); const __filename = __fu(import.meta.url); const __dirname = __dn(__filename);" },
  logLevel: 'warning',
});

console.log('2/3 copying migrations…');
fs.cpSync(path.join(root, 'migrations'), path.join(out, 'migrations'), { recursive: true });

console.log('3/3 writing web.config and .env…');
fs.writeFileSync(path.join(out, 'web.config'), `<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="httpPlatformHandler" path="*" verb="*" modules="httpPlatformHandler" resourceType="Unspecified" />
    </handlers>
    <httpPlatform processPath="C:\\Program Files\\nodejs\\node.exe" arguments=".\\server.mjs" startupTimeLimit="300" startupRetryCount="3" requestTimeout="00:04:00" stdoutLogEnabled="true" stdoutLogFile=".\\data\\logs\\node">
      <environmentVariables>
        <environmentVariable name="PORT" value="%HTTP_PLATFORM_PORT%" />
        <environmentVariable name="NODE_ENV" value="production" />
      </environmentVariables>
    </httpPlatform>
    <security>
      <requestFiltering>
        <requestLimits maxAllowedContentLength="15728640" />
      </requestFiltering>
    </security>
    <httpErrors existingResponse="PassThrough" />
  </system.webServer>
</configuration>
`);

fs.mkdirSync(path.join(out, 'public'), { recursive: true }); // put index.html + the APKs here
const secret = crypto.randomBytes(48).toString('base64url');
fs.writeFileSync(path.join(out, '.env'), keepEnv ?? `# Masarefy server – production settings. Fill in the lines marked <<…>>, then upload the folder.
# Never share this file. All HTTP requests go to the Node process, which does not serve files from disk.

# ── Database (SmarterASP control panel → Databases → PostgreSQL) ──
# postgres://USER:PASSWORD@HOST:5432/DATABASE     (URL-encode special characters in the password)
DATABASE_URL=<<postgres://user:password@host:5432/database>>
DB_SCHEMA=masarefy
AUTO_MIGRATE=on

# ── Security (generated for this package – keep it; changing it signs every device out) ──
JWT_ACCESS_SECRET=${secret}

# ── Who can create an account ──
#   open   = anyone with the server address
#   code   = only people who know SIGNUP_CODE (enter it in the app's register screen)
#   closed = nobody new
REGISTRATION=code
SIGNUP_CODE=<<choose-a-signup-code>>

# Only needed for a browser-based client (the mobile app does not use CORS).
CORS_ORIGIN=
`);

fs.writeFileSync(path.join(out, 'README-DEPLOY.txt'), `مصاريفي – رفع السيرفر على SmarterASP.NET
=========================================

1) قاعدة البيانات
   لوحة التحكم ← Databases ← PostgreSQL ← Add Database. احتفظ بـ Host / Database / Username / Password.

2) ملف .env (افتحه بـ Notepad) واملا السطور اللي فيها <<…>>:
   DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DATABASE
   SIGNUP_CODE=كود تسجيل تختاره (REGISTRATION=code معناها محدش يسجّل غير اللي يعرف الكود)
   ما تغيّرش JWT_ACCESS_SECRET بعد أول تشغيل.

3) الرفع
   ارفع محتويات الفولدر ده كله (مش الفولدر نفسه) على جذر الموقع. لازم web.config و server.mjs في الجذر.
   لو بتحدّث نسخة موجودة: ارفع server.mjs و migrations و web.config بس، وما تمسحش .env ولا data.

4) Node.js
   تأكد إن Node.js 18+ متاح للموقع (httpPlatformHandler) من لوحة SmarterASP، وعمل Restart للموقع بعد الرفع.

5) تأكد إنه شغال
   افتح  https://موقعك/api/health   لازم يرجّع  {"ok":true,"db":true,...}
   أول تشغيل بياخد لحد دقيقة: السيرفر بينشئ الجداول لوحده (AUTO_MIGRATE).
   لو ok=false: افتح data\\logs\\ وابعتلي آخر سطور من ملف node.

6) في التطبيق
   الإعدادات ← الحساب والمزامنة ← اكتب عنوان السيرفر (https://موقعك) ← إنشاء حساب بالكود.

أمان: استخدم https. لو الموقع على رابط http بس (ctempurl) اتصال التطبيق هيكون غير مشفّر – مناسب للتجربة فقط.
`);
console.log(`done → ${out}`);
