"""Compare completed real-Flutter SSE/polling trials without pooling repetitions."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)] if values else None


def windows(report, expected_mode):
    if report.get("status") != "complete" or report.get("mode") != expected_mode:
        raise ValueError("Expected a completed " + expected_mode + " capture")
    result = {}
    for trial in report["trials"]:
        if trial.get("status") != "complete" or trial.get("streamsAfterClose") != 0:
            raise ValueError("Incomplete trial or streams retained after close")
        for window in trial["views"]:
            key = (trial["clients"], trial["repetition"], window["view"], window["workload"])
            if key in result or not window.get("finishedAt") or len(window["clients"]) != trial["clients"]:
                raise ValueError("Duplicate, incomplete or missing client window")
            result[key] = (trial, window)
    return result


def measurements(window):
    data_gets, body_bytes, unknown, page_errors = 0, 0, [], 0
    for client in window["clients"]:
        data_gets += sum(counts["getRequests"] for route, counts in client["routes"].items()
                         if not route.startswith(("/api/v1/auth/", "/api/v1/changes")))
        body_bytes += client["bytes"]["decodedBody"]
        page_errors += client["pageErrors"]
        if not client["liveStreamByteCoverage"]:
            raise ValueError("Missing live-stream byte coverage")
        unknown.extend(f["route"] for f in client["failures"]
                       if f.get("bodyOutcome") != "actual-body-valid-json-read-to-eof" or
                       f.get("applicationOutcome") != "json-decoded-by-actual-application-consumer")
    observations = [row for write in window["writes"] for row in write["observations"]]
    return {"wallMs": window["wallMs"], "dataGETs": data_gets, "decodedBodyBytes": body_bytes,
            "unclassifiedOrUnsuccessfulFailuresByRoute": dict(Counter(unknown)),
            "pageErrorsCumulativeAtWindowEnd": page_errors,
            "semanticsP95Ms": percentile([row["semanticsMs"] for row in observations], .95),
            "captureP95Ms": percentile([row["screenshotUpperBoundMs"] for row in observations], .95),
            "observations": len(observations),
            "allObservedPixelsChanged": all(row["dataRegionPixelsChanged"] for row in observations)}


def reduction(current, baseline, current_ms, baseline_ms):
    if baseline <= 0 or current_ms <= 0 or baseline_ms <= 0:
        return None
    return (1 - (current / current_ms) / (baseline / baseline_ms)) * 100


def compare(sse, polling, selected_clients=None):
    for key in ("kind", "browser", "channel", "diagnostics", "toolSha256"):
        if key not in sse or key not in polling or sse[key] != polling[key]:
            raise ValueError("Comparison inputs differ in " + key)
    for key in ("browserExecutableSha256", "webArtifact"):
        if sse.get(key) != polling.get(key):
            raise ValueError("Comparison inputs differ in " + key)
    if sse.get("webArtifact", {}).get("kind", "gateway-production-release") != "gateway-production-release":
        raise ValueError("Supplementary probe is not a release comparison")
    if any(not isinstance(report.get("plan"), dict) for report in (sse, polling)):
        raise ValueError("Comparison inputs differ in plan")
    plans = [dict(report["plan"]) for report in (sse, polling)]
    if selected_clients is not None:
        if not selected_clients or not set(selected_clients) <= set(plans[0]["clients"]) & set(plans[1]["clients"]):
            raise ValueError("Selected clients missing from a capture")
        for plan in plans:
            plan["clients"] = sorted(selected_clients)
    if plans[0] != plans[1]:
        raise ValueError("Comparison inputs differ in plan")
    if sse["kind"] != "integrated-flutter-acceptance":
        raise ValueError("Expected production Flutter captures")
    current, baseline = windows(sse, "sse"), windows(polling, "polling")
    if selected_clients is not None:
        current = {key: value for key, value in current.items() if key[0] in selected_clients}
        baseline = {key: value for key, value in baseline.items() if key[0] in selected_clients}
    if current.keys() != baseline.keys():
        raise ValueError("Comparison workloads/repetitions differ")
    rows = []
    for key in sorted(current):
        trial, window = current[key]
        old_trial, old_window = baseline[key]
        if trial["logicalContexts"] != old_trial["logicalContexts"]:
            raise ValueError("Client tab/context grouping differs")
        now, old = measurements(window), measurements(old_window)
        clients, repetition, view, workload = key
        row = {"clients": clients, "repetition": repetition, "view": view, "workload": workload,
               "sse": now, "polling": old}
        if workload == "idle":
            row["idleDataGetReductionPercent"] = reduction(now["dataGETs"], old["dataGETs"], now["wallMs"], old["wallMs"])
            row["idleBodyByteReductionPercent"] = reduction(now["decodedBodyBytes"], old["decodedBodyBytes"], now["wallMs"], old["wallMs"])
            row["numericalTargetMet"] = (row["idleDataGetReductionPercent"] is not None and row["idleDataGetReductionPercent"] >= 90 and
                                         row["idleBodyByteReductionPercent"] is not None and row["idleBodyByteReductionPercent"] >= 80)
        else:
            expected = clients * sse["plan"]["writesPerView"]
            row["numericalTargetMet"] = (now["captureP95Ms"] is not None and now["captureP95Ms"] <= 2000 and
                                         now["observations"] == expected and now["allObservedPixelsChanged"])
        rows.append(row)
    expected_keys = {(clients, rep, view, work) for clients in (1, 3, 5, 10)
                     for rep in (1, 2, 3) for view in ("overview", "detail") for work in ("idle", "writes")}
    five = [row for row in rows if row["clients"] == 5]
    required_five_keys = {(5, rep, view, work) for rep in (1, 2, 3)
                         for view in ("overview", "detail") for work in ("idle", "writes")}
    failures_open = any(item[mode]["unclassifiedOrUnsuccessfulFailuresByRoute"] or
                        item[mode]["pageErrorsCumulativeAtWindowEnd"] for item in rows for mode in ("sse", "polling"))
    return {"schema": 1, "kind": "matched-integrated-flutter-comparison", "browser": sse["browser"],
            "plan": plans[0], "diagnostics": sse["diagnostics"],
            "explicitClientSubset": sorted(selected_clients) if selected_clients is not None else None,
            "requiredMatrixComplete": expected_keys <= current.keys(),
            "fiveClientNumericalTargetsMet": required_five_keys <= current.keys() and all(row["numericalTargetMet"] for row in five),
            "requestOrPageErrorEvidenceOpen": failures_open, "windows": rows,
            "limits": [
                "Numerical targets are not overall issue acceptance: resource bounds, rendering, physical lifecycle and the soak are separate.",
                "Each repetition stays separate; clients observing the same write are correlated.",
                "Body-byte rates include stream upkeep/fallback/resync but exclude headers, TLS/TCP and other wire overhead.",
                "Capture p95 is an upper bound after semantics/two animation callbacks, not physical presentation time.",
                "Unclassified terminal events remain open even if UI values and numerical targets succeed.",
                "Exact image identities and experiment mode order need their separate provenance record.",
                "Separate transport batches have time/order and warm-up confounds; consult composition/switch timestamps. No per-mode RAM saving follows from this comparison."]}


def markdown(report):
    lines = ["# Matched integrated Flutter comparison", "",
             f"Required matrix complete: {report['requiredMatrixComplete']}; five-client numerical targets: {report['fiveClientNumericalTargetsMet']}; request/page evidence open: {report['requestOrPageErrorEvidenceOpen']}.", "",
             "| Clients | Repetition | View | Workload | SSE / polling data GETs | SSE / polling body bytes | GET reduction % | Body reduction % | SSE / polling capture p95 ms |",
             "| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    def number(value):
        return f"{value:.3f}" if value is not None else "-"
    for row in report["windows"]:
        now, old = row["sse"], row["polling"]
        lines.append(f"| {row['clients']} | {row['repetition']} | {row['view']} | {row['workload']} | {now['dataGETs']} / {old['dataGETs']} | {now['decodedBodyBytes']} / {old['decodedBodyBytes']} | {number(row.get('idleDataGetReductionPercent'))} | {number(row.get('idleBodyByteReductionPercent'))} | {number(now['captureP95Ms'])} / {number(old['captureP95Ms'])} |")
    return "\n".join(lines + ["", "## Limits", ""] + ["- " + item for item in report["limits"]]) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sse", type=Path)
    parser.add_argument("polling", type=Path)
    parser.add_argument("--output-prefix", type=Path, required=True)
    parser.add_argument("--clients", type=int, nargs="+", help="Explicit matched subset; never establishes the full required matrix")
    args = parser.parse_args()
    reports = [json.loads(path.read_text(encoding="utf-8-sig")) for path in (args.sse, args.polling)]
    result = compare(*reports, selected_clients=args.clients)
    result["sourceCaptureSha256"] = {name: hashlib.sha256(path.read_bytes()).hexdigest()
                                     for name, path in (("sse", args.sse), ("polling", args.polling))}
    args.output_prefix.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    args.output_prefix.with_suffix(".md").write_text(markdown(result), encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("requiredMatrixComplete", "fiveClientNumericalTargetsMet", "requestOrPageErrorEvidenceOpen")}))


if __name__ == "__main__":
    main()
