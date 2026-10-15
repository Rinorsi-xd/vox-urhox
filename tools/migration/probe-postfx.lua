V.atFrame(45,function()
    local app=VOX_HANGAR.app;local zone=app.scene:GetComponent('Zone',true)
    local data={bindings={},attributes={},commands={}}
    for _,name in ipairs({'SetAutoExposurePlusEnabled','SetAutoExposureBias','GetSSAORadius','SetTonemapLUTTexture'}) do
        local ok,value=pcall(function() return zone[name] end);data.bindings[name]=ok and type(value) or tostring(value)
    end
    for index=0,zone:GetNumAttributes()-1 do
        local info=zone:GetAttributeInfo(index)
        data.attributes[#data.attributes+1]={name=info.name,value=zone:GetAttribute(index):ToString()}
    end
    local path=renderer:GetDefaultRenderPath()
    for index=0,path:GetNumCommands()-1 do
        local c=path:GetCommand(index);local outputs={}
        for i=0,c:GetNumOutputs()-1 do outputs[#outputs+1]=c:GetOutputName(i) end
        data.commands[#data.commands+1]={type=c.type,tag=c.tag,pass=c.pass,vs=c.vertexShaderName,ps=c.pixelShaderName,vsdefines=c.vertexShaderDefines,psdefines=c.pixelShaderDefines,enabled=c.enabled,outputs=outputs}
    end
    local file=File('.tmp/postfx-capabilities.json',FILE_WRITE);file:WriteString(cjson.encode(data));file:Dispose()
    fileSystem:CreateDir('.tmp/engine-postfx')
    for _,name in ipairs({'BloomUE','GaussianBlur','CopyFramebuffer','HistogramExposureUE'}) do
        local path='Shaders/BLGL/'..name..'.glsl'
        if cache:Exists(path) then
            local source=cache:GetFile(path);local text=source:ReadString();source:Dispose()
            local output=File('.tmp/engine-postfx/'..name..'.glsl',FILE_WRITE);output:WriteString(text);output:Dispose()
        end
    end
    V.assert(#data.attributes>0 and #data.commands>0,'native graphics capabilities recorded');V.finish()
end)
