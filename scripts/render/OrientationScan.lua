-- Recognize two complete four-colour squares, never whole-screen colour centroids.
-- Screenshot coordinates may be scaled or inverted; only relative quadrant order matters.
local M={}
local function Classify(c)
    local r,g,b=c.r,c.g,c.b
    local hi=math.max(r,g,b);if hi<.7 then return nil end
    local lo=hi*.3
    local R,G,B=r>=hi*.8,g>=hi*.8,b>=hi*.8
    if R and G and B then return 4 end
    if R and B and g<lo then return 5 end
    if R and G and b<lo then return 6 end
    if G and B and r<lo then return 7 end
    if R and g<lo and b<lo then return 1 end
    if G and r<lo and b<lo then return 2 end
    if B and g<lo then
        if r>hi*.35 and r<hi*.8 then return 8 end
        if r<lo then return 3 end
    end
end
local function Components(pixels,cols,rows)
    local out={}
    for index=1,cols*rows do
        local key=pixels[index]
        if key then
            local queue={index};pixels[index]=nil
            local head,n=1,0
            local xmin,ymin,xmax,ymax=cols,rows,0,0
            while head<=#queue do
                local at=queue[head];head=head+1
                local x,y=(at-1)%cols,math.floor((at-1)/cols)
                n=n+1;xmin=math.min(xmin,x);xmax=math.max(xmax,x);ymin=math.min(ymin,y);ymax=math.max(ymax,y)
                local function Visit(nextIndex)
                    if pixels[nextIndex]==key then pixels[nextIndex]=nil;queue[#queue+1]=nextIndex end
                end
                if x>0 then Visit(at-1) end
                if x<cols-1 then Visit(at+1) end
                if y>0 then Visit(at-cols) end
                if y<rows-1 then Visit(at+cols) end
            end
            local w,h=xmax-xmin+1,ymax-ymin+1
            -- A quadrant is a filled, approximately square component. Reject text/scene regions.
            if n>=4 and w>=2 and h>=2 and n>=w*h*.75 and w/h>=.6 and w/h<=1.67 then
                out[#out+1]={key=key,x=(xmin+xmax)/2,y=(ymin+ymax)/2,w=w,h=h,n=n}
            end
        end
    end
    return out
end
local function FindSquare(parts,first)
    local found
    for _,a in ipairs(parts) do if a.key>=first and a.key<first+4 then
        local slots={[1]=a};local ambiguous=false
        for _,b in ipairs(parts) do if b~=a and b.key>=first and b.key<first+4 then
            local w,h=(a.w+b.w)/2,(a.h+b.h)/2
            if math.abs(a.w-b.w)<=math.max(1,w*.3) and math.abs(a.h-b.h)<=math.max(1,h*.3) then
                local dx,dy=b.x-a.x,b.y-a.y
                local sameX,sameY=math.abs(dx)<=math.max(.6,w*.2),math.abs(dy)<=math.max(.6,h*.2)
                local nextX,nextY=math.abs(dx-w)<=math.max(1,w*.25),math.abs(dy-h)<=math.max(1,h*.25)
                local slot=nextX and sameY and 2 or sameX and nextY and 3 or nextX and nextY and 4
                if slot then if slots[slot] then ambiguous=true else slots[slot]=b end end
            end
        end end
        if not ambiguous and slots[2] and slots[3] and slots[4] then
            local seen,order={},{}
            for i=1,4 do seen[slots[i].key]=true;order[i]=slots[i].key end
            if seen[first] and seen[first+1] and seen[first+2] and seen[first+3] then
                -- Multiple valid markers are ambiguous; do not silently pick one.
                if found then return nil end
                found=order
            end
        end
    end end
    return found
end
function M.Scan(image)
    local w,h=image:GetWidth(),image:GetHeight()
    if w<16 or h<16 then return nil end
    local step=math.max(1,math.ceil(math.sqrt(w*h/20000)))
    local cols,rows=math.ceil(w/step),math.ceil(h/step)
    local pixels={}
    for y=0,rows-1 do for x=0,cols-1 do
        pixels[y*cols+x+1]=Classify(image:GetPixel(x*step,y*step))
    end end
    local parts=Components(pixels,cols,rows)
    local ref,probe=FindSquare(parts,1),FindSquare(parts,5)
    return {refOrder=ref,probeOrder=probe,refCount=ref and 4 or 0,probeCount=probe and 4 or 0}
end
function M.Resolve(scan)
    if not scan or not scan.refOrder or not scan.probeOrder then return nil end
    local flips={['1234']={1,1},['2143']={-1,1},['3412']={1,-1},['4321']={-1,-1}}
    local keys={}
    for i=1,4 do keys[i]=scan.probeOrder[i]-4 end
    local refKey,probeKey=table.concat(scan.refOrder),table.concat(keys)
    local base,flip=flips[refKey],flips[probeKey]
    if not base or not flip then return nil end
    return flip,probeKey,base,refKey
end
return M
