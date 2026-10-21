import unittest
from datetime import datetime, timezone

from analyze_integrated_soak import summarize


def utc(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat()


def fixture():
    clock = {"samples": [{"offsetLowerMs": 0, "offsetUpperMs": 0}]}
    report = {"kind": "integrated-flutter-tab-reopen-soak", "method": "explicit-tab-reopen",
              "status": "complete", "startedAt": utc(0), "plannedFinishedAt": utc(1800),
              "clockBefore": clock, "clockAfter": clock,
              "reopens": [{"completedAt": utc(i * 15), "newConfirmedConnections": 1} for i in range(1, 102)],
              "streamSamples": [{"streams": 5}, {"streams": 0}], "clients": []}
    samples = [{"utc": utc(t), "processes": [{"container": "lab", "observed_utc": utc(t),
                "memory_available": True, "rss_kib": 110 if t >= 1200 else 100,
                "start_time_ticks": 1, "cpu_user_ticks": 0, "cpu_system_ticks": 0}]} for t in range(-5, 1810, 5)]
    return report, samples, {"metadata": {"clock_ticks_per_second": 100}}


class SoakSummaryTests(unittest.TestCase):
    def test_ten_minute_medians_and_exact_ten_percent_growth(self):
        report, samples, header = fixture()
        result = summarize(report, samples, header)
        process = result["processes"]["lab"]
        self.assertEqual(result["actualReopensInsideFixedWindow"], 101)
        self.assertTrue(result["durationAndReopenThresholdsMet"])
        self.assertAlmostEqual(process["warmMedianGrowthPercent"], 10)
        self.assertEqual(process["growthAssessment"], "within-10-percent-investigation-threshold")

    def test_restart_prevents_a_memory_growth_claim(self):
        report, samples, header = fixture()
        for sample in samples:
            if sample["utc"] >= utc(900):
                sample["processes"][0]["start_time_ticks"] = 2
        process = summarize(report, samples, header)["processes"]["lab"]
        self.assertIsNone(process["warmMedianGrowthPercent"])
        self.assertFalse(process["stableIdentity"])

    def test_missing_final_coverage_stays_unavailable(self):
        report, samples, header = fixture()
        samples = samples[:-10]
        process = summarize(report, samples, header)["processes"]["lab"]
        self.assertIsNone(process["warmMedianGrowthPercent"])
        self.assertFalse(process["finalWarmTenMinutes"]["coveredAtFiveSecondCadence"])

    def test_late_reopen_does_not_count_and_large_growth_needs_investigation(self):
        report, samples, header = fixture()
        report["reopens"][-2:] = [{"completedAt": utc(1801), "newConfirmedConnections": 9}]
        for sample in samples:
            if sample["utc"] >= utc(1200):
                sample["processes"][0]["rss_kib"] = 125
        result = summarize(report, samples, header)
        self.assertEqual(result["actualReopensInsideFixedWindow"], 99)
        self.assertFalse(result["durationAndReopenThresholdsMet"])
        self.assertEqual(result["processes"]["lab"]["growthAssessment"], "investigate-over-10-percent")


if __name__ == "__main__":
    unittest.main()
