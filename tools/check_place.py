#!/usr/bin/env python3
"""Check the actual native place produced by Rojo, not just Lua source syntax."""
import argparse
import pathlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]

def prop(item, kind, key):
    return item.find(f'./Properties/{kind}[@name="{key}"]')

def name(item):
    value = prop(item, 'string', 'Name')
    return value.text if value is not None else ''

def child(parent, key):
    item = next((i for i in parent.findall('Item') if name(i) == key), None)
    assert item is not None, f'Missing native instance: {key}'
    return item

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rojo', required=True)
    a = parser.parse_args()
    with tempfile.TemporaryDirectory() as d:
        path = pathlib.Path(d) / 'place.rbxlx'
        subprocess.run([a.rojo, 'build', str(ROOT / 'default.project.json'), '-o', str(path)], check=True)
        root = ET.parse(path).getroot()
    workspace = child(root, 'Workspace')
    world = child(workspace, 'Archipelago')
    parts = list(world.iterfind('.//Item[@class="Part"]')) + list(world.iterfind('.//Item[@class="SpawnLocation"]'))
    assert len(parts) > 800, 'The map must exist before any script is run'
    for part in parts:
        size = prop(part, 'Vector3', 'size')
        assert size is not None, name(part)
        assert all(.001 <= float(size.find(axis).text) <= 2048 for axis in 'XYZ'), name(part)
    sea = [p for p in parts if name(p) == 'Mer']
    assert len(sea) == 9 and all(prop(p, 'bool', 'CanCollide').text == 'false' for p in sea)
    for key in ['Port', 'Jungle', 'Fort', 'Storm']:
        island = child(world, key)
        child(island, 'Plateau')
        spawn = child(island, key + 'Spawn')
        assert spawn.get('class') == 'SpawnLocation'
        enabled = prop(spawn, 'bool', 'Enabled')
        assert (enabled is None or enabled.text == 'true') == (key == 'Port')
        child(child(island, 'Ivo · passeur'), 'Torso')
    prompts = list(world.iterfind('.//Item[@class="ProximityPrompt"]'))
    assert len(prompts) == 10, 'All quest, travel and training/fruit interactions must exist'
    version = re.search(r'Config.Version = "([^"]+)"', (ROOT / 'src/shared/Config.lua').read_text()).group(1)
    assert prop(child(world, 'WorldVersion'), 'string', 'Value').text == version, 'Rebake the map after a version change'
    refs = {i.get('referent') for i in world.iter('Item')}
    for reference in world.iter('Ref'):
        assert reference.text == 'null' or reference.text in refs, 'Broken model/label reference'
    checks = [
        (child(child(root, 'ReplicatedFirst'), 'Boot'), 'LocalScript', 'src/first/Boot.client.lua'),
        (child(child(root, 'ServerScriptService'), 'CombatServer'), 'Script', 'src/server/CombatServer.server.lua'),
        (child(child(child(root, 'StarterPlayer'), 'StarterPlayerScripts'), 'Game'), 'LocalScript', 'src/client/Game.client.lua'),
    ]
    shared = child(child(root, 'ReplicatedStorage'), 'ArchipelagoShared')
    for module in ['Config', 'Rules']:
        checks.append((child(shared, module), 'ModuleScript', f'src/shared/{module}.lua'))
    services = child(child(root, 'ServerScriptService'), 'Services')
    for source in sorted((ROOT / 'src/server/Services').glob('*.lua')):
        checks.append((child(services, source.stem), 'ModuleScript', str(source.relative_to(ROOT))))
    clients = child(child(root, 'StarterPlayer'), 'StarterPlayerScripts')
    for label, cls, source in [('Combat', 'LocalScript', 'Combat.client.lua'),
                               ('Movement', 'LocalScript', 'Movement.client.lua'),
                               ('UI', 'ModuleScript', 'UI.lua')]:
        checks.append((child(clients, label), cls, 'src/client/' + source))
    for node, cls, source in checks:
        assert node.get('class') == cls
        text = node.find('./Properties/*[@name="Source"]')
        assert text is not None and text.text == (ROOT / source).read_text(), source
    print(f'PASS native Rojo place: {len(parts)} parts, 4 islands, 4 spawns, 10 prompts, valid references and {len(checks)} exact script/module sources')

if __name__ == '__main__': main()
