-- Explicit QA-only output projection; no game state is changed.
VOX_QA_HOME_ROUTE={}
function VOX_QA_HOME_ROUTE.Project(data)
    local out={observer='home-route-v1',widgets={}}
    for _,key in ipairs({'width','height','mode','tab','blueprint','parts','carVisuals','garage',
        'vehicleLoading','loadingFlow','storage','lobby','salvage','salvageInventory',
        'salvageQuantity','dialog','frames','sceneVisible','preview'}) do out[key]=data[key] end
    out.hangar=data.hangar and {scan=data.hangar.scan}
    out.workshop=data.workshop and {view=data.workshop.view,selected=data.workshop.selected,pending=data.workshop.pending}
    for _,widget in ipairs(data.widgets or {}) do
        out.widgets[#out.widgets+1]={text=widget.text,kind=widget.kind,rect=widget.rect,
            disabled=widget.disabled,entrance=widget.entrance,card=widget.card}
    end
    return out
end
