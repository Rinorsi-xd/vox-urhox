package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks={}
local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local touch=false;package.loaded['controls.TouchMode']={Enabled=function()return touch end}
if PICKER_SOURCE then package.preload['story.TutorialFirstLine']=function()return assert(load(PICKER_SOURCE,'@candidate-TutorialFirstLine.lua'))()end end
local Rules=require 'story.TutorialRules';local Picker=require 'story.TutorialFirstLine'
local function clone(value)
 if type(value)~='table'then return value end
 local copy={};for key,item in pairs(value)do copy[key]=clone(item)end;return copy
end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for key,value in pairs(a)do if not same(value,b[key])then return false end end
 for key in pairs(b)do if a[key]==nil then return false end end;return true
end
local function expected(tutorial,app)
 local rules=tutorial.rules
 if tutorial.initialized then if not rules.running then return end
 else
  rules=Rules.New(tutorial.data,clone(rules.record),nil)
  if not rules:Resume({}) and not app.isValidation and not VOX_SKIP_TUTORIAL and not rules.record.done and not rules.record.skipped then rules:Start(1,nil,{})end
  if not rules.running then return end
 end
 local spec=rules:StepSpec();local lines=touch and spec.touchLines or spec.lines;local line=lines[1]
 if line[1]~='nono' and line[1]~='huhu'then return end
 local face=(line[3]or 'talk'):gsub('^'..line[1]..'_','')
 if line[1]=='nono' or face=='smug'then face='talk'end;return line[1],face
end
local scenarios=0
for _,touchValue in ipairs({false,true})do
 touch=touchValue
 for _,validation in ipairs({false,true})do for _,skip in ipairs({false,true})do
  VOX_SKIP_TUTORIAL=skip
  for _,path in ipairs({'intro','build','drive'})do
   for step=-1,#DATA.flows[path]+2 do
    local record=step==-1 and {}or {step=step,path=path};local writes=0
    local rules=Rules.New(DATA,record,function()writes=writes+1 end)
    local tutorial={data=DATA,rules=rules,initialized=false};local app={isValidation=validation}
    local beforeRecord=clone(record);local beforeRules=clone(rules);local oldRecord=rules.record
    local who,face=Picker.Pick(tutorial,app);local wantWho,wantFace=expected(tutorial,app)
    check(who==wantWho and face==wantFace,'real saved '..path..' step '..step..' follows Resume/touch/skip/validation semantics')
    check(writes==0 and rules.record==oldRecord and same(record,beforeRecord) and same(rules,beforeRules) and not tutorial.initialized,'prediction leaves live rules, record, identity, initialization and saves unchanged')
    scenarios=scenarios+1
   end
  end
  for _,record in ipairs({{done=true},{skipped=true},{step='bad'},{step=0,path='invalid'}})do
   local tutorial={data=DATA,rules=Rules.New(DATA,record,nil),initialized=false};local app={isValidation=validation}
   local who,face=Picker.Pick(tutorial,app);local a,b=expected(tutorial,app)
   check(who==a and face==b,'done/skipped and invalid saved records match real rules initialization');scenarios=scenarios+1
  end
 end end
end
VOX_SKIP_TUTORIAL=true;touch=false
for path,flow in pairs(DATA.flows)do for index=1,#flow do
 local writes=0;local rules=Rules.New(DATA,{},function()writes=writes+1 end)
 if path=='replay'then rules:Replay({})else rules:Start(index,path,{})end
 if path=='replay'then rules:Go(index,{})end
 local tutorial={data=DATA,rules=rules,initialized=true,line=2,suspended=true,lineAge=17}
 local before=clone(rules);local oldWrites=writes
 local who,face=Picker.Pick(tutorial,{isValidation=true});local a,b=expected(tutorial,{isValidation=true})
 check(who==a and face==b,'initialized running '..path..' step '..index..' chooses first resumed line despite skip/validation')
 check(same(rules,before) and writes==oldWrites and tutorial.line==2 and tutorial.lineAge==17,'live/replay prediction does not advance active line or state')
 rules.running=false;check(Picker.Pick(tutorial,{})==nil,'initialized stopped tutorial never restarts for warmup');scenarios=scenarios+1
end end
local custom=clone(DATA)
custom.steps[1].lines={{'huhu','example','huhu_angry'}};custom.steps[1].touchLines={{'huhu','touch','huhu_smug'}}
local tutorial={data=custom,rules=Rules.New(custom,{},nil),initialized=false}
VOX_SKIP_TUTORIAL=nil;touch=false;local who,face=Picker.Pick(tutorial,{})
check(who=='huhu' and face=='angry','speaker/face is data driven rather than hard-coded Nono')
touch=true;who,face=Picker.Pick(tutorial,{})
check(who=='huhu' and face=='talk','touch line and actual talking-smug substitution are honored')
custom.steps[1].touchLines={{'boss','example','chairman'}}
check(Picker.Pick(tutorial,{})==nil,'non-portrait first speaker produces no unrelated preload')
tutorial.disposed=true;check(Picker.Pick(tutorial,{})==nil,'disposed tutorial produces no preload')
tutorial.disposed=false;check(Picker.Pick(tutorial,{stopped=true})==nil,'stopped app produces no preload')
return {count=#checks,checks=checks,scenarios=scenarios}
