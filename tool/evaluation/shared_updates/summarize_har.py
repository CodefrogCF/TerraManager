"""Summarize real Shared Care HAR traffic without copying bodies, headers or secrets."""
import argparse
import collections
import datetime
import json
import math
import re
from pathlib import Path
from urllib.parse import urlsplit

def summarize(document, observation_seconds=None):
    if observation_seconds is not None and (not math.isfinite(observation_seconds) or observation_seconds <= 0):
        raise ValueError('The explicit observation window must be positive and finite')
    routes = collections.defaultdict(lambda: {
        "requests": 0, "statuses": {}, "known_body_bytes": 0,
        "unknown_body_sizes": 0, "durations_ms": [],
    })
    times = []
    for entry in document.get("log", {}).get("entries", []):
        request = entry.get("request", {})
        parsed = urlsplit(request.get("url", ""))
        if not parsed.path.startswith("/api/v1/"):
            continue
        # Allowlisted route tokens only. Never emit URLs, IDs, usernames,
        # query strings, request/response bodies, cookies or HTTP headers.
        parts = parsed.path.split("/")[3:]
        allowed = {"boxes", "animals", "feedings", "reminders", "media", "pictures",
                   "weights", "shedding", "feeding-reminder", "auth", "session",
                   "login", "logout", "preferences", "admin", "accounts", "audit",
                   "backups", "restore", "restore-status", "health", "duplicate",
                   "archive", "scan"}
        route = "/api/v1/" + "/".join(
            ":id" if part.isdigit() else part if part in allowed else ":other"
            for part in parts
        )
        method = request.get("method", "")
        method = method if method in {"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"} else "OTHER"
        item = routes[method + " " + route]
        item["requests"] += 1
        response = entry.get("response", {})
        status_value = response.get("status", 0)
        status = str(status_value) if type(status_value) is int and 0 <= status_value <= 599 else "unknown"
        item["statuses"][status] = item["statuses"].get(status, 0) + 1
        size = response.get("bodySize", -1)
        if isinstance(size, (int, float)) and size >= 0:
            item["known_body_bytes"] += size
        else:
            item["unknown_body_sizes"] += 1
        duration = entry.get("time")
        if isinstance(duration, (int, float)) and math.isfinite(duration) and duration >= 0:
            item["durations_ms"].append(duration)
        try:
            start = datetime.datetime.fromisoformat(entry["startedDateTime"].replace("Z", "+00:00"))
            times.append(start.timestamp())
            if isinstance(duration, (int, float)) and math.isfinite(duration) and duration >= 0:
                times.append(start.timestamp() + duration / 1000)
        except (KeyError, TypeError, ValueError):
            pass
    seconds = max(times) - min(times) if len(times) >= 2 else 0
    for item in routes.values():
        durations = sorted(item.pop("durations_ms"))
        item["request_duration_p95_ms"] = durations[math.ceil(len(durations) * .95) - 1] if durations else None
        item["requests_per_minute"] = item["requests"] * 60 / observation_seconds if observation_seconds else None
    return {
        "schema": 1, "capture_span_seconds": seconds,
        "explicit_observation_seconds": observation_seconds,
        "requests": sum(item["requests"] for item in routes.values()),
        "routes": dict(sorted(routes.items())),
        "limits": [
            "Real API traffic from the supplied HAR; no inferred UI propagation latency or Flutter rebuild count.",
            "Body sizes are HAR response.bodySize; unknown sizes remain unknown. TLS/TCP overhead is excluded.",
            "Rates require an explicit observation window; the first-to-last-response span is diagnostic only.",
            "Keep the original HAR private: it may contain session cookies and personal data.",
        ],
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("har", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--window-seconds", type=float,
                        help="Known capture duration; rates remain null if omitted")
    args = parser.parse_args()
    report = summarize(json.loads(args.har.read_text(encoding="utf-8-sig")), args.window_seconds)
    with args.output.open("x", encoding="utf-8") as output:
        json.dump(report, output, indent=2)
        output.write("\n")

if __name__ == "__main__":
    main()

