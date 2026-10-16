local checks=0
local function SameNumber(a,b,label)
    checks=checks+1
    assert((a~=a and b~=b) or string.pack('d',a)==string.pack('d',b),label)
end
local function Same(a,b,label)
    assert(type(a)=='table' and type(b)=='table',label..' result table')
    for k,v in pairs(a)do SameNumber(v,b[k],label..'/'..k)end
    for k in pairs(b)do assert(a[k]~=nil,label..' extra key')end
end
local function Inputs(a,b,v,label)
    local beforeA,beforeB,beforeV={a.x,a.y,a.z,a.w},{b.x,b.y,b.z,b.w},{v[1],v[2],v[3]}
    Same(BASE_MATH.QMul(a,b),CAND_MATH.QMul(a,b),label..'/QMul')
    Same(BASE_MATH.RotateUnit(a,v),CAND_MATH.RotateUnit(a,v),label..'/RotateUnit')
    for i,k in ipairs({'x','y','z','w'})do SameNumber(a[k],beforeA[i],label..'/input a');SameNumber(b[k],beforeB[i],label..'/input b')end
    for i=1,3 do SameNumber(v[i],beforeV[i],label..'/input vector')end
    local first=CAND_MATH.QMul(a,b);local second=CAND_MATH.QMul(a,b)
    assert(first~=second and first~=a and first~=b,label..'/fresh quaternion')
    first=CAND_MATH.RotateUnit(a,v);second=CAND_MATH.RotateUnit(a,v)
    assert(first~=second and first~=a and first~=v,label..'/fresh vector')
    checks=checks+2
end
math.randomseed(7137)
for i=1,100000 do
    local function N()return (math.random()*2-1)*1000 end
    Inputs({x=N(),y=N(),z=N(),w=N()},{x=N(),y=N(),z=N(),w=N()},{N(),N(),N()},'random '..i)
end
local values={0.0,-0.0,1.0,-1.0,1e-300,-1e-300,1e150,-1e150,math.huge,-math.huge,0/0}
for i,x in ipairs(values)do
    Inputs({x=x,y=-.25,z=.6,w=.8},{x=.1,y=x,z=-.3,w=.4},{1,x,-2},'edge '..i)
end
local q={x=.25,y=-.5,z=.75,w=2}
Inputs(q,q,{4,-2,8},'same quaternion input, nonunit')
local vector={3,-2,4,x=.2,y=-.3,z=.8,w=.5}
Inputs(vector,vector,vector,'all inputs alias')
local delegated=setmetatable({},{__index={x=.2,y=-.3,z=.8,w=.5,[1]=3,[2]=-2,[3]=4}})
Inputs(delegated,delegated,delegated,'metatable fields')
local randomState=math.random
local function Uniform()return randomState()*2-1 end
for i=1,1000 do
    local a={x=Uniform(),y=Uniform(),z=Uniform(),w=Uniform()}
    local size=math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z+a.w*a.w)
    for _,key in ipairs({'x','y','z','w'})do a[key]=a[key]/size end
    Inputs(a,{x=0,y=0,z=0,w=1},{Uniform(),Uniform(),Uniform()},'unit '..i)
end
MATH_SCALAR_CHECKS=checks
MATH_SCALAR_BENCH={}
local a={x=.12,y=-.48,z=.73,w=.65};local b={x=.21,y=.62,z=-.33,w=.47};local v={2.6,-4.8,7.1}
for _,name in ipairs({'QMul','RotateUnit'})do
    local row={name=name,calls=500000,baseline={},candidate={}}
    for pass=1,3 do
        for _,entry in ipairs(pass%2==0 and {{'candidate',CAND_MATH},{'baseline',BASE_MATH}} or {{'baseline',BASE_MATH},{'candidate',CAND_MATH}})do
            collectgarbage('collect');local fn=entry[2][name];local argument=name=='QMul' and b or v
            local start=os.clock();local sum=0
            for i=1,row.calls do local out=fn(a,argument);sum=sum+(out.x or out[1])end
            row[entry[1]][pass]={seconds=os.clock()-start,checksum=sum}
        end
        SameNumber(row.baseline[pass].checksum,row.candidate[pass].checksum,name..' benchmark checksum')
    end
    MATH_SCALAR_BENCH[#MATH_SCALAR_BENCH+1]=row
end
MATH_SCALAR_CHECKS=checks
