-- Explicit QA suffix: detached in-memory shortage; never grants or saves stock.
do
    local previous=HandleUpdate
    local held=nil
    local function Copy(value) return cjson.decode(cjson.encode(value)) end
    local function Stock(data)
        local items={};for id,n in pairs(data.items) do items[#items+1]={id,n} end
        table.sort(items,function(a,b) return a[1]<b[1] end)
        return {credits=data.credits,items=items}
    end
    local function Snapshot(app,phase)
        local lobby=app.salvageLobby
        local saved=lobby.store:Read('stash',require('app.SalvageLobby').Valid)
        local short=lobby:Shortfall();local deployment=lobby:DeploymentShortfall()
        local kinds,deployKinds,used=0,0,0
        for _ in pairs(short) do kinds=kinds+1 end
        for _ in pairs(deployment) do deployKinds=deployKinds+1 end
        for _,n in pairs(lobby:Usage()) do used=used+n end
        print('QA_SALVAGE_STOCK '..cjson.encode({phase=phase,debug=app.debugEnabled==true,arguments=GetArguments(),
            lobby=app.lobby,mode=app.mode,missingKinds=kinds,deploymentMissingKinds=deployKinds,
            used=used,stock=Stock(lobby.data),saved=saved and Stock(saved),
            saveCalls=held and held.saveCalls or 0,saveStockChanged=held and held.saveStockChanged or false,
            restored=phase=='restored'}))
    end
    function HandleUpdate(eventType,eventData)
        if previous then previous(eventType,eventData) end
        local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
        if not app or not app.salvageLobby then return end
        if input:GetKeyPress(KEY_F16) then
            assert(not held,'QA stock fixture already prepared')
            assert(app.lobby=='salvage' and app.mode=='hangar','Prepare only actual salvage hall')
            local lobby=app.salvageLobby
            held={lobby=lobby,data=lobby.data,save=lobby.Save,saveCalls=0,saveStockChanged=false}
            lobby.data=Copy(lobby.data);lobby.data.items={}
            local expected=cjson.encode(Stock(lobby.data))
            lobby.Save=function(self)
                held.saveCalls=held.saveCalls+1
                if cjson.encode(Stock(self.data))~=expected then held.saveStockChanged=true end
                return true
            end
            require('ui.GarageHud').GetState().revision=-1
            Snapshot(app,'prepared')
        elseif input:GetKeyPress(KEY_F17) and held then Snapshot(app,'observed')
        elseif input:GetKeyPress(KEY_F18) and held then
            local state=held;state.lobby.data=state.data;state.lobby.Save=state.save
            local home=require('ui.GarageHud').GetState();if home then home.revision=-1 end
            Snapshot(app,'restored');held=nil
        end
    end
end
