#!/usr/bin/env python3
"""Bake WorldService into a native model so Rojo shows the map BEFORE Play.
The geometry host is not Roblox Studio. Rojo validates/encodes the instance tree.
Usage: python tools/bake_world.py --luau /path/luau --rojo /path/rojo
"""
import argparse
import json
import pathlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
# Numeric values from Roblox's official creator-docs/reference/engine/enums.
ENUMS = {
    'Material': {'SmoothPlastic': 272, 'Neon': 288, 'Wood': 512, 'WoodPlanks': 528,
                 'Slate': 800, 'Brick': 848, 'Pebble': 864, 'Cobblestone': 880,
                 'Rock': 896, 'Metal': 1088, 'Grass': 1280, 'Sand': 1296,
                 'Fabric': 1312, 'Glass': 1568, 'Plaster': 2310},
    'SurfaceType': {'Smooth': 0}, 'PartType': {'Ball': 0, 'Block': 1, 'Cylinder': 2},
    'Font': {'GothamBold': 19}, 'KeyCode': {'E': 101},
}
COLOR = {'Color', 'TextColor3'}
BOOL = {'Anchored', 'CanCollide', 'CanTouch', 'CanQuery', 'AlwaysOnTop',
        'RequiresLineOfSight', 'Neutral', 'Enabled'}
FLOAT = {'Transparency', 'Reflectance', 'MaxDistance', 'BackgroundTransparency',
         'TextStrokeTransparency', 'TextSize', 'MaxActivationDistance', 'HoldDuration',
         'Range', 'Brightness'}
STRINGS = {'Name', 'Text', 'ActionText', 'ObjectText', 'Value'}

def element(parent, tag, name=None, text=None):
    e = ET.SubElement(parent, tag, {'name': name} if name else {})
    if text is not None:
        e.text = str(text)
    return e

def serialize(parent, obj):
    cls = obj['ClassName']
    assert cls in {'Folder', 'Model', 'Part', 'SpawnLocation', 'BillboardGui',
                   'TextLabel', 'PointLight', 'ProximityPrompt', 'StringValue'}, cls
    node = ET.SubElement(parent, 'Item', {'class': cls, 'referent': obj['Ref']})
    props = element(node, 'Properties')
    for key, value in sorted(obj['Properties'].items()):
        if isinstance(value, dict) and 'Ref' in value:
            element(props, 'Ref', key, value['Ref'])
        elif key == 'CFrame':
            cf = element(props, 'CoordinateFrame', key)
            for field, n in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'], value):
                element(cf, field, text=n)
        elif (key == 'Size' and cls in {'Part', 'SpawnLocation'}) or key == 'StudsOffsetWorldSpace':
            if key == 'Size':
                assert all(.001 <= n <= 2048 for n in value), (obj['Properties'].get('Name'), value)
            vector = element(props, 'Vector3', 'size' if key == 'Size' else key)
            for axis, n in zip('XYZ', value): element(vector, axis, text=n)
        elif key == 'Size':
            dim = element(props, 'UDim2', key)
            for field, n in zip(['XS','XO','YS','YO'], value): element(dim, field, text=n)
        elif key in COLOR:
            color = element(props, 'Color3', key)
            for axis, n in zip('RGB', value): element(color, axis, text=n / 255)
        elif key in BOOL:
            element(props, 'bool', key, str(value).lower())
        elif key == 'Duration' and cls == 'SpawnLocation':
            element(props, 'int', key, int(value))
        elif key in FLOAT:
            element(props, 'float', key, value)
        elif key in STRINGS:
            element(props, 'string', key, value)
        elif isinstance(value, str) and '.' in value:
            enum, member = value.split('.', 1)
            element(props, 'token', key, ENUMS[enum][member])
        else:
            raise ValueError(f'Unmapped model property {cls}.{key}: {value}')
    for child in obj['Children']: serialize(node, child)
    return node

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--luau', required=True)
    p.add_argument('--rojo', required=True)
    p.add_argument('--out', default=str(ROOT / 'world/Archipelago.rbxm'))
    a = p.parse_args()
    source = (ROOT / 'tests/world_harness.luau').read_text()
    for name, path in [('Config','src/shared/Config.lua'), ('B','src/server/Services/Builders.lua'), ('World','src/server/Services/WorldService.lua')]:
        s = (ROOT / path).read_text()
        if name == 'World':
            s = s.replace('local Config = require(ReplicatedStorage.Shared.Config)', '').replace('local B = require(script.Parent.Builders)', '')
        source += '\nlocal ' + name + ' = (function()\n' + s + '\nend)()\n'
    source += '\nWorld.build()\n' + (ROOT / 'tests/export_world.luau').read_text()
    output = pathlib.Path(a.out).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        (d / 'bake.luau').write_text(source)
        result = subprocess.run([a.luau, str(d / 'bake.luau')], check=True, capture_output=True, text=True)
        tree = json.loads(result.stdout)
        xml = ET.Element('roblox', {'version': '4'})
        serialize(xml, tree)
        ET.ElementTree(xml).write(d / 'map.rbxmx', encoding='utf-8', xml_declaration=True)
        project = {'name': 'archipelago-model', 'tree': {'$path': 'map.rbxmx'}}
        (d / 'default.project.json').write_text(json.dumps(project))
        subprocess.run([a.rojo, 'build', str(d / 'default.project.json'), '-o', str(output)], check=True)
    print(f'Baked editable map: {output} ({output.stat().st_size} bytes)')

if __name__ == '__main__': main()
