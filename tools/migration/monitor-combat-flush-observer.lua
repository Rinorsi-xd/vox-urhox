-- Isolated attribution suffix; appended after the unchanged capture observer.
do
local installed=false
local selected={
 {'construction.Blueprint','Graph','flush.graph'},
 {'construction.Blueprint','Connectivity','flush.connectivity'},
 {'drive.VehicleSpec','Build','flush.specBuild'},
 {'drive.VehicleSpec','BuildParts','flush.buildParts'},
 {'drive.VehicleSpec','MergeBoxes','flush.mergeBoxes'},
 {'construction.Rotors','Spec','flush.rotors'},
 {'construction.TurretRange','For','flush.turretRange'},
 {'combat.CarUnit','DisposeVehicle','flush.disposeVehicle'},
}
local update=HandleUpdate
function HandleUpdate(...)
 if not installed and app and app.trial and app.trial.vehicle and performance then
  assert(performance.enabled,'Flush attribution requires the default enabled monitor')
  for _,entry in ipairs(selected)do
   local module=require(entry[1])
   assert(type(module)=='table' and type(module[entry[2]])=='function','Missing flush method '..entry[1]..'.'..entry[2])
   performance:Wrap(module,entry[2],entry[3])
  end
  installed=true
  print('MONITOR_COMBAT_FLUSH_READY '..cjson.encode({count=#selected,frame=GetTime().frameNumber}))
 end
 return update(...)
end
end
