import unittest
from analyze_sse_comparison import process_window, resource_window


def process(second, ticks, identity=7, rss=100):
    return {'container': 'lab', 'observed_utc': f'2026-10-17T22:00:{second:02d}Z',
            'observed_monotonic_seconds': second, 'cpu_user_ticks': ticks,
            'cpu_system_ticks': 0, 'start_time_ticks': identity,
            'rss_kib': rss, 'memory_available': rss is not None}


START = 1792274400  # 2026-10-17 22:00:00 UTC


class ProcessWindowTests(unittest.TestCase):
    def test_cpu_uses_observed_span_not_whole_trial(self):
        result = process_window([process(1, 10), process(6, 110)], START, START+10, 100)
        self.assertEqual(result['cpuSeconds'], 1)
        self.assertEqual(result['cpuCounterSpanSeconds'], 5)
        self.assertEqual(result['cpuMeanPercentOneCore'], 20)
        self.assertEqual(result['cpuCoverageFractionOfTrial'], .5)

    def test_restart_pair_is_discarded_instead_of_subtracting_counters(self):
        result = process_window([process(1, 500), process(6, 3, 8), process(11, 53, 8)], START, START+15, 100)
        self.assertEqual(result['cpuSeconds'], .5)
        self.assertEqual(result['discardedCpuPairs'], 1)
        self.assertEqual(result['cpuCounterSpanSeconds'], 5)
        self.assertEqual(result['processIdentities'], [7, 8])

    def test_counter_regression_does_not_report_negative_usage(self):
        result = process_window([process(1, 500), process(6, 3)], START, START+10, 100)
        self.assertIsNone(result['cpuSeconds'])
        self.assertIsNone(result['cpuMeanPercentOneCore'])
        self.assertEqual(result['discardedCpuPairs'], 1)

    def test_valid_zero_cpu_and_unavailable_ram_remain_distinct(self):
        result = process_window([process(1, 10, rss=None), process(6, 10, rss=None)], START, START+10, 100)
        self.assertEqual(result['cpuSeconds'], 0)
        self.assertEqual(result['cpuMeanPercentOneCore'], 0)
        self.assertIsNone(result['rssMaxKiB'])

    def test_process_timestamp_is_used_instead_of_outer_docker_timestamp(self):
        rows = [{'utc': '2026-10-17T21:59:55Z', 'processes': [process(1, 0)]},
                {'utc': '2026-10-17T21:59:59Z', 'processes': [process(6, 100)]}]
        result = resource_window(rows, START, START+10, 100)
        self.assertEqual(result['processes']['lab']['cpuSeconds'], 1)

    def test_interface_counter_reset_is_not_reported_as_negative_bandwidth(self):
        rows = [{'utc': '2026-10-17T22:00:01Z', 'host_interface_bytes': {'rx': 100, 'tx': 100}},
                {'utc': '2026-10-17T22:00:06Z', 'host_interface_bytes': {'rx': 0, 'tx': 0}}]
        self.assertIsNone(resource_window(rows, START, START+10, 100)['hostInterface'])


if __name__ == '__main__': unittest.main()
