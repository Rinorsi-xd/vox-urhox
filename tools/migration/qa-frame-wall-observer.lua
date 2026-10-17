-- Only concatenated into QA main; normal runtime scripts are unchanged.
local VOX_QA_FRAME_WALL=(function()
    local samples={};local mode=false;local last=false;local first=false;local drops=0
    local function Observe(stamp,nextMode,excluded)
        if excluded or nextMode~=mode or not last or stamp<last then
            samples={};drops=0;mode=nextMode;last=stamp;first=stamp
            if excluded then mode=false end
            return
        end
        if #samples<4096 then samples[#samples+1]=stamp-last else drops=drops+1 end
        last=stamp
    end
    local function Drain()
        if #samples==0 then return nil end
        local ordered={};local total=0
        for i,value in ipairs(samples) do ordered[i]=value;total=total+value end
        table.sort(ordered);local n=#ordered
        local result={count=n,totalMs=total,p50=ordered[math.ceil(n*.5)],p95=ordered[math.ceil(n*.95)],
            p99=ordered[math.ceil(n*.99)],max=ordered[n],samplesMs=samples,
            firstClockMs=first,lastClockMs=last,dropped=drops,
            source='QA Update entry wall interval; Time:GetSystemTime integer milliseconds; includes engine, waits and observers, not CPU or presentation time'}
        samples={};first=last;drops=0
        return result
    end
    return {Observe=Observe,Drain=Drain}
end)()
