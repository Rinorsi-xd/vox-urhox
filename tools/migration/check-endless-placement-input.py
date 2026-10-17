import json
import hashlib
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path('.tmp/nav-python-deps').resolve()))
from lupa.lua54 import LuaRuntime

root = pathlib.Path.cwd()
report = json.loads((root / 'docs/migration/evidence/endless-stock-web-0bae-d/report.json').read_text(encoding='utf8'))
entered = next(item['state'] for item in report['states'] if item['label'] == 'editor entered')
lua = LuaRuntime(unpack_returned_tuples=True)
resource_reads = {}

def table(value):
    if isinstance(value, dict):
        return lua.table_from({key: table(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(item) for item in value])
    return value

def resource(name):
    content = (root / 'assets' / name).read_bytes()
    resource_reads[name] = hashlib.sha256(content).hexdigest()
    return table(json.loads(content.decode('utf8')))

lua.globals().ReadResource = resource
lua.globals().fixture = table(entered)
observer = (root / 'tools/migration/endless-edit-stock-web-observer.lua').read_text(encoding='utf8')
helper = observer.split('local function CandidatePlacement(', 1)[1].split('local function Candidates(', 1)[0]
lua.execute("package.path='scripts/?.lua;'..package.path;package.loaded['core.ResourceData']={Read=ReadResource};cjson={null={}};Placement=require'construction.Placement'")
lua.execute('local function CandidatePlacement(' + helper + '\nQAPlacement={Candidate=CandidatePlacement,Rank=RankCandidates}')
build_session = (root / 'scripts/app/BuildSession.lua').read_text(encoding='utf8')
keys_source = build_session.split('function M:Keys()', 1)[1].split('\nfunction M:Update(', 1)[0]
for key in set(re.findall(r'\bKEY_[A-Z0-9_]+\b', keys_source)):
    lua.globals()[key] = key
lua.execute("package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1600,900 end,GetFocus=function()return QAFocus end}")
lua.execute("local M={};local UI=require('urhox-libs/UI');function M:Keys()" + keys_source + '\nQAKeys=M.Keys')
audit_source = observer.split('local keyAudits=', 1)[1].split('local function Snapshot()', 1)[0]
lua.execute("local UI=require('urhox-libs/UI');local keyAudits=" + audit_source + '\nQAKeyAudit=AuditKeys')
lua.execute('''
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=ReadResource}
package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1600,900 end,GetFocus=function()return QAFocus end}
cjson={null={}}
local BP=require'construction.Blueprint';local Editor=require'construction.BuildEditor'
local Ray=require'construction.GridRay';local Config=require'Config'
local Controls=require'controls.BuildInput';local Inv=require'endless.Inventory'
local bp=BP.New():Load(fixture.blueprint);local e=Editor.New(bp);e.mirror=false
local eye={6,12,7};local direction={0,-1,0}
local function Candidates(kind)
 e:SelectType(kind);local count,legal,reasons=0,0,{};local candidates,all={},{}
for _,part in ipairs(bp:List())do for _,cell in ipairs(part._cells)do
 for _,n in ipairs({{0,1,0},{1,0,0},{-1,0,0},{0,0,1},{0,0,-1}})do
  if not bp.cellIds[BP.Key(cell[1]+n[1],cell[2]+n[2],cell[3]+n[3])]then
   local at={(cell[1]+n[1]*.499)*Config.CELL,(cell[2]+.5+n[2]*.499)*Config.CELL,(cell[3]+n[3]*.499)*Config.CELL}
   local dx,dy,dz=at[1]-eye[1],at[2]-eye[2],at[3]-eye[3];local length=math.sqrt(dx*dx+dy*dy+dz*dz)
   local ray={dx/length,dy/length,dz/length};local hit=Ray.Cast(eye,ray,bp,160,false)
   if hit.hit and hit.partId==part.id then
    count=count+1;e.forward={ray[1],0,ray[3]}
    local oldHit,oldPreview=e.hit,e.preview;local predicted=QAPlacement.Candidate(e,hit,e.forward)
    assert(e.hit==oldHit and e.preview==oldPreview,'Observer must not mutate actual editor hit or preview')
    local p=e:Trace(eye,ray);assert(predicted.ok==(p and p.res.ok),'Read-only candidate legality must match actual preview')
    assert(predicted.rot==p.rot and table.concat(predicted.pos,',')==table.concat(p.pos,','),'Read-only candidate position/rotation must match actual preview')
    local candidate={part=part.id,type=part.type,cell=cell,normal=hit.normal,place=p.pos,rotation=p.rot,ordinal=count,ray=ray,legal=predicted.ok};all[#all+1]=candidate
    if p and p.res.ok then legal=legal+1;candidates[#candidates+1]=candidate
    else local r=p and p.res.reason or 'no preview';reasons[r]=(reasons[r]or 0)+1 end
   end
  end
 end
end end
 local ranked=QAPlacement.Rank(all);local retained={};for _,candidate in ipairs(ranked)do if candidate.legal then retained[#retained+1]=candidate end end
 assert(#ranked<=100 and #retained==math.min(100,legal),'Rank actual legality before bounded output')
 return retained,{visible=count,legal=legal,reasons=reasons}
end
MOUSEB_LEFT=1;MOUSEB_RIGHT=2;MOUSEB_MIDDLE=3;KEY_SHIFT=4;KEY_CTRL=5
local down,pressed=false,false;local button=MOUSEB_LEFT;local heldKeys,pressedKeys={},{}
input={GetKeyDown=function(_,key)return heldKeys[key]or false end,GetKeyPress=function(_,key)return pressedKeys[key]or false end,GetMouseButtonDown=function(_,b)return b==button and down end,
 GetMouseButtonPress=function(_,b)return b==button and pressed end}
local acts=0
local session={editor=e,hud={playfield={}},buildCamera={mode='fp',captured=true,buttonsReady=true,touch=false}}
session.Keys=QAKeys
function session:Trace()e.forward={direction[1],0,direction[3]};return e:Trace(eye,direction)end
function session:Act()acts=acts+1;return e:Act()end
local controls=Controls.New(session)
local function Click(candidate,kind)
 e:SelectType(kind);direction=candidate.ray;session:Trace();assert(e.preview and e.preview.res.ok,'Real preview required before pointer placement')
 local before=bp:Size();down=true;pressed=true;controls:FirstPerson(1/60);down=false;pressed=false;controls:FirstPerson(1/60)
 assert(bp:Size()==before+1,'Actual FirstPerson input must install exactly one part')
 return bp:List()[#bp:List()]
end
local direct,directInfo=Candidates('laser1');assert(#direct>0,'Actual starter must have legal authored ray mounts')
local foundations,foundationInfo=Candidates('cube');local foundation
for _,candidate in ipairs(foundations)do if candidate.normal[2]==1 and candidate.type=='cube'and candidate.cell[3]>=3 then foundation=candidate;break end end
assert(foundation,'Visible legal structural top face required')
local cube=Click(foundation,'cube');assert(cube.type=='cube'and (Inv.Remaining(fixture.owned,bp).laser1 or 0)==1,'Unlimited foundation must preserve laser stock')
local mount;local foundationCount=1
for level=1,4 do
 local mounted=Candidates('laser1')
 for _,candidate in ipairs(mounted)do if candidate.part==cube.id and candidate.normal[2]==1 then mount=candidate;break end end
 if mount then break end
 local more=Candidates('cube');local nextCube
 for _,candidate in ipairs(more)do if candidate.part==cube.id and candidate.normal[2]==1 then nextCube=candidate;break end end
 if not nextCube then
  local target={cube.pos[1]*Config.CELL,(cube.pos[2]+.999)*Config.CELL,cube.pos[3]*Config.CELL}
  local ray={target[1]-eye[1],target[2]-eye[2],target[3]-eye[3]};local length=math.sqrt(ray[1]^2+ray[2]^2+ray[3]^2);for i=1,3 do ray[i]=ray[i]/length end
  local pv=e:Trace(eye,ray);error('Actual foundation top must allow next structural block; cube '..cube.id..' at '..table.concat(cube.pos,',')..' hit '..tostring(e.hit and e.hit.partId)..' reason '..tostring(pv and pv.res.reason))
 end
 cube=Click(nextCube,'cube');foundationCount=foundationCount+1
end
assert(mount,'Laser must legally mount on the actual placed foundation top')
local laser=Click(mount,'laser1');assert(laser.type=='laser1'and Inv.Remaining(fixture.owned,bp).laser1==0,'Actual pointer placement exhausts spare laser')
assert(mount.ordinal>100,'Actual foundation mount demonstrates why old early cap loses it')
local ui=package.loaded['urhox-libs/UI'];ui.GetFocus=function()return QAFocus end
local keyAudit=QAKeyAudit(session)
heldKeys[KEY_CTRL]=true;pressedKeys[KEY_Z]=true;session.buildCamera.captured=false
QAFocus={OnTextInput=function()end};session:Keys()
assert(bp:Size()==80 and #e.history.undoStack==2 and #e.history.redoStack==0,'Actual Keys must not undo while a text field owns focus')
QAFocus=nil;session:Keys()
assert(bp:Size()==79 and #e.history.undoStack==1 and #e.history.redoStack==1 and Inv.Remaining(fixture.owned,bp).laser1==1,'Actual BuildSession.Keys Ctrl+Z restores laser stock even without pointer capture')
pressedKeys[KEY_Z]=nil;pressedKeys[KEY_Y]=true;session:Keys()
assert(bp:Size()==80 and #e.history.undoStack==2 and #e.history.redoStack==0 and Inv.Remaining(fixture.owned,bp).laser1==0,'Actual BuildSession.Keys Ctrl+Y consumes laser stock')
assert(#keyAudit.attempts==3 and keyAudit.attempts[1].focus.textInput and keyAudit.attempts[1].before.parts==80 and keyAudit.attempts[1].after.parts==80,'Observer records actual text-focus rejection without changing history')
assert(keyAudit.attempts[2].ctrl and keyAudit.attempts[2].z and not keyAudit.attempts[2].focus.captured and keyAudit.attempts[2].after.parts==79,'Observer records actual uncaptured Ctrl+Z dispatch and result')
assert(keyAudit.attempts[3].ctrl and keyAudit.attempts[3].y and keyAudit.attempts[3].after.parts==80,'Observer records actual Ctrl+Y dispatch and result')
heldKeys[KEY_CTRL]=nil;pressedKeys[KEY_Y]=nil;session.buildCamera.captured=true
session:Trace();assert(e.hit.partId==laser.id,'Actual same-face ray must hit the installed laser for removal')
button=MOUSEB_RIGHT;down=true;pressed=true;controls:FirstPerson(1/60);down=false;pressed=false;controls:FirstPerson(1/60)
assert(bp:Size()==79 and Inv.Remaining(fixture.owned,bp).laser1==1,'Actual right-button removal returns limited inventory')
exploration={status='PASS',initialParts=#fixture.blueprint.parts,eye=eye,direct=directInfo,foundation=foundation,foundationCount=foundationCount,laserMount=mount,finalParts=bp:Size(),placementActions=acts,rightRemoval=true,stockSequence={1,1,0,1,0,1},history={undo=#e.history.undoStack,redo=#e.history.redoStack},historyKeys={actualBuildSessionKeys=true,textFocusRejected=true,uncapturedUndoWorks=true,ctrlYRedoWorks=true},
 boundary='Actual failed-d starter blueprint/resources plus actual GridRay, BuildEditor, BuildInput.FirstPerson and EditHistory. Camera/input/UI service adapters; selected types mapped to actual SelectType. No Runtime, actual browser pointer or performance acceptance.'}
''')

def plain(value):
    if hasattr(value, 'items'):
        values = dict(value.items())
        if values and set(values) == set(range(1, len(values) + 1)):
            return [plain(values[index]) for index in range(1, len(values) + 1)]
        return {key: plain(item) for key, item in values.items()}
    return value

result = plain(lua.globals().exploration)
result['resourcesSha256'] = resource_reads
result['scriptsSha256'] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in [
    'scripts/construction/BuildEditor.lua', 'scripts/construction/GridRay.lua',
    'scripts/construction/Placement.lua', 'scripts/construction/EditHistory.lua',
    'scripts/controls/BuildInput.lua', 'scripts/endless/Inventory.lua',
    'scripts/app/BuildSession.lua',
    'tools/migration/endless-edit-stock-web-observer.lua']}
result['fixtureReportSha256'] = hashlib.sha256((root / 'docs/migration/evidence/endless-stock-web-0bae-d/report.json').read_bytes()).hexdigest()
text = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
if len(sys.argv) > 1:
    with pathlib.Path(sys.argv[1]).open('x', encoding='utf8') as output:
        output.write(text)
else:
    print(text)
