"""Validate the unsigned device IPA before publishing it for SideStore."""
import pathlib
import plistlib
import struct
import sys
import zipfile

path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(path) as ipa:
    assert ipa.testzip() is None, 'ZIP CRC check failed'
    names = ipa.namelist()
    assert all(n.startswith('Payload/') for n in names), 'Unexpected ZIP root'
    apps = {n.split('/')[1] for n in names if len(n.split('/')) > 1 and n.split('/')[1]}
    assert apps == {'Moonlight.app'}, apps
    prefix = 'Payload/Moonlight.app/'
    info = plistlib.loads(ipa.read(prefix + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'com.moonlight-stream.Moonlight'
    assert info['CFBundlePackageType'] == 'APPL'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
    assert info['UIApplicationSceneManifest']['UISceneConfigurations']
    assert not any(n.endswith('embedded.mobileprovision') or '/_CodeSignature/' in n for n in names), 'Unexpected signing material'
    data = ipa.read(prefix + info['CFBundleExecutable'])
    magic, cpu = struct.unpack_from('<II', data)
    assert magic == 0xFEEDFACF and cpu == 0x0100000C, 'Executable is not thin ARM64 Mach-O'
    ncmds = struct.unpack_from('<I', data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, offset)
        assert size >= 8 and offset + size <= len(data)
        if cmd == 0x2C:
            assert struct.unpack_from('<I', data, offset + 16)[0] == 0, 'Encrypted executable'
        offset += size
    assert any('iPhone.storyboardc/' in n for n in names), 'Missing phone storyboard'
    print('PASS: ZIP, Payload, device platform, ARM64, unencrypted executable, scene manifest, resources, no signing material')
    for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'MinimumOSVersion', 'DTSDKName'):
        print(f'{key}: {info.get(key)}')
    print(f'Files: {len(names)}; IPA bytes: {path.stat().st_size}')
