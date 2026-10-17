"""Run real Lua projectile filtering/Bolt rendering with exact draw and RNG checks."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

baseline = ROOT / '.tmp/outgame-cached-1792217492466/scripts/render/CombatSourceFx.lua'
assert hashlib.sha256(baseline.read_bytes()).hexdigest() == 'c3d6ed6a7867fd59c32d5fc78496111ed5a9e455cd66f39e92708cf7a163570e'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.globals().BASELINE_PATH = baseline.as_posix()
lua.execute('''
for _,name in ipairs({'render.CombatLight','render.MissileEffects','render.MissileView',
 'render.DrillEffects','render.EffectBatch','render.Quality','render.ChipEffects'}) do
 package.loaded[name]={}
end
Actual=require 'render.CombatSourceFx'
Before=assert(loadfile(BASELINE_PATH))()
Effects=require 'render.CombatEffects'
local function Same(a,b,path)
 path=path or 'root';assert(type(a)==type(b),path..' type')
 if type(a)=='number' then assert(string.pack('d',a)==string.pack('d',b),path..' number')
 elseif type(a)=='table' then
  for k,v in pairs(a) do Same(v,b[k],path..'.'..tostring(k)) end
  for k in pairs(b) do assert(a[k]~=nil,path..' extra '..tostring(k)) end
 else assert(a==b,path..' value') end
end
local color={glow={3.6,2.3,.6},core={8,6.6,3.6},inner={2.8,1.85,.5}}
local function Draw(module,p,seed)
 local streaks,glows={},{}
 local batch={Segment=function(_,...) streaks[#streaks+1]=table.pack(...) end}
 math.randomseed(seed)
 module.Bolt(batch,function(...) glows[#glows+1]=table.pack(...) end,p,color)
 return {streaks=streaks,glows=glows,nextRandom=math.random()}
end
function Check(module)
 local count=0
 for tier=1,5 do for _,bright in ipairs({false,true}) do
 for _,velocity in ipairs({{0,0,0},{0,0,250},{-40,15,8},{300,-100,-45}}) do
 for _,seed in ipairs({0,.5,1}) do for _,distance in ipairs({.01,12.01,22,100,400}) do
  local p={pos={-15,2,10},vel=velocity,dist=distance,seed=seed,bright=bright,s={tier=tier}}
  for _,own in ipairs({false,true}) do
   p.adsOwnProjectile=own or nil
   local expected=Draw(Before,p,count+721)
   local got=Draw(module,p,count+721)
   Same(got.streaks,expected.streaks,'streaks')
   Same(got.nextRandom,expected.nextRandom,'rng')
   if own then assert(#got.glows==0,'own ADS round glow remains')
   else Same(got.glows,expected.glows,'remote-or-released glows') end
   assert(#got.streaks==2,'two original streaks retained')
   count=count+1
  end
 end end end end end
 return count
end
function Projectiles()
 local own,far={fx='bolt',dist=22,pos={1,2,3}},{fx='bolt',dist=55}
 local near,missile={fx='bolt',dist=12},{fx='missile',dist=20}
 local closeMissile,enemy={fx='missile',dist=6},{fx='bolt',dist=22}
 local all={own,far,near,missile,closeMissile,enemy}
 local source={projectiles={own,far,near,missile,closeMissile}}
 local effect=setmetatable({},Effects)
 effect:SetFirstPerson(true,source,{})
 local filtered=effect:Projectiles(all)
 assert(#filtered==4,'near thresholds retained')
 assert(filtered[1]~=own and filtered[1].dist==10 and filtered[1].adsOwnProjectile==true)
 assert(filtered[2]~=far and filtered[2].dist==43 and filtered[2].adsOwnProjectile==true)
 assert(filtered[3]~=missile and filtered[3].dist==14 and not filtered[3].adsOwnProjectile)
 assert(filtered[4]==enemy and not enemy.adsOwnProjectile,'remote identity and glow unchanged')
 assert(not own.adsOwnProjectile and own.dist==22 and not far.adsOwnProjectile)
 assert(not near.adsOwnProjectile and not missile.adsOwnProjectile and closeMissile.dist==6)
 effect:SetFirstPerson(false,source,{})
 assert(effect:Projectiles(all)==all and not own.adsOwnProjectile,'release restores original list')
 effect:SetFirstPerson(true,nil,{})
 assert(effect:Projectiles(all)==all,'missing own system preserves list')
 return 9
end
''')
checks = lua.globals().Check(lua.globals().Actual)
projectile_checks = lua.globals().Projectiles()
negative_controls = []
for name, mutation in [
    ('unmodified round glow', "function(_,...) return Before.Bolt(...) end"),
    ('extra RNG advance', "function(...) math.random();return Actual.Bolt(...) end"),
    ('missing streak', "function(batch,glow,p,color) local proxy={Segment=function() end};return Actual.Bolt(proxy,glow,p,color) end"),
]:
    if name == 'unmodified round glow':
        candidate = lua.globals().Before
    else:
        candidate = lua.eval('{Bolt=' + mutation + '}')
    try:
        lua.globals().Check(candidate)
    except Exception:
        negative_controls.append(name)
    else:
        raise AssertionError('Negative control accepted: ' + name)
result = {
    'result': 'PASS', 'boltCases': checks, 'projectileChecks': projectile_checks,
    'negativeControlsRejected': negative_controls,
    'production': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in [ROOT/'scripts/render/CombatSourceFx.lua', ROOT/'scripts/render/CombatEffects.lua']},
    'boundary': 'Actual Lua modules with draw sinks; not Web rendering or FPS acceptance',
}
if len(sys.argv) > 1:
    (ROOT/sys.argv[1]).write_text(json.dumps(result, indent=2)+'\n',encoding='utf-8')
print(json.dumps(result, indent=2))
