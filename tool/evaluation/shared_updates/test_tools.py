import json
import unittest
from unittest.mock import patch
import subprocess
from summarize_har import summarize
from sample_resources import parse_process_snapshot, process_snapshot, next_deadline, sample


class ProcessResourceTests(unittest.TestCase):
    @staticmethod
    def fixture(status="VmRSS:\t190192 kB\nVmHWM:\t200000 kB\nThreads:\t4\n"):
        fields = ["S"] + ["0"] * 21
        fields[11], fields[12], fields[19] = "1234", "567", "987654"
        return "1 (worker name (test)) " + " ".join(fields) + "\n" + status

    def test_process_name_parentheses_do_not_shift_cpu_or_identity(self):
        result = parse_process_snapshot(self.fixture())
        self.assertEqual((result["cpu_user_ticks"], result["cpu_system_ticks"]), (1234, 567))
        self.assertEqual(result["start_time_ticks"], 987654)
        self.assertEqual(result["rss_kib"], 190192)
        self.assertEqual(result["high_water_kib"], 200000)
        self.assertEqual(result["threads"], 4)

    def test_missing_memory_is_unavailable_not_zero(self):
        result = parse_process_snapshot(self.fixture("Threads:\t4\n"))
        self.assertFalse(result["memory_available"])
        self.assertIsNone(result["rss_kib"])
        self.assertEqual(result["cpu_user_ticks"], 1234)

    def test_invalid_records_and_units_are_rejected(self):
        for text in ("1 (incomplete) S", self.fixture("VmRSS:\t7 MB\n"), self.fixture("VmRSS:\t-1 kB\n")):
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_process_snapshot(text)

    @patch("sample_resources.subprocess.run", side_effect=subprocess.TimeoutExpired("docker", 10))
    def test_probe_failure_is_recorded_without_fake_memory_or_stderr(self, run):
        result = process_snapshot("test-container")
        self.assertFalse(result["memory_available"])
        self.assertIsNone(result["rss_kib"])
        self.assertEqual(result["error"], "TimeoutExpired")
        self.assertNotIn("stdout", result)

    @patch("sample_resources.process_snapshot", return_value={"rss_kib": 123})
    @patch("sample_resources.subprocess.run", side_effect=subprocess.CalledProcessError(1, "docker"))
    def test_process_probe_survives_unavailable_docker_stats(self, run, probe):
        result = sample(["test-container"], process_stats=True)
        self.assertEqual(result["processes"][0]["rss_kib"], 123)
        self.assertEqual(result["docker_stats_error"], "CalledProcessError")

    def test_fixed_cadence_skips_overruns_without_catch_up(self):
        self.assertEqual(next_deadline(0, 5, 2), (5, 0))
        self.assertEqual(next_deadline(0, 5, 12), (15, 2))

class HarTests(unittest.TestCase):
    def test_rates_use_the_explicit_window_including_idle_time(self):
        document = {"log": {"entries": [{
            "startedDateTime": "2026-10-17T10:00:00Z", "time": 100,
            "request": {"url": "https://server/api/v1/boxes", "method": "GET"},
            "response": {"status": 200, "bodySize": 12},
        }]}}
        automatic = summarize(document)
        self.assertIsNone(automatic["routes"]["GET /api/v1/boxes"]["requests_per_minute"])
        explicit = summarize(document, 60)
        self.assertEqual(explicit["routes"]["GET /api/v1/boxes"]["requests_per_minute"], 1)
        with self.assertRaises(ValueError):
            summarize(document, float('nan'))

    def test_secrets_and_personal_values_are_not_emitted(self):
        report = summarize({"log": {"entries": [{
            "startedDateTime": "2026-10-17T10:00:00Z", "time": 100,
            "request": {"url": "https://private-host/api/v1/animals/42?secret=PASSWORD",
                        "method": "GET", "cookies": [{"value": "SESSION"}]},
            "response": {"status": 200, "bodySize": 123,
                         "content": {"text": "PRIVATE ANIMAL NAME"}},
        }]}})
        text = json.dumps(report)
        for private in ("private-host", "PASSWORD", "SESSION", "PRIVATE ANIMAL NAME", "animals/42"):
            self.assertNotIn(private, text)
        self.assertEqual(report["routes"]["GET /api/v1/animals/:id"]["known_body_bytes"], 123)

    def test_unknown_sizes_remain_unknown_and_external_assets_are_ignored(self):
        report = summarize({"log": {"entries": [
            {"request": {"url": "https://server/api/v1/boxes", "method": "GET"},
             "response": {"status": 200, "bodySize": -1}},
            {"request": {"url": "https://server/main.dart.js", "method": "GET"},
             "response": {"status": 200, "bodySize": 999}},
        ]}})
        self.assertEqual(report["requests"], 1)
        self.assertEqual(report["routes"]["GET /api/v1/boxes"]["unknown_body_sizes"], 1)
        self.assertIsNone(report["routes"]["GET /api/v1/boxes"]["requests_per_minute"])

    def test_unsafe_route_segments_and_unknown_methods_are_redacted(self):
        report = summarize({"log": {"entries": [{
            "request": {"url": "https://server/api/v1/admin/accounts/private-username",
                        "method": "PRIVATE-METHOD"},
            "response": {"status": "PRIVATE-STATUS", "bodySize": 0},
        }]}})
        self.assertIn("OTHER /api/v1/admin/accounts/:other", report["routes"])
        self.assertNotIn("PRIVATE-STATUS", json.dumps(report))

if __name__ == "__main__":
    unittest.main()

