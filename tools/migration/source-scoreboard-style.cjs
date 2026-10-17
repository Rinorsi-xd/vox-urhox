const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json');
const inputs={};
function read(name){const bytes=fs.readFileSync(path.resolve(root,baseline.snapshot,name));const sha=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(sha,baseline.files[name].sha256);inputs[name]=sha;return bytes.toString('utf8');}
const source=read('shared/ui/matchHud.js'),utility=read('shared/css/new-ui-utility.css'),responsive=read('shared/css/new-ui-responsive.css');
const code=source.replace(/^import .*;\r?\n/gm,'').replace(/export class /g,'class ');
const MatchHud=vm.runInNewContext(`(()=>{${code};return MatchHud;})()`,{escapeHtml:s=>String(s),avatarUrl:()=>'',setTimeout:()=>{}});
const css=source.match(/const CSS = `([\s\S]*?)`;/)[1];
const rule=css.match(/#match-hud \.mh-row \.dmg\{([^}]+)\}/)[1];
const color=rule.match(/(?:^|;)color:(#[\da-f]{8})(?:;|$)/)[1];
const damageColor=color.slice(1).match(/../g).map(x=>parseInt(x,16));
const damageSize=Number(rule.match(/(?:^|;)font-size:(\d+)px(?:;|$)/)[1]);
assert(!utility.includes('.dmg')&&!responsive.includes('.dmg'),'No later damage-specific override in frozen utility/responsive CSS');
const grid=css.match(/#match-hud \.mh-row\{[^}]*grid-template-columns:([^;]+);/)[1];
const gridWidths=grid.match(/\d+px/g).map(x=>parseInt(x,10));
const hud=Object.create(MatchHud.prototype);
const row={member:{role:'heavy',level:7},name:'layout probe',rating:1200,kills:2,assists:3,deaths:4,damage:123456};
const html=hud._rows([row],null);
assert.match(html,/<span class="dmg">123,456<\/span>/);
process.stdout.write(JSON.stringify({baseline:baseline.commit,inputs,damageColor,damageSize,grid,gridWidths,sourceRow:html,
 boundary:'Executes frozen JS _rows and reads its exact damage rule; checks the two later frozen stylesheets for damage-specific overrides. Does not run a DOM cascade, font rasterization, engine, GPU, game or performance test.'}));
