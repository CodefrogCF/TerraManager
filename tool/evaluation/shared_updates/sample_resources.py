"""Record local host and selected Docker resource samples for a disposable evaluation."""
import argparse
import datetime
import json
import os
import platform
import subprocess
import time
from pathlib import Path

def linux_metadata():
    result = {"system": platform.system(), "machine": platform.machine(),
              "cpu_count": os.cpu_count()}
    model = Path("/proc/device-tree/model")
    if model.exists():
        result["device_model"] = model.read_text().strip("\0\n")
    memory = Path("/proc/meminfo")
    if memory.exists():
        for line in memory.read_text().splitlines():
            if line.startswith("MemTotal:"):
                result["memory_total_kib"] = int(line.split()[1])
    return result

def sample(containers, interface=None):
    result = {"utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "monotonic_seconds": time.monotonic()}
    if containers:
        completed = subprocess.run(
            ["docker", "stats", "--no-stream", "--format", "{{json .}}", *containers],
            capture_output=True, text=True, timeout=20, check=True)
        keep = {"Name", "CPUPerc", "MemUsage", "MemPerc", "NetIO", "BlockIO", "PIDs"}
        result["containers"] = [
            {key: value for key, value in json.loads(line).items() if key in keep}
            for line in completed.stdout.splitlines() if line.strip()
        ]
    if interface:
        base = Path("/sys/class/net") / interface / "statistics"
        result["host_interface_bytes"] = {
            name: int((base / (name + "_bytes")).read_text()) for name in ("rx", "tx")
        }
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", action="append", default=[])
    parser.add_argument("--interface")
    parser.add_argument("--seconds", type=int, default=600)
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.seconds < 1 or args.interval < .1:
        parser.error("Positive duration and an interval of at least 0.1 seconds are required")
    if args.interface and ("/" in args.interface or "\\" in args.interface or ".." in args.interface):
        parser.error("Expected a network interface name, not a path")
    if any(name.startswith("-") for name in args.container):
        parser.error("Container names must not start with '-'")
    start = time.monotonic()
    with args.output.open("x", encoding="utf-8") as output:
        output.write(json.dumps({"schema": 1, "metadata": linux_metadata(),
            "limits": "Docker NetIO is per container; do not sum proxy/backend traffic. "
                      "Host interface counters include unrelated traffic."}) + "\n")
        while time.monotonic() - start < args.seconds:
            output.write(json.dumps(sample(args.container, args.interface)) + "\n")
            output.flush()
            time.sleep(args.interval)

if __name__ == "__main__":
    main()

