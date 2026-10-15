// Bake only the reviewed new car images using the frozen source renderers.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {chromium} = require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve(__dirname, '../..');
const commit = 'b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/baselines', commit + '.json')));
const source = path.resolve(baseline.snapshot);
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const ids = ['mtBack','mtHead','mtWingL','mtWingR','mtTail1','mtTail2','mtTail3',
  'rtBack','rtHead','rtFlankL','rtFlankR','rtTail1','rtTail2','rtTail3',
  'roHead','roTail','roElytraL','roElytraR','roSideL','roSideR'];
const cars = ['fox', 'manta', 'rat', 'roach'];
const apply = process.argv.includes('--apply');
const evidence = path.join(root, 'docs/migration/evidence/car-images-' + new Date().toISOString().replace(/[:.]/g, '-'));
fs.mkdirSync(evidence, {recursive: true});
const inputs = {};
const images = [];
const report = {sourceCommit: commit, source, apply, sourceFiles: inputs, images, writes: [], errors: []};
function sourceBytes(relative) {
  const file = path.resolve(source, relative);
  assert(file.startsWith(source + path.sep));
  const bytes = fs.readFileSync(file);
  assert.equal(sha(bytes), baseline.files[relative]?.sha256, 'Frozen source input ' + relative);
  inputs[relative] = sha(bytes);
  return bytes;
}
let html = fs.readFileSync(path.join(__dirname, 'source-thumbnails.html'), 'utf8');
html = html.replace('const thumbs=renderThumbnails(),images={};', 'const thumbs=await renderThumbnails(112,' + JSON.stringify(ids) + '),images={};');
html = html.replace('for(const def of PART_LIST) {', 'for(const def of PART_LIST.filter(def=>' + JSON.stringify(ids) + '.includes(def.id))) {');
html = html.replace("const result=await response.json();", "const result=await response.json();window.exportDone=true;");
html = html.replace("console.error(error);button.disabled=false;", "console.error(error);window.exportError=error.message;button.disabled=false;");
html = html.replace('auto-fill,140px', '5,140px');
const token = crypto.randomBytes(24).toString('hex');
html = html.replace('__EXPORT_TOKEN__', token);
const mime = {'.js':'text/javascript','.json':'application/json','.glb':'model/gltf-binary','.png':'image/png','.jpg':'image/jpeg','.hdr':'application/octet-stream'};
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://127.0.0.1');
    if (req.method === 'GET' && url.pathname === '/') return res.writeHead(200, {'Content-Type':'text/html; charset=utf-8'}).end(html);
    if (req.method === 'GET' && url.pathname.startsWith('/source/')) {
      const relative = decodeURIComponent(url.pathname.slice(8));
      const bytes = sourceBytes(relative);
      return res.writeHead(200, {'Content-Type': mime[path.extname(relative)] || 'application/octet-stream'}).end(bytes);
    }
    if (req.method === 'POST' && url.pathname === '/export' && req.headers['x-export-token'] === token) {
      const chunks = []; let size = 0;
      for await (const chunk of req) {size += chunk.length; assert(size < 2 * 1024 * 1024); chunks.push(chunk);}
      const body = JSON.parse(Buffer.concat(chunks));
      assert.equal(body.size, 112); assert.deepEqual(Object.keys(body.images).sort(), [...ids].sort());
      for (const id of ids) {
        const uri = body.images[id]; assert(uri.startsWith('data:image/png;base64,'));
        const bytes = Buffer.from(uri.slice('data:image/png;base64,'.length), 'base64');
        assert.equal(bytes.readUInt32BE(16), 112); assert.equal(bytes.readUInt32BE(20), 112);
        fs.writeFileSync(path.join(evidence, id + '.png'), bytes);
        images.push({file:'assets/UI/Parts/' + id + '.png', baked:id + '.png', sha256:sha(bytes), bytes:bytes.length});
      }
      return res.writeHead(200, {'Content-Type':'application/json'}).end(JSON.stringify({count:ids.length, bytes:size}));
    }
    res.writeHead(404).end();
  } catch (error) {report.errors.push(error.message); res.writeHead(400).end(error.message);}
});
async function main() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({headless:true, channel:'chrome'});
  report.browser = browser.version();
  try {
    const page = await browser.newPage({viewport:{width:900, height:1000}});
    page.on('pageerror', error => report.errors.push(error.message));
    await page.goto('http://127.0.0.1:' + server.address().port + '/');
    await page.click('#export');
    await page.waitForFunction(() => window.exportDone || window.exportError, undefined, {timeout:180000});
    assert.equal(await page.evaluate(() => window.exportError), undefined, 'Source renderer succeeded');
    report.alphaChecks = await page.evaluate(async () => {
      const checks = [];
      for (const image of document.querySelectorAll('#tiles img')) {
        await image.decode();
        const canvas = document.createElement('canvas'); canvas.width = canvas.height = 112;
        const ctx = canvas.getContext('2d'); ctx.drawImage(image, 0, 0);
        const pixels = ctx.getImageData(0, 0, 112, 112).data;
        let transparent = 0; for (let p = 3; p < pixels.length; p += 4) if (!pixels[p]) transparent++;
        checks.push({id:image.alt, transparent, visible:112*112-transparent,
          corners:[3,111*4+3,111*112*4+3,(112*112-1)*4+3].map(p => pixels[p])});
      }
      return checks;
    });
    assert.equal(report.alphaChecks.length, 20);
    for (const check of report.alphaChecks) {
      assert(check.transparent > 112*112*.25, 'Transparent surround ' + check.id);
      assert(check.visible > 20, 'Visible thumbnail ' + check.id);
      assert(check.corners.every(alpha => alpha === 0), 'Transparent corners ' + check.id);
    }
    await page.locator('#tiles').screenshot({path:path.join(evidence, 'thumbnails-contact.png')});
    const css = sourceBytes('shared/css/workshop.css').toString('utf8');
    report.filters = {};
    for (const [name, selector] of Object.entries({card:'.wsb-card img',hover:'.wsb-card:hover img',dot:'.wsh-dots img'})) {
      const rule = css.split('\n').find(line => line.includes(selector + ' {') && line.includes('filter:'));
      const filter = rule?.match(/(?:^|[;{])\s*filter:\s*([^;]+)/)?.[1]?.trim();
      assert(filter, 'Source CSS filter ' + selector); report.filters[name] = filter;
      for (const id of cars) {
        const relative = 'shared/assets/ui/prefabs/' + id + '.jpg'; sourceBytes(relative);
        const uri = await page.evaluate(async ({url, filter, thumbnail}) => {
          const image = new Image(); image.src = url; await image.decode();
          const canvas = document.createElement('canvas'); canvas.width = thumbnail ? 264 : image.width;
          canvas.height = Math.round(image.height * canvas.width / image.width);
          const ctx = canvas.getContext('2d'); ctx.filter = filter; ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
          return canvas.toDataURL('image/jpeg', .98).split(',')[1];
        }, {url:'/source/' + relative, filter, thumbnail:name === 'dot'});
        const bytes = Buffer.from(uri, 'base64'); const filename = name + '-' + id + '.jpg';
        fs.writeFileSync(path.join(evidence, filename), bytes);
        images.push({file:'assets/UI/Prefabs/Filtered/' + filename, baked:filename, sha256:sha(bytes), bytes:bytes.length});
      }
    }
    assert.equal(images.length, 32); assert.equal(report.errors.length, 0, 'Asset browser errors');
  } finally {await browser.close(); await new Promise(resolve => server.close(resolve));}
  function write(relative, bytes) {
    const file = path.join(root, relative); const old = fs.existsSync(file) ? fs.readFileSync(file) : null;
    if (old?.equals(bytes)) return;
    report.writes.push({file:relative, beforeSha256:old ? sha(old) : null, sha256:sha(bytes), bytes:bytes.length});
    if (!apply) return;
    if (old) {const backup = path.join(evidence, 'before', relative); fs.mkdirSync(path.dirname(backup), {recursive:true}); fs.writeFileSync(backup, old);}
    fs.mkdirSync(path.dirname(file), {recursive:true}); fs.writeFileSync(file, bytes);
  }
  function meta(relative) {
    if (!fs.existsSync(path.join(root, relative + '.meta'))) write(relative + '.meta', Buffer.from(JSON.stringify({uuid:crypto.createHash('sha256').update('Vox:BaselineCarImage:' + relative).digest().subarray(0,18).toString('base64url')})));
  }
  for (const image of images) {
    if (!image.file.includes('Filtered/') || !image.file.endsWith('-fox.jpg')) assert(!fs.existsSync(path.join(root, image.file)), 'New image must be absent ' + image.file);
    write(image.file, fs.readFileSync(path.join(evidence, image.baked))); meta(image.file);
    const xml = image.file.replace(/\.(png|jpg)$/, '.xml');
    if (!fs.existsSync(path.join(root, xml))) write(xml, fs.readFileSync(path.join(root, image.file.includes('/Parts/') ? 'assets/UI/Parts/fxHead.xml' : 'assets/UI/Prefabs/Filtered/card-fox.xml')));
    meta(xml);
  }
  for (const image of images) if (apply) assert.equal(sha(fs.readFileSync(path.join(root, image.file))), image.sha256);
  report.converterSha256 = sha(fs.readFileSync(__filename)); report.finishedAt = new Date().toISOString();
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({evidence, applied:apply, images:images.length, writes:report.writes.length, sourceInputs:Object.keys(inputs).length}, null, 2));
}
main().catch(error => {report.failure = error.stack; fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2)); console.error(error); process.exitCode = 1; server.close();});
