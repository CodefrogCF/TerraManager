from copy import deepcopy
import unittest

from combine_integrated import combine
from compare_integrated import compare
from test_compare_integrated import capture


def raw(clients):
    report = capture("sse")
    report.update(schema=1, browserExecutableSha256="pinned", controller={"node": "same"},
                  webArtifact={"kind": "gateway-production-release"}, limits=["Original limit"],
                  createdAt="2026-10-18T20:00:00Z", completedAt="2026-10-18T21:00:00Z")
    report["plan"].update(clients=clients, repetitions=3)
    report["trials"] = [t for t in report["trials"] if t["clients"] in clients]
    return report


class CompositionTests(unittest.TestCase):
    sources = [{"file": "first.json", "sha256": "a"}, {"file": "next.json", "sha256": "b"}]

    def test_union_preserves_outliers_trials_and_separate_execution_blocks(self):
        first, next_run = raw([5]), raw([1, 3, 10])
        next_run.update(createdAt="2026-10-19T09:00:00Z", completedAt="2026-10-19T10:15:00Z")
        for write in first["trials"][0]["views"][1]["writes"]:
            for observation in write["observations"]:
                observation["screenshotUpperBoundMs"] = 2500
        original = deepcopy([first, next_run])
        result = combine([first, next_run], self.sources)
        self.assertEqual([first, next_run], original)
        self.assertEqual(result["trials"], first["trials"] + next_run["trials"])
        self.assertEqual(result["plan"]["clients"], [5, 1, 3, 10])
        self.assertEqual(result["completedAt"], next_run["completedAt"])
        self.assertEqual(result["composition"]["sources"][1]["plan"]["clients"], [1, 3, 10])
        polling = raw([5, 1, 3, 10]); polling["mode"] = "polling"
        for trial in polling["trials"]:
            for window in trial["views"]:
                for client in window["clients"]:
                    client["routes"]["/api/v1/animals"]["getRequests"] = 10
                    client["bytes"]["decodedBody"] = 10000
        comparison = compare(result, polling)
        self.assertTrue(comparison["requiredMatrixComplete"])
        self.assertFalse(comparison["fiveClientNumericalTargetsMet"])

    def test_duplicates_and_missing_declared_windows_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            combine([raw([5]), raw([5])], self.sources)
        other = raw([1, 3, 10]); other["trials"].pop()
        with self.assertRaisesRegex(ValueError, "Incomplete declared"):
            combine([raw([5]), other], self.sources)

    def test_browser_tools_controller_and_workload_must_not_drift(self):
        for key in ("browser", "browserExecutableSha256", "toolSha256", "controller", "mode", "webArtifact"):
            other = raw([1]); other[key] = "different"
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, key):
                combine([raw([5]), other], self.sources)
        other = raw([1]); other["plan"]["writesPerView"] = 6
        with self.assertRaisesRegex(ValueError, "plan"):
            combine([raw([5]), other], self.sources)

    def test_incomplete_and_nested_captures_are_rejected(self):
        for field, value, error in (("status", "running", "completed"),
                                    ("composition", {}, "nested")):
            other = raw([1]); other[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, error):
                combine([raw([5]), other], self.sources)
        other = raw([1]); other["trials"][0]["streamsAfterClose"] = 1
        with self.assertRaisesRegex(ValueError, "streams retained"):
            combine([raw([5]), other], self.sources)


if __name__ == "__main__":
    unittest.main()
