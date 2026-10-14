local Sync=require 'storage.CloudSync'
local M={sync=false,web=false,notice=false,confirmWanted=false,warned=false}
local namespaces={'vox-garage','vox-salvage'}
local keys={'draft','garage-state','build-settings','music','graphics','match-profile','story-progress','tutorial-v1','stash'}
for i=1,20 do keys[#keys+1]='slot'..i end
local function Remote(namespace,key) return 'vox-save-v1-'..namespace..'-'..key end
local function Identity()
    local ok,id=pcall(function() return GetUserId and GetUserId() or clientCloud.userId end)
    if ok and (type(id)=='number' and id>0 or type(id)=='string' and id:match('^[1-9]%d*$')) then return tostring(id) end
    return false
end
local function Decode(text,key)
    if #text>4*1024*1024 then return nil end
    local r=cjson.decode(text)
    if type(r)~='table' or r.v~=1 or type(r.generation)~='number' or r.generation<1 or r.generation%1~=0 then return nil end
    if r.deleted~=nil and r.deleted~=true then return nil end
    if not r.deleted and type(r.data)~='table' then return nil end
    if r.time~=nil and (type(r.time)~='number' or r.time<0 or r.time~=r.time) then return nil end
    if r.capture~=nil and type(r.capture)~='table' then return nil end
    if not r.deleted then
        local name=key:match('^vox%-save%-v1%-vox%-garage%-(.+)$') or key:match('^vox%-save%-v1%-vox%-salvage%-(.+)$')
        local data=r.data;local valid=false
        if name=='draft' or name and name:match('^slot%d+$') then valid=require('storage.BlueprintCode').Validate(data)
        elseif name=='garage-state' then valid=data.v==1 and (data.active==false or type(data.active)=='number' and data.active%1==0 and data.active>=1 and data.active<=20)
        elseif name=='build-settings' then valid=require('construction.Inventory').ValidSettings(data)
        elseif name=='music' then valid=require('audio.MusicPlayer').Valid(data)
        elseif name=='graphics' then valid=require('render.GraphicsSettings').ValidSaved(data)
        elseif name=='match-profile' then valid=require('combat.Matchmaker').Valid(data)
        elseif name=='tutorial-v1' then valid=require('story.TutorialRules').ValidRecord(data)
        elseif name=='stash' then valid=require('app.SalvageLobby').Valid(data)
        elseif name=='story-progress' then valid=true end
        if not valid then return nil end
    end
    return r
end
M.Decode=Decode
function M.Boot(done)
    M.web=require('urhox-libs.Platform.PlatformUtils').IsWebPlatform()
    local validation=rawget(_G,'VOX_CLOUD_VALIDATION')==true
    for _,arg in ipairs(GetArguments()) do if arg=='-validate' or arg:match('^%-screenshot=') then validation=true end end
    if not M.web or validation then done();return end
    local sdk=rawget(_G,'clientCloud');local user=sdk and Identity()
    if not user then M.notice='session';print('[CloudStorage] Session-only preview: no account identity');done();return end
    local list,allowed={},{}
    for _,namespace in ipairs(namespaces) do for _,key in ipairs(keys) do local name=Remote(namespace,key);list[#list+1]=name;allowed[name]=true end end
    local transport={}
    function transport:Read(names,events)
        local batch=sdk:BatchGet();for _,name in ipairs(names) do batch:Key(name) end;batch:Fetch(events)
    end
    function transport:Write(key,value,events) sdk:Set(key,value,events) end
    M.sync=Sync.New{transport=transport,identity=Identity,user=user,keys=list,allowed=allowed,decode=Decode}
    M.sync:Start(function(records,reason)
        if records then
            local Store=require 'storage.BlueprintStore'
            for _,namespace in ipairs(namespaces) do
                for _,key in ipairs(keys) do
                    local record=records[Remote(namespace,key)] or {v=1,generation=1,deleted=true}
                    local ok,restored=pcall(Store.Hydrate,namespace,key,record)
                    if not ok or not restored then M.sync:Block('local_restore_failed');M.notice='blocked';done();return end
                end
            end
            print('[CloudStorage] Restore complete; changed records will sync serially')
        else M.notice='blocked';print('[CloudStorage] Restore unavailable: '..tostring(reason)) end
        done()
    end)
end
function M.Snapshot()
    return {web=M.web,state=M.sync and M.sync.state or M.web and 'session' or 'local',
        reason=M.sync and M.sync.reason or '',pending=M.sync and M.sync:PendingCount() or 0}
end
function M.Queue(namespace,key,text)
    if not M.sync or namespace~='vox-garage' and namespace~='vox-salvage' then return end
    if not M.sync:Queue(Remote(namespace,key),text) and not M.warned then M.notice='blocked' end
end
function M.Invalid(namespace)
    if M.sync and (namespace=='vox-garage' or namespace=='vox-salvage') then M.sync:Block('invalid_data');if not M.warned then M.notice='blocked' end end
end
function M.Message(namespace,text)
    if not M.web or namespace~='vox-garage' and namespace~='vox-salvage' then return text end
    if not M.sync then return text..'（仅本次会话）' end
    if M.sync.state~='ready' then return text..'（本地备份，云同步暂停）' end
    if M.sync:PendingCount()>0 then M.confirmWanted=true;return text..'（等待云端确认）' end
    return text..'（云端已确认）'
end
function M.Update(dt,app)
    if M.sync then
        M.sync:Update(dt)
        if M.sync.notify=='saved' then
            M.warned=false
            if M.confirmWanted then M.notice='saved';M.confirmWanted=false end
        elseif M.sync.notify then M.notice=M.sync.notify end
        M.sync.notify=false
    end
    if app and app.toasts and M.notice then
        local notice=M.notice;M.notice=false
        if notice=='blocked' then M.warned=true end
        local text=notice=='saved' and '存档已同步到云端' or notice=='session' and '当前预览未连接账号，存档仅本次会话有效' or '云存档未确认，已保留本地备份；请暂勿刷新页面'
        app.toasts:Push(text,notice=='saved' and 'ok' or 'warn',notice=='saved' and 2200 or 8000)
    end
end
function M.Stop()
    require('storage.BlueprintStore').FlushAll()
    if M.sync then M.sync:Stop();M.sync=false end
    M.notice=false
    M.confirmWanted=false;M.warned=false
end
return M
