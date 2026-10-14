-- Frozen matchmaker.js RNG, lineup, skill and rating progression.
local Data=require 'combat.ArenaData'
local M={}
local function Valid(p) return type(p)=='table' and type(p.rating)=='number' and type(p.recent)=='table' end
M.Valid=Valid
local function Read(store) return store:Read('match-profile',Valid) or {rating=1000,games=0,wins=0,streak=0,level=1,xp=0,recent={},introSeen={}} end
local function Rng(seed)
    local state=seed & 0xffffffff;if state==0 then state=1 end
    return function()
        state=(state+0x6D2B79F5) & 0xffffffff
        local t=((state ~ (state >> 15))*(state | 1)) & 0xffffffff
        t=t ~ ((t+(((t ~ (t >> 7))*(t | 61)) & 0xffffffff)) & 0xffffffff)
        return ((t ~ (t >> 14)) & 0xffffffff)/4294967296
    end
end
function M.Find(store,size,tier,name,seed)
    local p=Read(store);local random=Rng(seed or (os.time()+math.random(1,1000000)))
    local used,pool={},{};for _,n in ipairs(p.recent) do used[n]=true end
    for _,n in ipairs(Data.names) do if not used[n] then pool[#pool+1]=n end end
    local bias=p.streak<=-2 and -90 or p.streak>=3 and 70 or 0
    local lineup=Data.lineup[tostring(size)]
    local function Bot(team,i,base)
        local rating=math.floor(base+(random()-.5)*160+.5)
        local index=math.floor(random()*#pool)+1;local n=table.remove(pool,index) or Data.names[math.floor(random()*#Data.names)+1]
        local role=lineup[i%#lineup+1];local variant=random()<.4 and tier<=3 and (role=='assault' or role=='heavy') and 1 or 0
        local k=math.max(0,math.min(1,(rating-700)/800))
        return {team=team,name=n,bot=true,role=role,tier=tier,variant=variant,rating=rating,
            level=math.max(1,math.floor(p.level+2+(random()-.3)*14+.5)),aimSkill=.95-k*.55,reaction=.7-k*.4}
    end
    local roster={blue={{team='blue',name=name or '你',bot=false,player=true,rating=p.rating,level=p.level,tier=tier}},red={},rating={}}
    for i=1,size-1 do roster.blue[#roster.blue+1]=Bot('blue',i,p.rating-40) end
    for i=0,size-1 do roster.red[#roster.red+1]=Bot('red',i,p.rating+20+bias) end
    local first=math.floor(random()*10);local i=0;local recent={}
    for _,team in ipairs({'blue','red'}) do local sum=0
        for _,member in ipairs(roster[team]) do
            member.avatar=member.player and 'me' or string.format('a%02d',(first+i)%10+2);i=i+1;sum=sum+member.rating
            if member.bot then recent[#recent+1]=member.name end
        end
        roster.rating[team]=math.floor(sum/size+.5)
    end
    for _,n in ipairs(p.recent) do if #recent<30 then recent[#recent+1]=n end end
    p.recent=recent;store:Write('match-profile',p,Valid);roster.wait=6+random()*8;return roster
end
function M.IntroSeen(store,mode) local p=Read(store);return p.introSeen and p.introSeen[mode]==true end
function M.MarkIntro(store,mode) local p=Read(store);p.introSeen=p.introSeen or {};p.introSeen[mode]=true;return store:Write('match-profile',p,Valid) end
function M.Record(store,winner,rating,kills,mvp)
    local p=Read(store);local won=winner=='blue';local expected=1/(1+10^((rating-p.rating)/400))
    local delta=math.floor(32*((not winner and .5 or won and 1 or 0)-expected)+.5)
    p.rating=math.max(100,p.rating+delta);p.games=p.games+1;p.wins=p.wins+(won and 1 or 0)
    p.streak=not winner and 0 or won and math.max(1,p.streak+1) or math.min(-1,p.streak-1)
    local xp=100+(won and 80 or 0)+kills*15+(mvp and 50 or 0);p.xp=p.xp+xp
    while p.xp>=400+p.level*120 do p.xp=p.xp-(400+p.level*120);p.level=p.level+1 end
    local ok=store:Write('match-profile',p,Valid);return {delta=delta,xp=xp,profile=p,saved=ok}
end
return M
