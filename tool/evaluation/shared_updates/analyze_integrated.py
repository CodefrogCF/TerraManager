"""Summarize integrated Flutter trials with explicit whole-window CPU bounds."""
import argparse
from collections import defaultdict
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path
import statistics


def instant(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()


def frame_summary(value):
    """Missing production instrumentation stays null, rather than zero frames."""
    if value is None:
        return None
    key = "frameElapsedMicroseconds" if "frameElapsedMicroseconds" in value else "frameCpuMicroseconds"
    durations = value.get(key)
    if not isinstance(durations, list) or any(type(n) not in (int, float) or not math.isfinite(n) or n < 0 for n in durations):
        raise ValueError("Invalid frame duration evidence")
    ordered = sorted(durations)
    return {"sourceKind": value.get("kind"), "sourceField": key,
            "interpretation": "synchronous-drawFrame-elapsed-wall-time-not-OS-CPU-or-presentation",
            "samples": len(ordered), "droppedSamples": value.get("droppedSamples"),
            "totalElapsedMicroseconds": sum(ordered),
            "p50ElapsedMicroseconds": ordered[math.ceil(len(ordered) * .5) - 1] if ordered else None,
            "p95ElapsedMicroseconds": ordered[math.ceil(len(ordered) * .95) - 1] if ordered else None,
            "maxElapsedMicroseconds": max(ordered) if ordered else None}


def load_resources(path):
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    rows, partial = [], 0
    for index, line in enumerate(lines):
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            if index != len(lines) - 1:
                raise
            partial += 1
    headers = [row for row in rows if "metadata" in row]
    if len(headers) != 1:
        raise ValueError("Expected one resource metadata record")
    return headers[0], [row for row in rows if "utc" in row], partial


def load_resource_inputs(paths):
    """Union probe observations, preserving overlap instead of adding counters."""
    metadata, samples, sources, ranges, seen = None, [], [], [], {}
    partial_total = 0
    for path in paths:
        header, rows, partial = load_resources(path)
        if metadata is not None and header["metadata"] != metadata["metadata"]:
            raise ValueError("Resource captures have different host/tick metadata")
        metadata = metadata or header
        times = [instant(row["utc"]) for row in rows]
        overlaps = sum(max(0, min(max(times), end) - max(min(times), start))
                       for start, end in ranges) if times else 0
        sources.append({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        "samples": len(rows), "trailingPartialRecords": partial,
                        "firstUtc": min((row["utc"] for row in rows), default=None),
                        "lastUtc": max((row["utc"] for row in rows), default=None),
                        "overlapSecondsWithEarlierInputs": overlaps})
        if times:
            ranges.append((min(times), max(times)))
        partial_total += partial
        for row in rows:
            # A second copy of the same observation must not inflate sample counts.
            key = (row["utc"], row.get("monotonic_seconds"))
            if key in seen:
                if seen[key] != row:
                    raise ValueError("Conflicting resource records at the same observation")
                continue
            seen[key] = row
            samples.append(row)
    samples.sort(key=lambda row: instant(row["utc"]))
    return metadata, samples, partial_total, sources


def cpu_bounds(rows, start, finish, tick_rate, offset=(0, 0), guard=.1):
    """Endpoint ticks bound the complete window; never hide its initial burst.

    The outer endpoints fully surround the window including clock/probe guards.
    The inner endpoints are fully inside it. Two ticks cover rounding of the two
    user/system counters. A partial inner span is not a whole-window CPU mean.
    """
    duration = finish - start
    if duration <= 0 or not tick_rate or tick_rate <= 0 or guard < 0:
        raise ValueError("Invalid CPU window, tick rate or guard")
    valid = sorted((r for r in rows if all(r.get(key) is not None for key in
        ("observed_utc", "cpu_user_ticks", "cpu_system_ticks", "start_time_ticks"))),
        key=lambda r: instant(r["observed_utc"]))
    def early(r):
        return instant(r["observed_utc"]) - r.get("collection_duration_seconds", 0) / 2
    def late(r):
        return instant(r["observed_utc"]) + r.get("collection_duration_seconds", 0) / 2
    before = [r for r in valid if late(r) <= start + offset[0] - guard]
    after = [r for r in valid if early(r) >= finish + offset[1] + guard]
    inner = [r for r in valid if early(r) >= start + offset[1] + guard
             and late(r) <= finish + offset[0] - guard]
    result = {"windowSeconds": duration, "clockOffsetRangeSeconds": list(offset),
              "guardSeconds": guard, "quantizationGuardTicks": 2,
              "lowerPercentOneCore": None, "upperPercentOneCore": None,
              "innerCounterSpanSeconds": None, "outerCounterSpanSeconds": None}
    if not before or not after:
        return {**result, "unavailableReason": "missing-surrounding-probes"}
    first, last = before[-1], after[0]
    involved = [r for r in valid if early(first) <= instant(r["observed_utc"]) <= late(last)]
    identities = sorted({r["start_time_ticks"] for r in involved})
    result["processIdentities"] = identities
    if len(identities) != 1:
        return {**result, "unavailableReason": "process-restarted"}
    def ticks(r):
        return r["cpu_user_ticks"] + r["cpu_system_ticks"]
    if any(ticks(b) < ticks(a) for a, b in zip(involved, involved[1:])):
        return {**result, "unavailableReason": "cpu-counter-regressed"}
    result["upperPercentOneCore"] = (ticks(last) - ticks(first) + 2) / tick_rate / duration * 100
    result["outerCounterSpanSeconds"] = instant(last["observed_utc"]) - instant(first["observed_utc"])
    result["outerFirstUtc"], result["outerLastUtc"] = first["observed_utc"], last["observed_utc"]
    if len(inner) >= 2:
        result["lowerPercentOneCore"] = max(0, ticks(inner[-1]) - ticks(inner[0]) - 2) / tick_rate / duration * 100
        result["innerCounterSpanSeconds"] = instant(inner[-1]["observed_utc"]) - instant(inner[0]["observed_utc"])
    return result


def budget_status(bounds, limit):
    lower, upper = bounds.get("lowerPercentOneCore"), bounds.get("upperPercentOneCore")
    if upper is not None and upper <= limit:
        return "within-conservative-bound"
    if lower is not None and lower > limit:
        return "exceeds-conservative-bound"
    return "inconclusive-at-this-resolution"


def summarize(report, samples=(), metadata=None, guard=.1):
    processes = defaultdict(list)
    for sample in samples:
        for process in sample.get("processes", []):
            processes[process["container"]].append(process)
    tick_rate = (metadata or {}).get("metadata", {}).get("clock_ticks_per_second")
    result = {"schema": 1, "kind": "integrated-flutter-window-summary", "captureStatus": report.get("status"),
              "browser": report["browser"], "mode": report["mode"], "diagnostics": report.get("diagnostics", "off"),
              "budgetInterpretation": "proposed-SSE-acceptance" if report["mode"] == "sse" else "SSE-budget-reference-only-for-polling-baseline",
              "plan": report.get("plan"), "resourceMetadata": metadata, "windows": [],
              "limits": ["Clients within each trial are correlated. Keep repetitions separate.",
                  "Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.",
                  "Screenshot completion is an upper capture bound, not physical presentation time.",
                  "CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.",
                  "Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.",
                  "Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted."]}
    for trial in report["trials"]:
        clocks = [trial[k] for k in ("clockBefore", "clockAfter") if trial.get(k)]
        offset = (min(c["offsetLowerMs"] for c in clocks) / 1000,
                  max(c["offsetUpperMs"] for c in clocks) / 1000) if clocks else (0, 0)
        for window in trial["views"]:
            if not window.get("finishedAt") or not window.get("clients"):
                continue
            row = {key: window[key] for key in ("view", "workload", "startedAt", "finishedAt", "wallMs")}
            row.update({"clients": trial["clients"], "repetition": trial["repetition"],
                        "clockProbesAvailable": len(clocks) == 2, "streamsAfterTrialClose": trial.get("streamsAfterClose"),
                        "dataGETs": 0, "changeControlGETs": 0, "decodedBodyBytes": 0, "upkeepEvents": 0,
                        "terminalFailures": 0, "failuresProvenConsumed": 0, "pageErrors": 0,
                        "liveByteCoverage": True, "writes": window["writes"], "frameObservations": [],
                        "semanticsMs": window["semanticsMs"], "screenshotUpperBoundMs": window["screenshotUpperBoundMs"], "processes": {}})
            for client in window["clients"]:
                row["frameObservations"].append({"client": client["client"], "measurement": frame_summary(client.get("frames"))})
                for route, counts in client["routes"].items():
                    if route.startswith("/api/v1/changes"):
                        row["changeControlGETs"] += counts["getRequests"]
                    elif not route.startswith("/api/v1/auth/"):
                        row["dataGETs"] += counts["getRequests"]
                row["decodedBodyBytes"] += client["bytes"]["decodedBody"]
                row["upkeepEvents"] += client["sseEvents"].get("keepalive", 0)
                row["terminalFailures"] += len(client["failures"])
                row["failuresProvenConsumed"] += sum(
                    f.get("bodyOutcome") == "actual-body-valid-json-read-to-eof" and
                    f.get("applicationOutcome") == "json-decoded-by-actual-application-consumer"
                    for f in client["failures"])
                row["pageErrors"] += client["pageErrors"]
                row["liveByteCoverage"] &= client["liveStreamByteCoverage"]
            row["unclassifiedOrUnsuccessfulFailures"] = row["terminalFailures"] - row["failuresProvenConsumed"]
            start, finish = instant(window["startedAt"]), instant(window["finishedAt"])
            for name, observations in processes.items():
                selected = sorted((p for p in observations if start + offset[0] - guard <= instant(p["observed_utc"]) <= finish + offset[1] + guard), key=lambda p: instant(p["observed_utc"]))
                rss = [p["rss_kib"] / 1024 for p in selected if p.get("memory_available") and p.get("rss_kib") is not None]
                times = [instant(p["observed_utc"]) for p in selected]
                gaps = [b - a for a, b in zip(times, times[1:])]
                component = "caddy" if "gateway" in name else "dart"
                rss_limit = 80 if component == "caddy" else 256
                stats = {"rssSamples": len(rss), "rssMaxMiB": max(rss) if rss else None,
                         "rssMedianMiB": statistics.median(rss) if rss else None,
                         "probeSamples": len(selected),
                         "probeSpanSeconds": times[-1] - times[0] if len(times) >= 2 else None,
                         "maxProbeGapSeconds": max(gaps) if gaps else None,
                         "maxCollectionDurationSeconds": max((p.get("collection_duration_seconds", 0) for p in selected), default=None),
                         "proposedSampledRssLimitMiB": rss_limit,
                         "sampledRssBudgetStatus": "sampled-within-limit" if rss and max(rss) <= rss_limit else "sampled-exceeds-limit" if rss else "unavailable"}
                if tick_rate:
                    stats["cpu"] = cpu_bounds(observations, start, finish, tick_rate, offset, guard)
                    limit = .1 if window["workload"] == "idle" else (.25 if component == "caddy" else 1.5)
                    stats["proposedCpuLimitPercentOneCore"] = limit
                    stats["proposedCpuBudgetStatus"] = budget_status(stats["cpu"], limit)
                row["processes"][name] = stats
            result["windows"].append(row)
    return result


def markdown(report):
    lines = ["# Integrated Flutter measurement windows", "",
             f"Capture: {report['captureStatus']}; browser: {report['browser']}; mode: {report['mode']}; read diagnostics: {report['diagnostics']}.", "",
             "| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |",
             "| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for w in report["windows"]:
        p95 = w["screenshotUpperBoundMs"]["p95"]
        lines.append(f"| {w['clients']} | {w['repetition']} | {w['view']} | {w['workload']} | {w['dataGETs']} | {w['decodedBodyBytes']} | {w['upkeepEvents']} | {w['terminalFailures']} / {w['failuresProvenConsumed']} | {p95 if p95 is not None else '-'} |")
    lines += ["", "## Process observations", "", "CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.", "",
              "| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |",
              "| --- | --- | ---: | ---: | --- |"]
    def number(value):
        return f"{value:.3f}" if value is not None else "unavailable"
    for w in report["windows"]:
        for name, p in w["processes"].items():
            cpu = p.get("cpu", {})
            lines.append(f"| {w['clients']} clients r{w['repetition']} {w['view']} / {w['workload']} | {name} | {number(p['rssMaxMiB'])} | {number(cpu.get('lowerPercentOneCore'))} / {number(cpu.get('upperPercentOneCore'))} | {p.get('proposedCpuBudgetStatus', 'unavailable')} |")
    if any(frame["measurement"] is not None for window in report["windows"] for frame in window["frameObservations"]):
        lines += ["", "## Supplementary drawFrame elapsed time", "",
                  "Synchronous elapsed wall time includes preemption. It is not OS CPU time, GPU time or presentation latency. Missing release measurements remain null.", "",
                  "| View / workload | Client | Frames | Dropped | p95 elapsed microseconds |",
                  "| --- | ---: | ---: | ---: | ---: |"]
        for window in report["windows"]:
            for frame in window["frameObservations"]:
                item = frame["measurement"]
                if item is not None:
                    lines.append(f"| {window['view']} / {window['workload']} | {frame['client']} | {item['samples']} | {item['droppedSamples']} | {item['p95ElapsedMicroseconds']} |")
    return "\n".join(lines + ["", "## Limits", ""] + ["- " + text for text in report["limits"]]) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--resources", type=Path, action="append", default=[],
                        help="Repeat for overlapping captures of the same host; counters are never added")
    parser.add_argument("--guard-ms", type=float, default=100)
    parser.add_argument("--output-prefix", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.capture.read_text(encoding="utf-8-sig"))
    metadata, samples, partial, sources = load_resource_inputs(args.resources)
    result = summarize(report, samples, metadata, args.guard_ms / 1000)
    result["sourceCaptureSha256"] = hashlib.sha256(args.capture.read_bytes()).hexdigest()
    result["trailingPartialResourceRecords"] = partial
    result["sourceResourceCaptures"] = sources
    if len(sources) == 1:
        result["sourceResourcesSha256"] = sources[0]["sha256"]
    args.output_prefix.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    args.output_prefix.with_suffix(".md").write_text(markdown(result), encoding="utf-8")
    print(json.dumps({"windows": len(result["windows"]), "resourcesLoaded": bool(samples), "captureStatus": result["captureStatus"]}))


if __name__ == "__main__":
    main()
