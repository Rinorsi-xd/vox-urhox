local UI=require 'urhox-libs/UI'
local I
local page
local folder='docs/migration/evidence/opening-comic-dialog-native-2026-10-15-final/'
local function Shot(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG(folder..name..'.png'),'rendered screenshot '..name);image:Dispose()
end
function HoldOpeningParity()if page then UI.SetRoot(page)end end
V.atFrame(2,function()
 I=require('intro.IntroSession').New({},{state={}});I.active=true;I.downloaded=true;I.stage='boot';I.shot='boot';page=I.page
 UI.SetRoot(page);SubscribeToEvent('PostUpdate','HoldOpeningParity')
end)
V.atFrame(22,function()
 V.assert(page.imageWarmup.ready,'actual source image uploads ready')
 I.stage='ad';I.shot='prosper';I.time=1;I.age=1;I.log={{shot='prosper',t=0}}
end)
V.atFrame(25,function()
 Shot('comic-prosper');V.assert(page.comicStates.prosper.age==1,'city first independent clock')
 I.shot='order';I.time=1.9;I.age=.5;I.log[#I.log+1]={shot='order',t=1.4}
end)
V.atFrame(28,function()
 Shot('comic-order');V.assert(page.comicStates.prosper.age==1.9 and math.abs(page.comicStates.order.age-.5)<.001,'city retains 1.9 seconds while order is 0.5 seconds')
 I.shot='leave';I.time=3.2;I.age=.5;I.log[#I.log+1]={shot='leave',t=2.7}
end)
V.atFrame(31,function()
 Shot('comic-leave');V.assert(page.comicStates.prosper.age==3.2 and math.abs(page.comicStates.leave.age-.5)<.001,'three accumulated panels keep independent clocks')
 I.shot='no';I.time=3.9;I.age=.5;I.log[#I.log+1]={shot='no',t=3.4}
end)
V.atFrame(34,function()
 V.assert(page.comicStates.prosper.age==3.4,'laser freezes prior drift exactly at no entry')
 I.stage='reality';I.shot='comms';I.age=1;I.time=1;I.line='v01';I.face='smile';I.lineAge=4;I.voiceDuration=3;I.finishedTyping=true;I.choosing=true;I.chooseAge=1
end)
V.atFrame(38,function()
 Shot('dialog-choices')
 local snap=page:Snapshot();V.assert(snap.choosing and #snap.buttons==3,'actual three original choices expose pointer rects')
 V.assert(page.dialogRect.w>0 and page.dialogRect.h>0,'actual dynamic dialog layout recorded')
 local b=snap.buttons[2];page:OnPointerDown({x=b.x+b.w/2,y=b.y+b.h/2,pointerId=91,pointerType='mouse'})
 V.assert(I.choice==2,'actual second UI pointer calls real IntroSession Choose')
 I.choosing=false
end)
V.atFrame(41,function()
 Shot('dialog-chosen');V.assert(#page.buttons==0,'choices disappear after selection state ends')
 page=nil;I:Dispose();V.finish()
end)
