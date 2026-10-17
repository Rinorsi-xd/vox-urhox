'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
function once(source,before,after){assert.equal(source.split(before).length-1,1,'Unique source anchor: '+before);return source.replace(before,()=>after)}
function instrumentGait(source){
 source="local Probe=assert(rawget(_G,'VOX_DRIVE_SCOPE'))\n"+source;
 for(const [before,after]of [
  ['function M.Step(c,dt,ctx)\n',"function M.Step(c,dt,ctx)\n    Probe.Enter('gait.Step');Probe.Enter('gait.init')\n"],
  ['    if not ctx.supported then\n',"    if not ctx.supported then\n        Probe.Switch('gait.air')\n"],
  ['c.parked=true;Finish(c,q,p);return',"c.parked=true;Probe.Switch('gait.finish');Finish(c,q,p);Probe.Leave();Probe.Leave();return"],
  ['    local vmax=0\n',"    Probe.Switch('gait.kinematics')\n    local vmax=0\n"],
  ['    local sn=Ramp(1.5,8,vmax)',"    Probe.Switch('gait.phase')\n    local sn=Ramp(1.5,8,vmax)"],
  ["        if s.mode=='stance' then\n","        if s.mode=='stance' then\n            Probe.Switch('gait.stance')\n"],
  ["        if s.mode=='swing' then\n","        if s.mode=='swing' then\n            Probe.Switch('gait.swing')\n"],
  ["        if s.mode=='free' then\n","        if s.mode=='free' then\n            Probe.Switch('gait.free')\n"],
  ["        if s.mode=='plant' then\n","        if s.mode=='plant' then\n            Probe.Switch('gait.plant')\n"],
  ['    Finish(c,q,p)\nend',"    Probe.Switch('gait.finish');Finish(c,q,p);Probe.Leave();Probe.Leave()\nend"],
 ])source=once(source,before,after);
 return source;
}
function instrumentContact(source){
 source="local Probe=assert(rawget(_G,'VOX_DRIVE_SCOPE'))\n"+source;
 for(const [before,after]of [
  ['function M.Step(vehicle,cmd,dt,frame)\n',"function M.Step(vehicle,cmd,dt,frame)\n    Probe.Enter('contact.Step');Probe.Enter('contact.inputs')\n"],
  ['    local nW=math.max',"    Probe.Switch('contact.loads')\n    local nW=math.max"],
  ['    vehicle.drifting=hand',"    Probe.Switch('contact.steering')\n    vehicle.drifting=hand"],
  ['    local hi=1-.25',"    Probe.Switch('contact.wheelCommands')\n    local hi=1-.25"],
  ['    local av=body.angvel()',"    Probe.Switch('contact.handling')\n    local av=body.angvel()"],
  ['    if contact>0 then\n',"    Probe.Switch('contact.damping')\n    if contact>0 then\n"],
  ['    for _,w in ipairs(vehicle.wheels) do\n        local length=',"    Probe.Switch('contact.bottomout')\n    for _,w in ipairs(vehicle.wheels) do\n        local length="],
  ['    local support,groundDrive,groundBrake=',"    Probe.Switch('contact.telemetry')\n    local support,groundDrive,groundBrake="],
  ['    return {contact=contact','    local result={contact=contact'],
  ['steeringAssist=steeringAssist}\nend','steeringAssist=steeringAssist}\n    Probe.Leave();Probe.Leave();return result\nend'],
 ])source=once(source,before,after);
 return source;
}
function buildDriveSectionsProbe(prepared,options={}){
 assert.ok(!options.afterStep||options.trialSections,'AfterStep sections extend explicit trial sections');
 const modules={};
 for(const [name,transform]of [['LegGait',instrumentGait],['ContactControl',instrumentContact]]){
  const relative='drive/'+name+'.lua',bytes=fs.readFileSync(path.join(prepared.source_directory,'scripts',relative));
  assert.equal(sha(bytes),prepared.identity.scripts[relative],'Frozen module identity '+name);
  modules[name]={source:transform(bytes.toString('utf8').replace(/\r\n/g,'\n')),sha256:sha(bytes)};
 }
 const scope=fs.readFileSync(path.join(__dirname,'perf-drive-sections-scope.lua'),'utf8');
 let observer=fs.readFileSync(path.join(__dirname,'qa-drive-sections.lua'),'utf8');
 let sourceIdentity='local SOURCE_IDENTITY={LegGait="'+modules.LegGait.sha256+'",ContactControl="'+modules.ContactControl.sha256+'"}\n';
 if(options.trialSections){
  const bindings=require('./trial-section-bindings.cjs').forProfile(options.afterStep===true);
  const lua=value=>Array.isArray(value)?'{'+value.map(lua).join(',')+'}':typeof value==='string'?JSON.stringify(value):String(value);
  const hashes={LegGait:modules.LegGait.sha256,ContactControl:modules.ContactControl.sha256};
  for(const name of bindings.sourceModules){
   const relative=name.replaceAll('.','/')+'.lua',bytes=fs.readFileSync(path.join(prepared.source_directory,'scripts',relative));
   assert.equal(sha(bytes),prepared.identity.scripts[relative],'Frozen trial binding module '+name);hashes[name]=sha(bytes);
  }
  sourceIdentity='local SOURCE_IDENTITY={'+Object.entries(hashes).map(([key,value])=>'['+lua(key)+']='+lua(value)).join(',')+'}\n';
  const extension='local TRIAL_METHODS='+lua(bindings.methods)+'\nlocal TRIAL_MODULE_BINDINGS='+bindings.moduleBindings+
   '\nlocal TRIAL_INSTANCE_LABELS='+lua(bindings.instanceLabels)+'\nlocal TRIAL_EXPECTED_BINDINGS='+bindings.expectedBindings+'\n'+
   fs.readFileSync(path.join(__dirname,'qa-trial-section-methods.lua'),'utf8')+'\n';
  observer=once(observer,'local function Install()\n',extension+'local function Install()\n');
  observer=once(observer,'    M.installed=true\n','    InstallTrialMethods()\n    M.installed=true\n');
  observer=once(observer,'    Scope.AssertClosed();Scope.rows={};Scope.active=true;M.frame=M.frame+1;M.started=clock()\n',
   '    BindTrialInstances(app)\n    Scope.AssertClosed();Scope.rows={};Scope.active=true;M.frame=M.frame+1;M.started=clock()\n');
  observer=once(observer,'    return {available=true,enabled=M.enabled,installed=M.installed,epoch=M.epoch,frames=M.frame,\n',
   '    return {available=true,trialSectionsProfile=true,profile="'+bindings.profile+'",expectedBindings=TRIAL_EXPECTED_BINDINGS,instanceLabels=instanceLabels,enabled=M.enabled,installed=M.installed,epoch=M.epoch,frames=M.frame,\n');
 }
 return 'do\nlocal Scope=(function()\n'+scope+'\nend)()\n_G.VOX_DRIVE_SCOPE=Scope\n'+
  "local Gait=(function()\n"+modules.LegGait.source+'\nend)()\n'+
  "local Contact=(function()\n"+modules.ContactControl.source+'\nend)()\n'+
  sourceIdentity+observer+'\nend\n';
}
module.exports={instrumentGait,instrumentContact,buildDriveSectionsProbe};
