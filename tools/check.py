#!/usr/bin/env python3
"""Compile all Luau, exercise pure rules and real quest-handler code without Roblox.
Usage: python tools/check.py --luau /path/to/luau --compiler /path/to/luau-compile
This does not simulate Roblox replication, rendering, physics or DataStore APIs.
"""
import argparse, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--luau', required=True)
p.add_argument('--compiler', required=True)
a = p.parse_args()
for source in sorted((ROOT / 'src').rglob('*.lua')):
    subprocess.run([a.compiler, '--null', str(source)], check=True, stdout=subprocess.DEVNULL)
print('PASS Luau compilation')
subprocess.run([a.luau, str(ROOT / 'tests/Rules.spec.luau')], check=True)
rules = (ROOT / 'src/shared/Rules.lua').read_text()
config = (ROOT / 'src/shared/Config.lua').read_text()
service = (ROOT / 'src/server/Services/ProgressionService.lua').read_text()
service = service.replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")', '')
service = service.replace('local Config = require(ReplicatedStorage.ArchipelagoShared.Config)', '')
service = service.replace('local Rules = require(ReplicatedStorage.ArchipelagoShared.Rules)', '')
prelude = '''local mt = {}
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
function mt.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function mt.__index(a,key) if key == "Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local workspace = {GetServerTimeNow = function() return 100 end}
'''
bundle = prelude + '\nlocal Rules = (function()\n' + rules + '\nend)()\nlocal Config = (function()\n' + config + '\nend)()\nlocal Progression = (function()\n' + service + '\nend)()\n' + (ROOT / 'tests/progression_cases.luau').read_text()
with tempfile.TemporaryDirectory() as d:
    f = pathlib.Path(d) / 'progression.luau'
    f.write_text(bundle)
    subprocess.run([a.luau, str(f)], check=True)
service = (ROOT / 'src/server/Services/DataService.lua').read_text()
service = service.replace('local Config = require(ReplicatedStorage.ArchipelagoShared.Config)', '')
service = service.replace('local Rules = require(ReplicatedStorage.ArchipelagoShared.Rules)', '')
harness = (ROOT / 'tests/data_cases.luau').read_text()
bundle = ('local Rules = (function()\n' + rules + '\nend)()\n'
          'local Config = (function()\n' + config + '\nend)()\n'
          + harness.replace('-- INSERT_DATA_SERVICE', service))
with tempfile.TemporaryDirectory() as d:
    f = pathlib.Path(d) / 'data.luau'
    f.write_text(bundle)
    subprocess.run([a.luau, str(f)], check=True)
harness = (ROOT / 'tests/boot_cases.luau').read_text()
source = (ROOT / 'src/server/CombatServer.server.lua').read_text()
with tempfile.TemporaryDirectory() as d:
    f = pathlib.Path(d) / 'bootstrap.luau'
    f.write_text(harness.replace('-- INSERT_BOOTSTRAP', source))
    subprocess.run([a.luau, str(f)], check=True)
print('Checks complete. Studio multiplayer/visual tests still required.')
