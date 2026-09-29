-- Geometry-only host for running the actual world builder outside Studio.
-- No physics/replication emulation. Used for floor assertions and an offline QA render.
local Vector3 = {}
local vmt = {}
function Vector3.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vmt) end
function vmt.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vmt.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vmt.__mul(a,b)
 if type(a)=='number' then a,b=b,a end
 return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
function vmt.__div(a,b) return a*(1/b) end
function vmt.__unm(a) return a*-1 end
function vmt.__index(a,key)
 if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
 elseif key=='Unit' then return a/a.Magnitude
 elseif key=='Dot' then return function(b,c) return b.X*c.X+b.Y*c.Y+b.Z*c.Z end
 elseif key=='Cross' then return function(b,c) return Vector3.new(b.Y*c.Z-b.Z*c.Y,b.Z*c.X-b.X*c.Z,b.X*c.Y-b.Y*c.X) end end
end
Vector3.zero,Vector3.one=Vector3.new(),Vector3.new(1,1,1)
local function identity() return {1,0,0,0,1,0,0,0,1} end
local function mm(a,b)
 local r={}
 for i=0,2 do for j=1,3 do r[i*3+j]=0;for k=1,3 do r[i*3+j]+=a[i*3+k]*b[(k-1)*3+j] end end end
 return r
end
local function mv(r,v) return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end
local CFrame = {}
local cmt = {}
function CFrame.new(x,y,z)
 local pos=type(x)=='table' and x or Vector3.new(x,y,z)
 return setmetatable({Position=pos,R=identity()},cmt)
end
function cmt.__mul(a,b)
 if b.R then return setmetatable({Position=a.Position+mv(a.R,b.Position),R=mm(a.R,b.R)},cmt) end
 return a.Position+mv(a.R,b)
end
function cmt.__index(a,key)
 if key=='PointToWorldSpace' then return function(b,v) return b*v end
 elseif key=='LookVector' then return Vector3.new(-a.R[3],-a.R[6],-a.R[9]) end
end
function CFrame.Angles(x,y,z)
 local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
 local c=CFrame.new();c.R=mm(mm({1,0,0,0,cx,-sx,0,sx,cx},{cy,0,sy,0,1,0,-sy,0,cy}),{cz,-sz,0,sz,cz,0,0,0,1});return c
end
function CFrame.lookAt(from,to)
 local f=(to-from).Unit
 local up=math.abs(f.Y)>0.99 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
 local right=f:Cross(up).Unit;up=right:Cross(f)
 local c=CFrame.new(from);c.R={right.X,up.X,-f.X,right.Y,up.Y,-f.Y,right.Z,up.Z,-f.Z};return c
end
local colorMT = {__index={Lerp=function(a,b,t) return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t} end}}
local Color3={fromRGB=function(r,g,b) return setmetatable({r,g,b},colorMT) end,new=function(r,g,b) return setmetatable({r*255,g*255,b*255},colorMT) end}
local Enum=setmetatable({}, {__index=function(_,category) return setmetatable({}, {__index=function(_,name)return category..'.'..name end}) end})
local Vector2={new=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local allParts={}
local Instance={}
local methods={}
local imt={}
function imt.__index(self,key)
 if methods[key] then return methods[key] end
 if key=='Position' and self._props.CFrame then return self._props.CFrame.Position end
 return self._props[key]
end
function imt.__newindex(self,key,value)
 self._props[key]=value
 if key=='Parent' and value then table.insert(value._children,self) end
end
function Instance.new(class,parent)
 local o=setmetatable({_props={ClassName=class,CanCollide=true,Transparency=0,Shape='PartType.Block',Name=class},_children={},_attributes={}},imt)
 if class=='Part' or class=='WedgePart' or class=='SpawnLocation' then table.insert(allParts,o) end
 if parent then o.Parent=parent end
 return o
end
function methods:IsA(class) return self.ClassName==class or (class=='BasePart' and (self.ClassName=='Part' or self.ClassName=='WedgePart' or self.ClassName=='SpawnLocation')) end
function methods:FindFirstChild(name) for _,o in ipairs(self._children) do if o.Name==name then return o end end end
function methods:GetChildren() return self._children end
function methods:SetAttribute(key,value) self._attributes[key]=value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:Destroy() self._props.Parent=nil end
local Random={}
function Random.new(seed)
 local r={seed=seed}
 function r:NextNumber(low,high) self.seed=(self.seed*48271)%2147483647;return low+(high-low)*(self.seed/2147483647) end
 return r
end
local task={wait=function()end}
local workspace=Instance.new('Workspace')
local lighting=Instance.new('Lighting')
local game={GetService=function(_,name) return name=='Lighting' and lighting or {} end}
