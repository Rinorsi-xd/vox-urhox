-- Behavior parameters only. Geometry, transforms, lighting and material values live in XML.
return {
    authoredPoseTime=10,
    room={x=30,z0=-36,z1=36,h=32,floorY=-0.35},
    layout={
        cameraLimit={x=28.5,z0=-32.5,z1=34.5,y0=0.3,y1=30},
        holos={{id="stats"},{id="blueprint"}},
        drones={patrol={r=15,y=7,speed=0.11}},
        crane={range={-13,13}},
    },
}
