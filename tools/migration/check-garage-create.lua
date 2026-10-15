local Garage=require 'construction.Garage'
local Blueprint=require 'construction.Blueprint'
V.atFrame(20,function()
    for _,mode in ipairs({'ok','save-false','save-throw','replace-false','replace-throw','activate-false','delete-false','delete-throw','restore-false'}) do
        local bp=Blueprint.New();bp.name='original'
        local slots={};local metadata=false;local deleted=0
        local store={LoadSlot=function(_,slot) return slots[slot] end,
            SaveSlot=function(_,slot,candidate)
                slots[slot]=candidate:ToTable()
                if mode=='save-throw' then error('injected save exception') end
                return mode~='save-false','injected save rejection'
            end,
            SaveGarageState=function(_,slot)
                if slot and mode=='activate-false' then return false,'metadata failure' end
                metadata=slot;return true
            end,
            Queue=function() end,Flush=function() return true end,
            DeleteSlot=function(_,slot)
                deleted=deleted+1
                if mode=='delete-throw' then error('injected cleanup exception') end
                if mode=='delete-false' then return false end
                slots[slot]=nil;return true
            end}
        local replace=function(data)
            if data.name~='original' then
                if mode=='replace-throw' then bp:Load(data);error('injected replacement exception') end
                if mode=='replace-false' or mode=='delete-false' or mode=='delete-throw' or mode=='restore-false' then return false,'replacement rejection' end
            elseif mode=='restore-false' then return false end
            bp:Load(data);return true
        end
        local garage=Garage.New(bp,store,replace,false);garage.unsaved=false
        local called,ok,err,reason=pcall(garage.CreateVehicle,garage,bp:ToTable(),'candidate',false)
        V.assert(called,'creation contains partial-write exceptions '..mode)
        if mode=='ok' then
            V.assert(ok and slots[1] and garage.active==1 and metadata==1 and deleted==0,'successful creation remains active and saved')
        elseif mode=='delete-false' or mode=='delete-throw' or mode=='restore-false' then
            V.assert(not ok and reason=='rollback','unresolved cleanup explicitly prevents purchase refund '..mode)
        else
            V.assert(not ok and reason~='rollback' and not slots[1] and deleted==1,'failed creation retires allocated slot '..mode)
            V.assert(bp.name=='original' and garage.active==false and metadata==false,'failed creation restores visible vehicle and metadata '..mode)
        end
    end
    V.finish()
end)
