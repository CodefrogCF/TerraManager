"""Report warm RSS medians for the separate real-Flutter tab-reopen workload."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import statistics

from analyze_integrated import cpu_bounds, instant, load_resource_inputs


def rss_window(rows, start, finish):
    selected = sorted((row for row in rows if row.get("memory_available") and
                       row.get("rss_kib", 0) > 0 and start <= instant(row["observed_utc"]) <= finish),
                      key=lambda row: instant(row["observed_utc"]))
    times = [instant(row["observed_utc"]) for row in selected]
    gaps = [b - a for a, b in zip(times, times[1:])]
    covered = bool(times) and times[0] - start <= 10 and finish - times[-1] <= 10
    covered = covered and max(gaps, default=0) <= 10 and len(selected) >= 100
    return {"samples": len(selected), "coveredAtFiveSecondCadence": covered,
            "firstUtc": selected[0]["observed_utc"] if selected else None,
            "lastUtc": selected[-1]["observed_utc"] if selected else None,
            "maximumGapSeconds": max(gaps, default=None),
            "medianMiB": statistics.median(row["rss_kib"] / 1024 for row in selected) if selected else None}


def summarize(report, samples, metadata):
    if report.get("kind") != "integrated-flutter-tab-reopen-soak":
        raise ValueError("Expected a tab-reopen soak capture")
    if not report.get("startedAt") or not report.get("plannedFinishedAt"):
        raise ValueError("Capture did not reach its fixed workload")
    start, finish = instant(report["startedAt"]), instant(report["plannedFinishedAt"])
    clocks = [report[key] for key in ("clockBefore", "clockAfter") if report.get(key)]
    probes = [sample for clock in clocks for sample in clock["samples"]]
    offset = (min(p["offsetLowerMs"] for p in probes) / 1000,
              max(p["offsetUpperMs"] for p in probes) / 1000) if probes else (0, 0)
    actual_reopens = sum(row["newConfirmedConnections"] for row in report["reopens"]
                         if row.get("completedAt") and instant(row["completedAt"]) <= finish)
    processes = defaultdict(list)
    for sample in samples:
        for row in sample.get("processes", []):
            processes[row["container"]].append(row)
    result = {"schema": 1, "kind": "integrated-tab-reopen-resource-summary",
              "captureStatus": report.get("status"), "method": report["method"],
              "startedAt": report["startedAt"], "plannedFinishedAt": report["plannedFinishedAt"],
              "fixedWindowSeconds": finish - start, "actualReopensInsideFixedWindow": actual_reopens,
              "durationAndReopenThresholdsMet": finish - start >= 1800 and actual_reopens >= 100,
              "reportedFixedWindowOverrunMs": report.get("fixedWindowOverrunMs"),
              "clockProbesBeforeAndAfter": len(clocks) == 2,
              "sampledStreamsMaximum": max((s["streams"] for s in report["streamSamples"]), default=None),
              "finalSampledStreams": report["streamSamples"][-1]["streams"] if report["streamSamples"] else None,
              "pageErrorsIncludingSetup": sum(c["pageErrors"] for c in report.get("clients", [])),
              "processes": {},
              "limits": [
                  "Tab reopen includes production Flutter startup and route reads; it is separate from outage recovery and normal invalidation.",
                  "Compare first/final ten-minute medians within the fixed workload after excluded setup/warmup.",
                  "RSS is sampled PID 1 memory, not continuous peak, container/tmpfs memory or browser memory.",
                  "Median comparison requires one stable process identity and dense coverage in both windows.",
                  "Investigate growth above 10 percent; a smaller change does not by itself prove the absence of leaks.",
                  "CPU is a workload observation; the ordinary idle/write CPU budgets do not apply to repeated tab startup.",
                  "Stream samples and source queue bounds are separate evidence; no live queue-size instrumentation is claimed."]}
    tick_rate = (metadata or {}).get("metadata", {}).get("clock_ticks_per_second")
    for name, rows in processes.items():
        # Ensure selected median samples are strictly inside their clock guards.
        early = rss_window(rows, start + offset[1] + .1, start + 600 + offset[0] - .1)
        late = rss_window(rows, finish - 600 + offset[1] + .1, finish + offset[0] - .1)
        selected = [row for row in rows if start + offset[0] - .1 <= instant(row["observed_utc"]) <= finish + offset[1] + .1]
        identities = sorted({row.get("start_time_ticks") for row in selected if row.get("start_time_ticks") is not None})
        stable = len(identities) == 1 and all(row.get("start_time_ticks") is not None for row in selected)
        rss = [row["rss_kib"] / 1024 for row in selected if row.get("memory_available") and row.get("rss_kib", 0) > 0]
        available = (stable and early["coveredAtFiveSecondCadence"] and late["coveredAtFiveSecondCadence"]
                     and finish - start >= 1800 and len(clocks) == 2)
        growth = (late["medianMiB"] / early["medianMiB"] - 1) * 100 if available else None
        rss_limit = 80 if "gateway" in name else 256
        result["processes"][name] = {"processIdentities": identities, "stableIdentity": stable,
            "initialWarmTenMinutes": early, "finalWarmTenMinutes": late,
            "sampledRssMaximumMiB": max(rss) if rss else None,
            "proposedSampledRssLimitMiB": rss_limit,
            "sampledRssBudgetStatus": "unavailable" if not rss else "sampled-within-limit" if max(rss) <= rss_limit else "sampled-exceeds-limit",
            "warmMedianGrowthPercent": growth,
            "growthAssessment": "unavailable" if growth is None else "investigate-over-10-percent" if growth > 10 + 1e-9 else "within-10-percent-investigation-threshold",
            "cpuWholeWorkload": cpu_bounds(rows, start, finish, tick_rate, offset) if tick_rate else None}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--resources", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    capture = json.loads(args.capture.read_text(encoding="utf-8-sig"))
    metadata, samples, partial, sources = load_resource_inputs(args.resources)
    result = summarize(capture, samples, metadata)
    result["sourceCaptureSha256"] = hashlib.sha256(args.capture.read_bytes()).hexdigest()
    result["sourceResourceCaptures"] = sources
    result["trailingPartialResourceRecords"] = partial
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"captureStatus": result["captureStatus"], "actualReopens": result["actualReopensInsideFixedWindow"],
                      "processes": len(result["processes"])}))


if __name__ == "__main__":
    main()
