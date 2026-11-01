#!/usr/bin/env python3
"""Validate both downloadable ZIP layers and the unsigned native app payload."""
import io
import plistlib
import sys
import struct
import zipfile
from pathlib import Path


def verify_ipa(data):
    with zipfile.ZipFile(io.BytesIO(data)) as ipa:
        assert ipa.testzip() is None, "IPA CRC check failed"
        info_path = "Payload/Tornadobreak.app/Info.plist"
        info = plistlib.loads(ipa.read(info_path))
        assert info["CFBundleIdentifier"] == "com.angie689.Tornadobreak"
        assert info["CFBundleShortVersionString"] == "1.0"
        assert info["CFBundlePackageType"] == "APPL"
        assert info.get("MinimumOSVersion") == "16.0"
        assert "iPhoneOS" in info.get("CFBundleSupportedPlatforms", []), "Expected a device build"
        binary_path = "Payload/Tornadobreak.app/" + info["CFBundleExecutable"]
        executable = ipa.read(binary_path)
        assert (ipa.getinfo(binary_path).external_attr >> 16) & 0o111, "App binary is not executable"
        assert len(executable) > 10000, "Missing app binary"
        assert executable[:4] == b"\xcf\xfa\xed\xfe", "Expected a 64-bit Mach-O executable"
        assert struct.unpack_from("<I", executable, 4)[0] == 0x0100000C, "Expected arm64 iPhone binary"
        assert not any("_CodeSignature/" in name for name in ipa.namelist()), "Expected an unsigned app"
        assert not any(name.endswith("embedded.mobileprovision") for name in ipa.namelist())


def main():
    ipa_path, zip_path = map(Path, sys.argv[1:])
    data = ipa_path.read_bytes()
    verify_ipa(data)
    with zipfile.ZipFile(zip_path) as outer:
        assert outer.testzip() is None, "Download ZIP CRC check failed"
        assert outer.read(ipa_path.name) == data, "Nested IPA differs"
        verify_ipa(outer.read(ipa_path.name))
        assert "SIDELOAD.txt" in outer.namelist()
    print("Verified: IPA + download ZIP CRCs, matching payload, native executable, bundle metadata, unsigned app.")


if __name__ == "__main__":
    main()
