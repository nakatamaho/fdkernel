# SPDX-License-Identifier: GPL-2.0-or-later
"""Strict parameter validation for public-synthetic or local-private loader builds.

This module emits no diagnostics containing profile values or paths. Its caller
owns the output privacy boundary; private definitions and identities stay local.
"""


class ProfileError(ValueError):
    pass


def keys(value, expected):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise ProfileError("Unexpected or missing profile fields")


def integer(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ProfileError("Profile integer is outside its supported range")
    return value


def interval(value):
    if not isinstance(value, list) or len(value) != 2:
        raise ProfileError("Invalid ownership interval")
    start, end = [integer(v, 0, 0x100000) for v in value]
    if start >= end:
        raise ProfileError("Ownership interval is empty or reversed")
    return start, end


def definitions(profile):
    keys(profile, ("schema_version", "profile_class", "regions", "firmware_regions", "stack", "disk", "cache"))
    if type(profile["schema_version"]) is not int or profile["schema_version"] != 1:
        raise ProfileError("Unsupported profile version")
    if profile["profile_class"] not in ("synthetic_rom_free", "private_observation_overlay"):
        raise ProfileError("Profile privacy class is required")
    names = ("stage2", "loader_stack", "scratch", "kernel_file", "kernel_allocation")
    keys(profile["regions"], names)
    owned = {name: interval(profile["regions"][name]) for name in names}
    for start, end in owned.values():
        if start % 16 or end % 16 or end - start > 65520:
            raise ProfileError("Owned region violates paragraph or segment bounds")
    firmware = profile["firmware_regions"]
    if not isinstance(firmware, list) or not 1 <= len(firmware) <= 16:
        raise ProfileError("Firmware ownership intervals are required")
    reserved = [interval(v) for v in firmware]
    for index, (start, end) in enumerate(owned.values()):
        for other_start, other_end in list(owned.values())[index + 1:] + reserved:
            if start < other_end and other_start < end:
                raise ProfileError("Owned regions overlap each other or firmware")
    keys(profile["stack"], ("segment", "pointer", "reserve"))
    stack = {k: integer(v, 0, 65535) for k, v in profile["stack"].items()}
    if stack["reserve"] < 1024 or stack["pointer"] < stack["reserve"]:
        raise ProfileError("Loader stack reserve is insufficient")
    top = stack["segment"] * 16 + stack["pointer"]
    if not owned["loader_stack"][0] <= top - stack["reserve"] < top <= owned["loader_stack"][1]:
        raise ProfileError("Loader stack lies outside its owned interval")
    keys(profile["disk"], ("sector_bytes", "sectors_track", "heads", "total_sectors"))
    disk = {k: integer(v, 1, 65535) for k, v in profile["disk"].items()}
    sector = disk["sector_bytes"]
    if not 128 <= sector <= 4096 or sector & (sector - 1):
        raise ProfileError("Unsupported sector size")
    if disk["sectors_track"] > 255 or disk["heads"] > 256:
        raise ProfileError("Disk geometry exceeds the shared adapter ABI")
    keys(profile["cache"], ("fat_bytes", "root_bytes", "bitmap_bytes"))
    cache = {k: integer(v, 1, 65535) for k, v in profile["cache"].items()}
    if cache["fat_bytes"] % sector or cache["root_bytes"] % sector or cache["root_bytes"] % 32:
        raise ProfileError("Metadata capacities are not complete sector records")
    offsets = {"BOOT": 0, "FAT": sector, "MIRROR": sector + cache["fat_bytes"],
               "ROOT": sector + 2 * cache["fat_bytes"],
               "BITMAP": sector + 2 * cache["fat_bytes"] + cache["root_bytes"]}
    if offsets["BITMAP"] + cache["bitmap_bytes"] > owned["scratch"][1] - owned["scratch"][0]:
        raise ProfileError("Metadata workspace exceeds scratch ownership")
    if owned["stage2"][1] - owned["stage2"][0] < sector:
        raise ProfileError("Stage-2 ownership is too small")
    result = {"PC88VA_PROFILE_VERSION": 1,
              "S2_STACK_SEGMENT": stack["segment"], "S2_STACK_POINTER": stack["pointer"],
              "S2_STACK_RESERVE": stack["reserve"],
              "S2_FAT_CAPACITY": cache["fat_bytes"], "S2_ROOT_CAPACITY": cache["root_bytes"],
              "S2_BITMAP_CAPACITY": cache["bitmap_bytes"]}
    for name, (start, end) in owned.items():
        result["S2_" + name.upper() + "_SEGMENT"] = start // 16
        result["S2_" + name.upper() + "_CAPACITY"] = end - start
    for name, value in offsets.items():
        result["S2_" + name + "_OFFSET"] = value
    for name, value in disk.items():
        result["S2_" + name.upper()] = value
    return result


def nasm_definitions(profile):
    return "".join("%define " + name + " " + str(value) + "\n"
                   for name, value in sorted(definitions(profile).items()))


def stage2_symbols(image):
    import struct
    names = ("version", "entry", "failure", "adapter", "boot", "metadata", "disk",
             "volume", "fat", "root", "file", "mz", "call_flags", "end")
    if len(image) < 36 or image[-36:-28] != b"M08S2SYM" or image.count(b"M08S2SYM") != 1:
        raise ProfileError("Stage-2 symbol footer is missing or ambiguous")
    symbols = dict(zip(names, struct.unpack("<14H", image[-28:])))
    if symbols["version"] != 1 or symbols["entry"] != 0 or symbols["end"] != len(image):
        raise ProfileError("Stage-2 symbol footer contract differs")
    if any(not 0 <= symbols[name] < len(image) - 36 for name in names[1:-1]):
        raise ProfileError("Stage-2 symbol lies outside the image")
    return symbols
