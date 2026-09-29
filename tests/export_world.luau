-- Emit the generated instance tree for the native Rojo model exporter.
local function quote(s)
	return '"' .. s:gsub('[%z\1-\31\\"]', function(c) return string.format('\\u%04x', string.byte(c)) end) .. '"'
end
local function encode(v)
	local kind = type(v)
	if kind == "string" then return quote(v) end
	if kind == "number" then assert(v == v and math.abs(v) < math.huge); return string.format("%.12g", v) end
	if kind == "boolean" then return tostring(v) end
	if v == nil then return "null" end
	if v.R then return encode({v.Position.X,v.Position.Y,v.Position.Z,table.unpack(v.R)}) end
	if v.X then return encode({v.X,v.Y,v.Z}) end
	local items = {}
	if #v > 0 then
		for _, x in ipairs(v) do table.insert(items, encode(x)) end
		return '[' .. table.concat(items, ',') .. ']'
	end
	for key, value in pairs(v) do table.insert(items, quote(key) .. ':' .. encode(value)) end
	table.sort(items)
	return '{' .. table.concat(items, ',') .. '}'
end
local ids, instances = {}, {}
local function visit(instance)
	ids[instance] = "RBX" .. (#instances + 1)
	table.insert(instances, instance)
	for _, sub in ipairs(instance:GetChildren()) do visit(sub) end
end
visit(World.Folder)
local count = #allParts
World.build() -- Exercise the existing-model path. It must not append or recreate geometry.
assert(#allParts == count, "binding a baked map must not rebuild it")
assert(#World.Markers == 24, "binding must restore enemy markers")
local function export(instance)
	local props, children = {}, {}
	for key, value in pairs(instance._props) do
		if key ~= "Parent" and key ~= "ClassName" then
			if type(value) == "table" and value._props then
				assert(ids[value], "reference must belong to exported model")
				props[key] = {Ref = ids[value]}
			else props[key] = value end
		end
	end
	for _, sub in ipairs(instance:GetChildren()) do table.insert(children, export(sub)) end
	return {ClassName = instance.ClassName, Ref = ids[instance], Properties = props, Children = children}
end
print(encode(export(World.Folder)))
