local Feedback=require 'controls.CameraFeedback'
local Coord=require 'core.Coord'
local function Near(a,b,tolerance) return math.abs(a-b)<(tolerance or 1e-6) end
local function Vec(v,a) return Near(-v.x,a[1],1e-4) and Near(v.y,a[2],1e-4) and Near(v.z,a[3],1e-4) end
V.atFrame(46,function()
    local file=assert(io.open('.tmp/source-camera-feedback.json'));local fixtures=cjson.decode(file:read('*a'));file:close()
    local scene=Scene();local node=scene:CreateChild('FeedbackCamera')
    for _,scenario in ipairs(fixtures.scenarios) do
        local state={};local feedback=Feedback.New(state)
        for index,f in ipairs(scenario.frames) do
            node.position=Coord.Vec(table.unpack(f.base.pos))
            node.rotation=Quaternion(Coord.Vec(table.unpack(f.base.right)),Coord.Vec(table.unpack(f.base.up)),Coord.Vec(table.unpack(f.base.forward)))
            state.stompV=state.stompV+f.impulse
            for _,e in ipairs(f.events) do feedback:Queue(e,false) end
            feedback:Flush({0,2,0})
            local vehicle={speed=f.speed}
            if scenario.kind=='mech' or scenario.kind=='mixed' then vehicle.mechControl={footfalls=f.footfalls,standAvg=8.5} end
            feedback:Apply(f.dt,node,vehicle)
            local same=true
            for key,value in pairs(f.expected.state) do same=same and Near(state[key],value) end
            V.assert(same,'frozen feedback state '..scenario.kind..'/'..index)
            V.assert(Vec(node.position,f.expected.pos),'actual feedback camera position '..scenario.kind..'/'..index)
            V.assert(Vec(node.rotation*Vector3.RIGHT,f.expected.right) and Vec(node.rotation*Vector3.UP,f.expected.up)
                and Vec(node.rotation*Vector3.FORWARD,f.expected.forward),'actual feedback orientation '..scenario.kind..'/'..index)
        end
    end
    local state={};local feedback=Feedback.New(state)
    feedback:Event({type='shot',kind='sniper',kick=1,shake=1},true,{0,0,0})
    feedback:Event({type='shot',kind='mg',spin=1},true,{0,0,0})
    V.assert(state.trauma==0 and state.rumbleTo==0,'remote enemy shots do not punch the player camera')
    scene:Dispose();V.finish()
end)
