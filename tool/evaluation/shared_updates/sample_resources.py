"""Record local host and selected Docker resource samples for a disposable evaluation."""
import argparse
import datetime
import json
import math
import os
import platform
import subprocess
import time
from pathlib import Path

def linux_metadata():
    result = {"system": platform.system(), "machine": platform.machine(),
              "cpu_count": os.cpu_count()}
    if hasattr(os, "sysconf"):
        result["clock_ticks_per_second"] = os.sysconf("SC_CLK_TCK")
    model = Path("/proc/device-tree/model")
    if model.exists():
        result["device_model"] = model.read_text().strip("\0\n")
    memory = Path("/proc/meminfo")
    if memory.exists():
        for line in memory.read_text().splitlines():
            if line.startswith("MemTotal:"):
                result["memory_total_kib"] = int(line.split()[1])
    return result

def parse_process_snapshot(text):
    """Parse only PID 1's stat/status; missing memory is unavailable, never zero."""
    stat, _, status = text.partition("\n")
    closing = stat.rfind(")")
    if closing < 0 or not stat.startswith("1 ("):
        raise ValueError("Expected a PID 1 stat record")
    fields = stat[closing + 1:].split()  # Starts at stat field 3 (state).
    if len(fields) < 20:
        raise ValueError("Incomplete process stat record")
    user, system, start = (int(fields[index]) for index in (11, 12, 19))
    if min(user, system, start) < 0:
        raise ValueError("Negative process CPU counter")
    result = {"pid": 1, "cpu_user_ticks": user, "cpu_system_ticks": system,
              "start_time_ticks": start, "rss_kib": None, "high_water_kib": None,
              "threads": None}
    for line in status.splitlines():
        key, _, value = line.partition(":")
        if key in ("VmRSS", "VmHWM"):
            parts = value.split()
            if len(parts) != 2 or parts[1] != "kB" or int(parts[0]) < 0:
                raise ValueError("Invalid process memory value")
            result["rss_kib" if key == "VmRSS" else "high_water_kib"] = int(parts[0])
        elif key == "Threads":
            result["threads"] = int(value.strip())
    result["memory_available"] = result["rss_kib"] is not None
    return result


def process_snapshot(container):
    started = time.monotonic()
    utc = datetime.datetime.now(datetime.timezone.utc)
    try:
        # Fixed read-only command; never interpolate container names into a shell.
        completed = subprocess.run(
            ["docker", "exec", container, "sh", "-eu", "-c",
             "cat /proc/1/stat; cat /proc/1/status"],
            capture_output=True, text=True, timeout=10, check=True)
        result = parse_process_snapshot(completed.stdout)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError, ValueError) as error:
        result = {"memory_available": False, "rss_kib": None,
                  "cpu_user_ticks": None, "cpu_system_ticks": None,
                  "error": type(error).__name__}
    elapsed = time.monotonic() - started
    result.update({"container": container,
                   "observed_utc": (utc + datetime.timedelta(seconds=elapsed / 2)).isoformat(),
                   "observed_monotonic_seconds": started + elapsed / 2,
                   "collection_duration_seconds": elapsed})
    return result


def next_deadline(previous, interval, now):
    """Keep a fixed cadence and skip overdue slots instead of catch-up bursts."""
    target = previous + interval
    skipped = max(0, math.floor((now - target) / interval) + 1) if now > target else 0
    return target + skipped * interval, skipped


def sample(containers, interface=None, process_stats=False):
    result = {"utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "monotonic_seconds": time.monotonic()}
    if containers:
        try:
            completed = subprocess.run(
                ["docker", "stats", "--no-stream", "--format", "{{json .}}", *containers],
                capture_output=True, text=True, timeout=20, check=True)
            keep = {"Name", "CPUPerc", "MemUsage", "MemPerc", "NetIO", "BlockIO", "PIDs"}
            result["containers"] = [
                {key: value for key, value in json.loads(line).items() if key in keep}
                for line in completed.stdout.splitlines() if line.strip()
            ]
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError, ValueError) as error:
            result["docker_stats_error"] = type(error).__name__
        if process_stats:
            result["processes"] = [process_snapshot(container) for container in containers]
    if interface:
        base = Path("/sys/class/net") / interface / "statistics"
        result["host_interface_bytes"] = {
            name: int((base / (name + "_bytes")).read_text()) for name in ("rx", "tx")
        }
        result["host_interface_observed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result["collection_duration_seconds"] = time.monotonic() - result["monotonic_seconds"]
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", action="append", default=[])
    parser.add_argument("--interface")
    parser.add_argument("--process-stats", action="store_true",
                        help="Read PID 1 RSS/high-water and cumulative CPU via docker exec")
    parser.add_argument("--seconds", type=int, default=600)
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.seconds < 1 or not math.isfinite(args.interval) or args.interval < .1:
        parser.error("Positive duration and an interval of at least 0.1 seconds are required")
    if args.interface and ("/" in args.interface or "\\" in args.interface or ".." in args.interface):
        parser.error("Expected a network interface name, not a path")
    if any(name.startswith("-") for name in args.container):
        parser.error("Container names must not start with '-'")
    start = time.monotonic()
    deadline = start
    with args.output.open("x", encoding="utf-8") as output:
        output.write(json.dumps({"schema": 2, "metadata": linux_metadata(),
            "requested_interval_seconds": args.interval, "process_stats_requested": args.process_stats,
            "limits": "Docker NetIO is per container; do not sum proxy/backend traffic. "
                      "Host interface counters include unrelated traffic. "
                      "PID 1 RSS is process memory, not container/tmpfs memory. "
                      "VmHWM is lifetime-wide, not a per-trial peak. "
                      "CPU tick deltas require the same process start_time_ticks. "
                      "Collection adds diagnostic overhead; inspect actual timestamps."}) + "\n")
        while time.monotonic() - start < args.seconds:
            record = sample(args.container, args.interface, args.process_stats)
            deadline, skipped = next_deadline(deadline, args.interval, time.monotonic())
            record["skipped_interval_slots"] = skipped
            output.write(json.dumps(record) + "\n")
            output.flush()
            time.sleep(max(0, min(deadline, start + args.seconds) - time.monotonic()))

if __name__ == "__main__":
    main()

