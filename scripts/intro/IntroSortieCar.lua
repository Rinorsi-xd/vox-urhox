-- Keep the frozen sortieCar eligibility separate from the general test-drive spec.
local BP=require 'construction.Blueprint'
local M={}
function M.Select(source)
 local spec=require('drive.VehicleSpec').Build(BP.New():Load(source))
 if spec.ok and #spec.weapons>0 and #spec.wings==0 and (#spec.wheels>0 or #spec.legs>0 or #spec.hovers>0) then return source end
 return require('construction.Prefab').BuildRaceCar(BP.New()):ToTable()
end
return M
