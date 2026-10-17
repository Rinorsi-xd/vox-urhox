const assert=require('node:assert/strict');
function assertResultInReturnedHall(state){
 assert.equal(state.mode,'hangar','Result is displayed only after actual hall installation');
 assert.equal(state.lobby,'salvage','Result is owned by original salvage hall');
 assert.equal(Boolean(state.loadingFlow?.active),false,'Result waits until return loading closes');
 assert.ok(!state.salvageRun,'Result never keeps a live salvage driver');
 assert.equal(state.dialog,true,'Returned hall owns the actual result dialog');
 const pending=state.salvageReturn;assert.ok(pending?.result&&pending.runId,'Detached original result is observed');
 assert.equal(pending.shown,true,'Detached result was shown by hall consumer');
 assert.equal(pending.committed,true,'Natural result was saved before acknowledgement');
 for(const key of ['disposed','scene','world','combat','effects','view','hud'])
  assert.equal(pending.release?.[key],true,'Actual old trial release observed: '+key);
 return {status:'HALL_RESULT_ACK_PENDING',runId:pending.runId,result:pending.result,release:pending.release};
}
function assertResultAcknowledgement(before,after){
 assertResultInReturnedHall(before);assertReturnedSurface(after);
 assert.ok(!after.salvageReturn,'Acknowledgement clears the retained hall result');
 assert.equal(typeof before.hallGeneration,'number','Actual hall generation was observed');
 assert.equal(after.hallGeneration,before.hallGeneration,'Acknowledgement does not reload hall');
 assert.equal(after.blueprint,before.blueprint,'Acknowledgement preserves selected original vehicle');
 assert.deepEqual(after.salvageInventory,before.salvageInventory,'Acknowledgement does not settle economy again');
 return {status:'ACK_CLOSED_IN_HALL',runId:before.salvageReturn.runId};
}
function assertReturnedSurface(state){
 assert.equal(state.mode,'hangar','Actual result returned to hall');
 assert.equal(state.lobby,'salvage','Actual salvage lobby restored');
 assert.equal(Boolean(state.loadingFlow?.active),false,'Return loading is closed');
 assert.equal(Boolean(state.dialog),false,'No owned result/dialog remains open');
 assert.ok(!state.salvageRun,'Live salvage session is absent after return');
 const overlay=state.overlayState;assert.ok(overlay&&typeof overlay.present==='boolean','Actual bounded overlay identity was observed');
 assert.equal(Boolean(state.mouse?.overlay),overlay.present,'Legacy overlay flag agrees with actual identity');
 if(overlay.present){
  assert.equal(overlay.stackAvailable,true,'Runtime exposes actual stack ownership');
  assert.equal(overlay.stackTruncated,false,'Full small overlay stack was observed');
  assert.ok(overlay.stack.length>0,'Actual stack entries exist');
  for(const item of overlay.stack){
   if(item.owner==='main.performancePanel'){
    assert.equal(item.className,'Panel','Performance overlay is the observed root panel');
    assert.equal(item.pointerEvents,'box-none','Performance root passes input outside its controls');
    assert.equal(item.hitTestBound,true,'Actual performance root retains its hit-test handler');
    assert.equal(item.visible,true,'Performance root is visible');
    assert.equal(item.panelVisible,true,'Actual performance owner is visible');
    assert.equal(item.disposed,false,'Actual performance owner is still valid');
    continue;
   }
   assert.equal(item.className,'VoxDebugPanel','No unrecognized modal is hidden under the top overlay');
   assert.equal(item.owner,'app.debugPanel','Debug is the actual application-owned widget, not a matching class name');
   assert.equal(item.registeredName,'vox-debug','Actual debug widget identity is known');
   assert.equal(item.open,false,'Debug panel is closed');assert.equal(item.disposed,false,'Debug widget is still valid');
  }
 }
 return {status:'SURFACE_OBSERVED_INPUT_PENDING',overlay};
}
function assertLobbyRoundTrip(before,garage,loadout){
 assertReturnedSurface(before);assertReturnedSurface(garage);assertReturnedSurface(loadout);
 assert.equal(before.salvage?.tab,'loadout','Returned page starts at actual loadout');
 assert.equal(garage.salvage?.tab,'garage','Real mouse click reached original garage page');
 assert.equal(loadout.salvage?.tab,'loadout','Real mouse click returned to original loadout');
 assert.equal(garage.blueprint,before.blueprint,'Garage input check did not replace vehicle');
 assert.equal(loadout.blueprint,before.blueprint,'Loadout input check preserved vehicle');
 return {status:'PASS',blueprint:before.blueprint,steps:['returned-loadout','mouse-garage','mouse-loadout'],boundary:'Actual distinct public mouse-click page transitions plus exact overlay ownership, not nil-overlay filtering.'};
}
module.exports={assertReturnedSurface,assertLobbyRoundTrip,assertResultInReturnedHall,assertResultAcknowledgement};
