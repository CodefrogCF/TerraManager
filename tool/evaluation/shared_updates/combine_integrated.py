"""Compose disjoint completed trial sets while preserving their execution provenance."""
import argparse
from copy import deepcopy
from datetime import datetime
import hashlib
import json
from pathlib import Path

from compare_integrated import windows


def instant(value):
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("Capture timestamps must include a timezone")
    return result


def combine(reports, sources):
    if len(reports) < 2 or len(reports) != len(sources):
        raise ValueError("Provide at least two captures and their provenance")
    first = reports[0]
    stable = ("schema", "kind", "browser", "mode", "channel", "diagnostics",
              "browserExecutableSha256", "webArtifact", "controller", "toolSha256")
    if first.get("kind") != "integrated-flutter-acceptance" or first.get("webArtifact", {}).get("kind") != "gateway-production-release":
        raise ValueError("Expected production Flutter captures")
    if first.get("mode") not in ("sse", "polling"):
        raise ValueError("Unexpected capture mode")
    if not first.get("toolSha256") or not first.get("browserExecutableSha256"):
        raise ValueError("Missing browser/tool provenance")
    shared_plan = {k: v for k, v in first["plan"].items() if k != "clients"}
    repetitions = shared_plan.get("repetitions")
    if type(repetitions) is not int or repetitions < 1:
        raise ValueError("Invalid repetition plan")
    clients, trials, seen, blocks = [], [], set(), []
    for report, source in zip(reports, sources):
        for key in stable:
            if key not in report or report[key] != first.get(key):
                raise ValueError("Capture inputs differ in " + key)
        if "composition" in report:
            raise ValueError("Use raw captures, not nested compositions")
        if {k: v for k, v in report["plan"].items() if k != "clients"} != shared_plan:
            raise ValueError("Capture inputs differ in plan")
        declared = report["plan"]["clients"]
        if not declared or len(declared) != len(set(declared)) or any(type(n) is not int or n < 1 for n in declared):
            raise ValueError("Invalid client plan")
        if instant(report["completedAt"]) < instant(report["createdAt"]):
            raise ValueError("Invalid capture time bounds")
        actual_windows = windows(report, first["mode"])
        expected = {(n, rep, view, work) for n in declared for rep in range(1, repetitions + 1)
                    for view in ("overview", "detail") for work in ("idle", "writes")}
        if actual_windows.keys() != expected:
            raise ValueError("Incomplete declared capture matrix")
        for trial in report["trials"]:
            key = (trial["clients"], trial["repetition"])
            if key in seen:
                raise ValueError("Duplicate client/repetition trial")
            seen.add(key)
            trials.append(deepcopy(trial))
        clients.extend(n for n in declared if n not in clients)
        blocks.append({**deepcopy(source), "createdAt": report["createdAt"],
                       "completedAt": report["completedAt"], "plan": deepcopy(report["plan"]),
                       "trialKeys": [[t["clients"], t["repetition"]] for t in report["trials"]]})
    result = deepcopy(first)
    result["createdAt"] = min(reports, key=lambda r: instant(r["createdAt"]))["createdAt"]
    result["completedAt"] = max(reports, key=lambda r: instant(r["completedAt"]))["completedAt"]
    result["plan"]["clients"] = clients
    result["trials"] = trials
    result["composition"] = {
        "kind": "disjoint-completed-trial-union", "sources": blocks,
        "limits": [
            "This is a composition of separate captures, not one continuous experiment.",
            "The clients plan lists the union; it does not describe global execution order.",
            "Each original trial, timestamp, repetition and observation is retained unchanged.",
            "Read source timestamps and the separate image-switch record for experiment mode order.",
            "Different days, warm-up and batched mode order remain possible confounds."]}
    result["limits"] = list(dict.fromkeys(limit for report in reports for limit in report["limits"])) + result["composition"]["limits"]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", type=Path, nargs="+")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reports = [json.loads(path.read_text(encoding="utf-8-sig")) for path in args.captures]
    sources = [{"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
               for path in args.captures]
    result = combine(reports, sources)
    with args.output.open("x", encoding="utf-8") as output:
        output.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"sourceCaptures": len(reports), "trials": len(result["trials"]),
                      "clients": result["plan"]["clients"]}))


if __name__ == "__main__":
    main()
