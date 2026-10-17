-- Isolated semantic child scopes. No per-ray, per-vertex or per-quad wrappers.
do
local installed=false
local selected={
 {'combat.EnemyDriverThink','Run','sim.ai.think'},
 {'combat.EnemyDriverThink','Sniper','sim.ai.sniper'},
 {'combat.EnemyDriverThink','Route','sim.ai.route'},
 {'combat.EnemyDriverMotion','Run','sim.ai.motion'},
 {'combat.EnemyDriverMotion','Crowd','sim.ai.crowd'},
 {'combat.EnemyDriverMotion','Recover','sim.ai.recover'},
 {'combat.EnemyDriver','Missiles','sim.ai.missiles'},
 {'combat.EnemyDriverNav','Graph','sim.nav.graph'},
 {'combat.EnemyDriverNav','Path','sim.nav.path'},
 {'combat.EnemyDriverNav','Nearest','sim.nav.nearest'},
 {'combat.EnemyDriverNav','Direct','sim.nav.direct'},
 {'combat.EnemyDriverNav','Visible','sim.nav.visible'},
 {'combat.EnemyDriverTactics','Cover','sim.tactics.cover'},
 {'combat.EnemyDriverTactics','Firing','sim.tactics.firing'},
 {'combat.EnemyDriverTactics','Strafe','sim.tactics.strafe'},
 {'combat.EnemyDriverTactics','Slide','sim.tactics.slide'},
 {'drive.LegGait','Foothold','sim.legs.foothold'},
 {'drive.LegControl','Clear','sim.legs.clear'},
 {'drive.LegControl','Reachable','sim.legs.reachable'},
 {'parts.LegIK','Solve','sim.ik.solve'},
 {'parts.LegIK','Reachable','sim.ik.reachable'},
 {'render.CombatEffects','Path','sim.combatFx.path'},
 {'render.CombatEffects','Helix','sim.combatFx.helix'},
 {'render.CombatEffects','Projectiles','sim.combatFx.projectiles'},
 {'render.WeaponEffects','Bands','sim.weaponFx.bands'},
 {'render.WeaponEffects','Motes','sim.weaponFx.motes'},
 {'render.WeaponEffects','Swirl','sim.weaponFx.swirl'},
 {'render.WeaponEffects','Arcs','sim.weaponFx.arcs'},
 {'render.WeaponEffects','Path','sim.weaponFx.path'},
}
local update=HandleUpdate
function HandleUpdate(...)
 if not installed and app and app.trial and app.trial.vehicle and performance then
  assert(performance.enabled,'Simulation attribution requires the default enabled monitor')
  for _,entry in ipairs(selected)do
   local module=require(entry[1])
   assert(type(module)=='table' and type(module[entry[2]])=='function','Missing simulation method '..entry[1]..'.'..entry[2])
   performance:Wrap(module,entry[2],entry[3])
  end
  installed=true
  print('MONITOR_COMBAT_SIMULATION_READY '..cjson.encode({count=#selected,frame=GetTime().frameNumber,debugUpvalues=false}))
 end
 return update(...)
end
end
