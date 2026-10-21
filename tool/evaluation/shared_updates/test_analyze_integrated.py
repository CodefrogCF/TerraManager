import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from datetime import datetime, timezone

from analyze_integrated import budget_status, cpu_bounds, load_resource_inputs, frame_summary


def probe(seconds, ticks, identity=1):
    return {"observed_utc": datetime.fromtimestamp(seconds, timezone.utc).isoformat(),
            "cpu_user_ticks": ticks, "cpu_system_ticks": 0, "start_time_ticks": identity,
            "collection_duration_seconds": 0}


class CpuBoundsTests(unittest.TestCase):
    def test_missing_frames_are_distinct_from_instrumented_idle_zero(self):
        self.assertIsNone(frame_summary(None))
        empty = frame_summary({"frameElapsedMicroseconds": [], "droppedSamples": 0})
        self.assertEqual(empty["samples"], 0)
        self.assertIsNone(empty["p95ElapsedMicroseconds"])
        legacy = frame_summary({"frameCpuMicroseconds": [100, 300, 200], "droppedSamples": 0})
        self.assertEqual(legacy["p95ElapsedMicroseconds"], 300)
        self.assertIn("not-OS-CPU", legacy["interpretation"])
        with self.assertRaisesRegex(ValueError, "frame"):
            frame_summary({"frameElapsedMicroseconds": [-1]})

    def test_initial_write_burst_is_in_upper_bound_even_when_inner_span_is_zero(self):
        rows = [probe(-1, 0), probe(1, 10), probe(9, 10), probe(11, 10)]
        result = cpu_bounds(rows, 0, 10, 100)
        self.assertEqual(result["lowerPercentOneCore"], 0)
        self.assertAlmostEqual(result["upperPercentOneCore"], 1.2)
        self.assertEqual(result["outerCounterSpanSeconds"], 12)
        self.assertEqual(budget_status(result, .1), "inconclusive-at-this-resolution")

    def test_missing_surrounding_probe_is_unavailable_not_zero(self):
        result = cpu_bounds([probe(1, 0), probe(9, 0)], 0, 10, 100)
        self.assertIsNone(result["upperPercentOneCore"])
        self.assertEqual(result["unavailableReason"], "missing-surrounding-probes")

    def test_restart_cannot_bridge_counters(self):
        result = cpu_bounds([probe(-1, 0), probe(1, 5), probe(9, 2, 2), probe(11, 3, 2)], 0, 10, 100)
        self.assertIsNone(result["upperPercentOneCore"])
        self.assertEqual(result["unavailableReason"], "process-restarted")

    def test_counter_regression_is_rejected(self):
        result = cpu_bounds([probe(-1, 10), probe(1, 8), probe(9, 9), probe(11, 11)], 0, 10, 100)
        self.assertEqual(result["unavailableReason"], "cpu-counter-regressed")

    def test_clock_range_and_probe_uncertainty_need_wider_outer_endpoints(self):
        rows = [probe(-2, 0), probe(-.05, 1), probe(1, 2), probe(9, 3), probe(10.05, 4), probe(12, 5)]
        result = cpu_bounds(rows, 0, 10, 100, offset=(-.1, .1), guard=.1)
        self.assertEqual(result["outerCounterSpanSeconds"], 14)
        self.assertAlmostEqual(result["upperPercentOneCore"], .7)

    def test_short_zero_tick_window_cannot_automatically_pass_idle_budget(self):
        short = cpu_bounds([probe(-1, 0), probe(1, 0), probe(9, 0), probe(11, 0)], 0, 10, 100)
        self.assertEqual(budget_status(short, .1), "inconclusive-at-this-resolution")
        long = cpu_bounds([probe(-1, 0), probe(1, 0), probe(119, 0), probe(121, 0)], 0, 120, 100)
        self.assertEqual(budget_status(long, .1), "within-conservative-bound")


class ResourceJoinTests(unittest.TestCase):
    def write_capture(self, path, rows, tick_rate=100):
        header = {"metadata": {"clock_ticks_per_second": tick_rate, "machine": "aarch64"}}
        path.write_text("\n".join(json.dumps(row) for row in [header, *rows]) + "\n", encoding="utf-8")
        return path

    def test_overlapping_collectors_union_observations_without_summing_ticks(self):
        with TemporaryDirectory() as folder:
            rows = [{"utc": probe(t, t)["observed_utc"], "processes": [probe(t, t)]} for t in (0, 5, 10, 15)]
            a = self.write_capture(Path(folder) / "first.jsonl", rows[:3])
            b = self.write_capture(Path(folder) / "next.jsonl", rows[1:])
            header, samples, partial, sources = load_resource_inputs([a, b])
            self.assertEqual(header["metadata"]["clock_ticks_per_second"], 100)
            self.assertEqual(len(samples), 4)
            self.assertEqual(partial, 0)
            self.assertEqual(sources[1]["overlapSecondsWithEarlierInputs"], 5)
            self.assertEqual([row["processes"][0]["cpu_user_ticks"] for row in samples], [0, 5, 10, 15])

    def test_different_tick_rate_cannot_be_silently_combined(self):
        with TemporaryDirectory() as folder:
            a = self.write_capture(Path(folder) / "first.jsonl", [])
            b = self.write_capture(Path(folder) / "next.jsonl", [], tick_rate=250)
            with self.assertRaisesRegex(ValueError, "different host/tick"):
                load_resource_inputs([a, b])

    def test_conflicting_duplicate_observation_is_rejected(self):
        with TemporaryDirectory() as folder:
            row = {"utc": probe(0, 0)["observed_utc"], "processes": [probe(0, 0)]}
            a = self.write_capture(Path(folder) / "first.jsonl", [row])
            b = self.write_capture(Path(folder) / "next.jsonl", [{**row, "processes": [probe(0, 9)]}])
            with self.assertRaisesRegex(ValueError, "Conflicting"):
                load_resource_inputs([a, b])


if __name__ == "__main__":
    unittest.main()
