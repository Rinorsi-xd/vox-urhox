local Session=require 'intro.IntroSession'
local data=Session.Data()
V.atFrame(2,function()
 local shots=require('intro.IntroShots');local calls=0
 local raised,lift=shots.SafeCamera({10,2,0},{0,2,0},function(_,direction,length)
  calls=calls+1;return direction[2]<.1 and {dist=length-2} or nil
 end,0)
 V.assert(lift==1.5 and raised[2]==3.5 and calls==4,'source cinematic obstacle raise clears static wall in half metre steps')
 local capped,cap=shots.SafeCamera({10,2,0},{0,2,0},function()return {dist=1} end,0)
 V.assert(cap==10 and capped[2]==12,'source blocked camera raise is capped at ten metres')
 local relaxed,remaining=shots.SafeCamera({10,2,0},{0,2,0},function()return nil end,1.5)
 V.assert(math.abs(remaining-1.35)<.00001 and math.abs(relaxed[2]-3.35)<.00001,'source cinematic camera lift recovers 0.15 metres per frame')
 local actor,actorLift=shots.SafeCamera({10,2,0},{0,2,0},function()return {dist=1,owner={ref={}}} end,0)
 V.assert(actorLift==0 and actor[2]==2,'source actor hit does not lift cinematic camera')
 V.assert(data.commit=='2b169a9964645f5f346a7158bcb14447f040814a','opening uses frozen October 14 commit')
 V.assert(#data.actors.invaders==7 and #data.galaxy.stars==2600 and #data.galaxy.hits==200,'source real actor roster and deterministic galaxy exported')
 V.assert(data.lines.v01=='好了新人，催泪广告看完了？' and data.lines.v13=='这么急着上前线？我喜欢你的<em>工贼精神</em>。','original dialogue includes skip reaction')
 local natural=Session.New({},{});natural.active=true;natural.line='v01';natural.lineAge=0;natural.typing=2.6;natural.voiceDuration=2.66
 natural:Update(.1,true);V.assert(natural.typedCount>=0 and natural.lineAge==.1,'untagged natural v01 counts Unicode without gsub second return leaking to utf8.len')
 natural.line='v13';natural:Update(.1,true);V.assert(natural.typedCount>=0,'tagged skipped dialogue remains valid');natural.audio:Dispose();natural.page:Destroy()
 local paths=Session.Dependencies();V.assert(#paths==70,'55 sounds 14 images and data are all declared dependencies')
 local I=Session.New({},{});I.shot='contract';local saved={}
 I.host.SaveProfile=function(name,at) saved={name=name,at=at};return true end
 V.assert(not I:Submit('') and I.error=='代号不能为空。','empty callsign rejected')
 V.assert(not I:Submit('一二三四五六七八九十甲') and I.error=='代号最多 10 个字。','Unicode callsign length measured in codepoints')
 V.assert(not I:Submit('诺诺新兵') and not I:Submit('NoNo'),'source reserved callsign prefix and case insensitive alias rejected')
 V.assert(not I:Submit('新人') and I.error=='请先在签名框里签一笔。','name alone cannot bypass signature')
 I.ink=29.9;V.assert(not I:Submit('新人'),'source 30 logical pixel ink threshold kept')
 I.ink=30;V.assert(I:Submit('  机修师7  ') and I.name=='机修师7' and saved.name=='机修师7','trim callsign and persist exact signed name')
 local bad=Session.New({},{SaveProfile=function()return false,'test storage failure' end});bad.shot='contract';bad.ink=35
 V.assert(not bad:Submit('新人') and not bad.signed and bad.error=='test storage failure','failed persistent write blocks completion')
 local long=Session.New({},{SaveProfile=function()return true end});long.shot='contract';long.ink=801;long.active=true
 V.assert(long:Submit('认真机修师') and not long.signed and long.error=='签得很认真。没用的。','source large signature displays authored note')
 long:Update(1.19,true);V.assert(not long.signed,'signature note holds before source 1.2 second deadline')
 long:Update(.02,true);V.assert(long.signed and long.name=='认真机修师','source large signature completes after note hold');long.audio:Dispose();long.page:Destroy()
 I.active=true;I.stage='reality';V.assert(not I:Skip(),'source skip only applies to advertisement')
 I.stage='ad';V.assert(I:Skip() and I.skipRequested,'advertisement skip enters authored reality route')
 local S=require('intro.IntroSortie').New(I);local state={controlling=false,pos={62,1,-176},playerAlive=true};I.host.SortieStatus=function()return state end
 S:Update(100);V.assert(S.step==0 and S.elapsed==0,'unlocked player never ages guided battle clock')
 state.controlling=true;S:Update(.1);V.assert(S.step==1,'capture begins manual drive lesson')
 state.pos={62,1,-157};S:Update(.1);V.assert(S.step==1 and S.pending==2,'real displacement beyond 18 meters starts source success hold');S:Update(.5);V.assert(S.step==2,'source half second success hold advances to weapons')
 state.controlling=false;S:Update(20);V.assert(S.step==2 and S.elapsed==0,'release pauses weapons wait and reinforcements clock')
 state.controlling=true;state.enemyHit=true;S:Update(.1);V.assert(S.pending==3 and S.mine,'real ten percent enemy damage satisfies first kill');S:Update(.5)
 S:Update(10);V.assert(S.step==4 and S.reason=='被「援军」误伤','source ally misidentification happens after ten active seconds')
 S:Update(2.05);V.assert(S.step==5,'source beam reaches destruction stage')
 S:Update(.89);V.assert(not S.stamped,'wreck capture and stamp wait original 0.9 seconds')
 S:Update(.02);V.assert(S.stamped,'wreck snapshot precedes original stamp')
 S:Update(2.4);V.assert(S.done and I.wrecked,'destruction stamp finishes live sortie')
 I.audio:Dispose();bad.audio:Dispose();I.page:Destroy();bad.page:Destroy()
 local sounds=require('audio.IntroAudio').New(data);local prepared=false
 for _=1,55 do local done,err=sounds:PrepareNext();V.assert(not err,'original audio decodes one retained resource at a time');prepared=done end
 V.assert(prepared and sounds.prepared==55,'all original narration music and effects decode')
 V.assert(math.abs(sounds:Duration('vo_n01')-data.durations.vo_n01)<.03,'real decoded duration matches authored speech clock')
 sounds:Voice('vo_v01');local source=sounds.voice;local before=source.sound;sounds:Update(.1,true)
 V.assert(source==sounds.voice and source.sound==before,'UI tick retains voice source and buffer')
 sounds:Dispose();V.finish()
end)
