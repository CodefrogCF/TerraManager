import json
import unittest
from summarize_har import summarize

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

