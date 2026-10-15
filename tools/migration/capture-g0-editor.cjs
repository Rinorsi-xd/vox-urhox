// Read-only editor status. Never exports credentials, user IDs or profile IDs.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const python=process.env.VOX_MAKER_PYTHON||'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
const raw=cp.execFileSync(python,['tools/editor_mcp.py','status'],{cwd:root,encoding:'utf8',windowsHide:true,env:{...process.env,PYTHONIOENCODING:'utf-8'}});
const status=JSON.parse(raw),state=status.editor_state?.data;
if(!status.ok||!state)throw Error('Editor status unavailable');
const accounts=state.debug_accounts;
const report={capturedAt:new Date().toISOString(),sourceCommit:prepared.identity.sourceCommit,
 manifest:path.basename(prepared.manifest_path),workspaceScriptFingerprint:prepared.identity.scriptFingerprint,
 project:state.project_path,scene:state.scene_path,editMode:state.edit_mode,playMode:state.play_mode,
 runtimeDebugRunning:state.runtime_debug_running,dirty:state.dirty,
 savedAccountPresent:!!accounts?.accounts?.some(a=>a.credential_state==='saved'),
 savedAccountSelected:!!accounts?.selected_profile_id,
 acceptance:{editorInteraction:'NOT_RUN',editorRuntimeIdentity:'NOT_VERIFIED',realAccountWebRefresh:'NOT_RUN'},
 limitation:'A saved native debug account does not prove Web cloud authentication or persistence. Status is not runtime, visual or interaction acceptance.'};
if(state.project_path.replaceAll('\\','/').replace(/\/$/,'').toLowerCase()!==root.replaceAll('\\','/').toLowerCase())throw Error('Wrong editor project');
const out=path.join(root,'docs/migration/evidence/full-parity',prepared.identity.sourceCommit.slice(0,12),'G0',path.basename(prepared.manifest_path,'.json'));
fs.mkdirSync(out,{recursive:true});
const capturePath=path.join(out,'editor-status-'+report.capturedAt.replace(/[:.]/g,'-')+'.json');
fs.writeFileSync(capturePath,JSON.stringify(report,null,2),{flag:'wx'});
console.log(JSON.stringify(report));
