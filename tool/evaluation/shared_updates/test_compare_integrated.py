from copy import deepcopy
import unittest

from compare_integrated import compare


def capture(mode):
    report = {"status": "complete", "mode": mode, "kind": "integrated-flutter-acceptance", "browser": "test",
              "channel": "chrome", "diagnostics": "reads", "toolSha256": {"runner": "same", "observer": "same"},
              "plan": {"clients": [1, 3, 5, 10], "writesPerView": 3}, "trials": []}
    for count in (1, 3, 5, 10):
        for rep in (1, 2, 3):
            trial = {"clients": count, "repetition": rep, "logicalContexts": count,
                     "status": "complete", "streamsAfterClose": 0, "views": []}
            for view in ("overview", "detail"):
                for workload in ("idle", "writes"):
                    client = {"routes": {"/api/v1/animals": {"getRequests": 0 if mode == "sse" else 10}},
                              "bytes": {"decodedBody": 100 if mode == "sse" else 10000}, "pageErrors": 0,
                              "liveStreamByteCoverage": True, "failures": []}
                    writes = [{"observations": [{"semanticsMs": 100, "screenshotUpperBoundMs": 200,
                                "dataRegionPixelsChanged": True} for _ in range(count)]} for _ in range(3)] if workload == "writes" else []
                    trial["views"].append({"view": view, "workload": workload, "finishedAt": "complete", "wallMs": 120000,
                                           "clients": [deepcopy(client) for _ in range(count)], "writes": writes})
            report["trials"].append(trial)
    return report


class ComparisonTests(unittest.TestCase):
    def test_explicit_subset_is_matched_without_claiming_complete_matrix(self):
        sse, polling = capture("sse"), capture("polling")
        sse["plan"]["clients"] = [5]
        sse["trials"] = [trial for trial in sse["trials"] if trial["clients"] == 5]
        result = compare(sse, polling, selected_clients=[5])
        self.assertFalse(result["requiredMatrixComplete"])
        self.assertTrue(result["fiveClientNumericalTargetsMet"])
        self.assertEqual(len(result["windows"]), 12)
        with self.assertRaisesRegex(ValueError, "Selected clients"):
            compare(sse, polling, selected_clients=[10])

    def test_pinned_binary_and_release_artifact_must_match(self):
        for key in ("browserExecutableSha256", "webArtifact"):
            other = capture("polling"); other[key] = "different"
            with self.assertRaisesRegex(ValueError, key):
                compare(capture("sse"), other)
        sse, polling = capture("sse"), capture("polling")
        for report in (sse, polling): report["webArtifact"] = {"kind": "supplementary-local-Flutter-probe"}
        with self.assertRaisesRegex(ValueError, "probe"):
            compare(sse, polling)

    def test_matched_repetitions_keep_rows_and_reduce_rates(self):
        result = compare(capture("sse"), capture("polling"))
        self.assertTrue(result["requiredMatrixComplete"])
        self.assertTrue(result["fiveClientNumericalTargetsMet"])
        self.assertEqual(len(result["windows"]), 48)
        self.assertFalse(result["requestOrPageErrorEvidenceOpen"])

    def test_unknown_request_event_remains_open_when_numbers_pass(self):
        sse = capture("sse")
        sse["trials"][6]["views"][1]["clients"][0]["failures"] = [{"route": "/api/v1/changes"}]
        result = compare(sse, capture("polling"))
        self.assertTrue(result["fiveClientNumericalTargetsMet"])
        self.assertTrue(result["requestOrPageErrorEvidenceOpen"])

    def test_capture_outlier_is_not_hidden_by_pooling_repetitions(self):
        sse = capture("sse")
        for write in sse["trials"][6]["views"][1]["writes"]:
            for observation in write["observations"]:
                observation["screenshotUpperBoundMs"] = 2500
        self.assertFalse(compare(sse, capture("polling"))["fiveClientNumericalTargetsMet"])

    def test_incomplete_or_different_tools_cannot_form_a_matched_comparison(self):
        for key in ("browser", "diagnostics", "toolSha256", "plan"):
            other = capture("polling"); other[key] = "different"
            with self.assertRaisesRegex(ValueError, key):
                compare(capture("sse"), other)
        other = capture("polling"); other["status"] = "running"
        with self.assertRaisesRegex(ValueError, "completed"):
            compare(capture("sse"), other)


if __name__ == "__main__":
    unittest.main()
