"""Prints the UDID of an iPhone simulator from the newest iOS runtime.

Prefers the iPhone 16 Pro (the target phone), then other recent Pro models.
Usage: xcrun simctl list devices available --json | python3 pick_simulator.py
"""
import json
import re
import sys

PREFERRED = ("iPhone 16 Pro", "iPhone 17 Pro", "iPhone 16", "iPhone 17")


def runtime_version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(match.group(1)), int(match.group(2))) if match else (0, 0)


devices = json.load(sys.stdin)["devices"]
runtimes = sorted((name for name in devices if "iOS" in name), key=runtime_version, reverse=True)

for runtime in runtimes:
    available = [d for d in devices[runtime] if d.get("isAvailable", True)]
    for wanted in PREFERRED:
        for device in available:
            if device["name"] == wanted:
                print(f"Symulator: {device['name']} ({runtime})", file=sys.stderr)
                print(device["udid"])
                sys.exit(0)
    iphones = [d for d in available if d["name"].startswith("iPhone")]
    if iphones:
        print(f"Symulator: {iphones[0]['name']} ({runtime})", file=sys.stderr)
        print(iphones[0]["udid"])
        sys.exit(0)

sys.exit("Nie znaleziono symulatora iPhone'a")
