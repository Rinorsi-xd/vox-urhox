'use strict';
const methods=[
 ['app.TrialSession',['Aim'],'trial'],
 ['combat.BattleController',['SyncPlayer'],'combat'],
 ['render.CombatView',['SavePose'],'combatView'],
 ['render.DriveView',['Update','SavePose'],'driveView'],
 ['render.VehicleView',['UpdateIdle','UpdateWeaponEffects'],'vehicleView'],
 ['render.WeaponView',['Update'],'weaponView'],
 ['render.RotorView',['Update'],'rotorView'],
 ['render.ActuatorView',['Update'],'actuatorView'],
 ['render.LegView',['Update'],'legView'],
 ['render.MechView',['Update'],'mechView'],
 ['render.WingRig',['Update'],'wingRig'],
 ['render.EquipmentEffects',['Update'],'equipmentEffects'],
 ['render.PartHitFlash',['Update'],'hitFlash'],
 ['render.RestoreFlash',['Consume','Update'],'restoreFlash'],
 ['render.CombatEffects',['Consume','Update'],'effects'],
 ['render.JoinedMesh',['Update'],'joinedMesh'],
 ['render.LiveryLayer',['Update'],'livery'],
 ['render.WeaponEffects',['Update'],'weaponEffects'],
 ['render.WeaponPresentation',['Update'],'weaponPresentation'],
 ['audio.WeaponAudio',['Update','SetActive','Consume'],'weaponAudio'],
 ['audio.DrivingAudio',['Update','Observe','SetActive'],'drivingAudio'],
 ['audio.CombatFeedbackAudio',['Update','Consume','SetActive'],'feedbackAudio'],
 ['audio.CollisionAudio',['BeforeStep','AfterStep'],'collisionAudio'],
 ['audio.DrivingEvents',['Observe'],'drivingEvents'],
 ['drive.TrialMetrics',['Timing'],'metrics'],
 ['controls.SafeReset',['Update'],'safeReset'],
 ['ui.DriveOverlay',['Update','Consume'],'hud.overlay'],
 ['ui.ReticleState',['Update'],'hud.reticle'],
];
const moduleBindings=methods.reduce((count,row)=>count+row[1].length,0);
const instanceLabels=['hud.Update','hud.readouts.Tick','hud.readouts.Refresh','hud.mode.Update','hud.sniper.Update'];
const sourceModules=[...new Set([...methods.map(row=>row[0]),'ui.DriveHud','ui.DriveReadouts','ui.MatchHud','ui.MissionHud','ui.SniperThreat'])];
const baseline={methods,moduleBindings,instanceLabels,sourceModules,expectedBindings:57+moduleBindings+instanceLabels.length,profile:'trial-sections-v1'};
const afterStepMethods=[
 ['combat.BattleController',['WorldState'],'combat'],
 ['combat.BattleObjectives',['WorldState','Update'],'objectives'],
 ['render.ObjectiveView',['Update'],'objectiveView'],
 ['combat.ConquestRules',['Step'],'conquestRules'],
 ['audio.BattleFlow',['Countdown'],'battleFlow'],
];
const afterStep={...baseline,methods:[...methods,...afterStepMethods],moduleBindings:moduleBindings+6,
 sourceModules:[...new Set([...sourceModules,...afterStepMethods.map(row=>row[0])])],
 expectedBindings:baseline.expectedBindings+6,profile:'trial-after-step-v1'};
function forProfile(afterStepEnabled=false){return afterStepEnabled?afterStep:baseline}
module.exports={...baseline,afterStep,forProfile};
