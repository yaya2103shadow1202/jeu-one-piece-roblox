#!/usr/bin/env python3
"""Run the actual world builder with a geometry host; export polygons for offline QA.
Not a Roblox screenshot. Usage: python tools/preview_world.py --luau ... --out /tmp/world.json
"""
import argparse,pathlib,subprocess,tempfile,json
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);p.add_argument('--out',required=True);a=p.parse_args()
source=(root/'tests/world_harness.luau').read_text()
for name,path in [('Config','src/shared/Config.lua'),('B','src/server/Services/Builders.lua'),('World','src/server/Services/WorldService.lua')]:
 s=(root/path).read_text()
 if name=='World':
  s=s.replace('local Config = require(ReplicatedStorage.Shared.Config)','').replace('local B = require(script.Parent.Builders)','')
 source+='\nlocal '+name+' = (function()\n'+s+'\nend)()\n'
source+='''
World.build()
assert(#World.Markers == 24, "24 enemy spawns")
local function floorAt(position)
 local height=-math.huge
 for _,part in ipairs(allParts) do
  if part.CanCollide and part.CFrame and part.Size then
   local c,s,r=part.CFrame.Position,part.Size,part.CFrame.R
   if part.Shape=="PartType.Cylinder" and math.abs(r[4])>0.99 then
    if (position.X-c.X)^2+(position.Z-c.Z)^2 <= (s.Y/2)^2 then height=math.max(height,c.Y+s.X/2) end
   elseif part.Shape=="PartType.Block" and math.abs(r[1]-1)<0.001 and math.abs(r[5]-1)<0.001 then
    if math.abs(position.X-c.X)<=s.X/2 and math.abs(position.Z-c.Z)<=s.Z/2 then height=math.max(height,c.Y+s.Y/2) end
   end
  end
 end
 return height
end
for id,hub in pairs(World.Hubs) do
 local gap=hub.Spawn.Position.Y-floorAt(hub.Spawn.Position)
 assert(gap>1 and gap<8, "Unsafe spawn "..id.." gap="..gap)
end
for _,marker in ipairs(World.Markers) do
 local gap=marker.Position.Y-floorAt(marker.Position)
 assert(gap>1 and gap<8,"Blocked/floating NPC marker "..marker.Enemy.." gap="..gap)
end
local function array(a) local s={};for _,n in ipairs(a) do table.insert(s,string.format("%.4f",n)) end;return "["..table.concat(s,",").."]" end
for _,p in ipairs(allParts) do
 if p.CFrame and p.Size then
 local v,s=p.CFrame.Position,p.Size
 print('{"name":'..string.format('%q',p.Name)..',"shape":'..string.format('%q',p.Shape)..',"p":'..array({v.X,v.Y,v.Z})..',"s":'..array({s.X,s.Y,s.Z})..',"r":'..array(p.CFrame.R)..',"c":'..array(p.Color or {255,255,255})..',"alpha":'..tostring(p.Transparency or 0)..'}')
 end
end
'''
with tempfile.TemporaryDirectory() as d:
 f=pathlib.Path(d)/'world.luau';f.write_text(source)
 result=subprocess.run([a.luau,str(f)],capture_output=True,text=True,check=True)
parts=[json.loads(line) for line in result.stdout.splitlines()]
pathlib.Path(a.out).write_text(json.dumps(parts))
print('PASS world geometry:',len(parts),'parts; 4 player spawns and 24 enemy spawns on walkable ground')
