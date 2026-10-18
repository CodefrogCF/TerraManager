"""Derive repeated browser results and independently timestamped Pi process metrics."""
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict
import argparse
import hashlib
import json
import statistics


def instant(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()


def process_window(rows, start, finish, tick_rate):
    selected = sorted((row for row in rows if start <= instant(row['observed_utc']) <= finish),
                      key=lambda row: row['observed_monotonic_seconds'])
    rss = [row['rss_kib'] for row in selected if row.get('memory_available') and row.get('rss_kib') is not None]
    valid = [row for row in selected if all(row.get(key) is not None for key in
             ('cpu_user_ticks', 'cpu_system_ticks', 'start_time_ticks'))]
    cpu_seconds = coverage = 0
    discarded = 0
    spans = []
    if tick_rate:
        for first, last in zip(valid, valid[1:]):
            elapsed = last['observed_monotonic_seconds'] - first['observed_monotonic_seconds']
            delta = last['cpu_user_ticks'] + last['cpu_system_ticks'] - first['cpu_user_ticks'] - first['cpu_system_ticks']
            if elapsed <= 0 or delta < 0 or first['start_time_ticks'] != last['start_time_ticks']:
                discarded += 1
                continue
            cpu_seconds += delta / tick_rate
            coverage += elapsed
            spans.append(elapsed)
    return {'samples': len(selected), 'memoryValidSamples': len(rss),
            'rssMeanKiB': statistics.mean(rss) if rss else None, 'rssMaxKiB': max(rss) if rss else None,
            'cpuValidSamples': len(valid), 'cpuSeconds': cpu_seconds if coverage else None,
            'cpuCounterSpanSeconds': coverage or None,
            'cpuMeanPercentOneCore': cpu_seconds / coverage * 100 if coverage else None,
            'cpuCoverageFractionOfTrial': coverage / (finish-start),
            'discardedCpuPairs': discarded, 'maxCpuProbeGapSeconds': max(spans) if spans else None,
            'processIdentities': sorted({row['start_time_ticks'] for row in valid}),
            'firstObservedUtc': selected[0]['observed_utc'] if selected else None,
            'lastObservedUtc': selected[-1]['observed_utc'] if selected else None}


def resource_window(samples, start, finish, tick_rate):
    processes = defaultdict(list)
    for sample in samples:
        for process in sample.get('processes', []):
            processes[process['container']].append(process)
    result = {'processes': {name: process_window(rows, start, finish, tick_rate) for name, rows in processes.items()}}
    network = sorted((row for row in samples if 'host_interface_bytes' in row and
                      start <= instant(row.get('host_interface_observed_utc', row['utc'])) <= finish),
                     key=lambda row: instant(row.get('host_interface_observed_utc', row['utc'])))
    result['hostInterface'] = None
    if len(network) >= 2:
        deltas = [{key: last['host_interface_bytes'][key] - first['host_interface_bytes'][key] for key in ('rx', 'tx')}
                  for first, last in zip(network, network[1:])]
        span = instant(network[-1].get('host_interface_observed_utc', network[-1]['utc'])) - instant(network[0].get('host_interface_observed_utc', network[0]['utc']))
        if span > 0 and all(value >= 0 for delta in deltas for value in delta.values()):
            total = sum(sum(delta.values()) for delta in deltas)
            result['hostInterface'] = {'samples': len(network), 'counterSpanSeconds': span,
                                       'rxTxBytes': total, 'rxTxBytesPerSecond': total/span}
    return result


def summarize(manifest, samples=(), metadata=None):
    tick_rate = (metadata or {}).get('metadata', {}).get('clock_ticks_per_second')
    rows = []
    for item in manifest['completed']:
        data = item['result']
        rows.append({'number': item['number'], 'repetition': item['repetition'], 'phase': item['phase'], 'mode': item['mode'],
                     'startedAt': data['startedAt'], 'finishedAt': data['finishedAt'],
                     'durationSeconds': data['measuredDurationMs']/1000, 'clients': data['clients'],
                     'fetchStarts': data['requests'], 'writes': data['writes'], 'errors': data['errors'],
                     'missingObservations': data['missingObservations'],
                     'observedChanges': sum(client['observedChanges'] for client in data['clientsDetail']),
                     'expectedChanges': sum(client['expectedChanges'] for client in data['clientsDetail']),
                     'latencyP50Ms': data['writeStartToLabDomP50Ms'], 'latencyP95Ms': data['writeStartToLabDomP95Ms'],
                     'labDomUpdates': data['labDomUpdates'],
                     'httpEncodedBodyBytes': sum(wire['encodedResponseBodyBytes'] for wire in (data.get('wire') or [])),
                     'pi': resource_window(samples, instant(data['startedAt']), instant(data['finishedAt']), tick_rate) if samples else None})
    pairs = []
    for repetition in sorted({row['repetition'] for row in rows}):
        baseline = next((row for row in rows if row['repetition'] == repetition and row['phase'] == 'idle' and row['mode'] == 'polling'), None)
        sse = next((row for row in rows if row['repetition'] == repetition and row['phase'] == 'idle' and row['mode'] == 'sse'), None)
        if baseline and sse:
            pair = {'repetition': repetition}
            for field, name in (('fetchStarts', 'idleFetchReductionPercent'), ('httpEncodedBodyBytes', 'idleHttpBodyReductionPercent')):
                rate = baseline[field]/baseline['durationSeconds']
                pair[name] = 100*(1-sse[field]/sse['durationSeconds']/rate) if rate else None
            pairs.append(pair)
    return {'schema': 1, 'generatedAt': datetime.now(timezone.utc).isoformat(), 'runStatus': manifest['status'],
            'kind': manifest['kind'], 'sourceHead': manifest['sourceHead'], 'plan': manifest['plan'],
            'resourcesLoaded': bool(samples), 'resourceMetadata': metadata, 'trials': rows, 'pairedIdle': pairs,
            'limits': manifest['limits'] + [
                'Per-trial latency values describe correlated client observations; repetitions remain separate.',
                'HTTP body counters exclude headers, TLS/TCP framing and outgoing traffic.',
                'Main-process RSS is not total container/tmpfs memory or an exact instantaneous peak.',
                'Process CPU is cumulative tick delta over the actual covered probe span, not the full configured window.',
                'Discarded reset/restart pairs and coverage are reported; host-interface traffic includes unrelated work.',
            ]}


def markdown(report):
    rows = report['trials']
    lines = ['# Repeated polling/SSE comparison', '',
             f"Run status: {report['runStatus']}; completed windows: {len(rows)}/{len(report['plan']['trials'])}.",
             f"Pi resources loaded: {report['resourcesLoaded']}.", '',
             f"{report['plan']['clients']} logical Chrome contexts, overview workload, {report['plan']['seconds']} seconds/window, {report['plan']['repetitions']} planned repetitions.",
             'Warm disposable lab with alternating order; this is not production SSE or Flutter frame timing.', '',
             '| Trial | Repetition | Workload | Mode | Data GET starts | Writes | Observed / expected | Errors | Lab p95 ms |',
             '| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |']
    for row in rows:
        p95 = row['latencyP95Ms'] if row['latencyP95Ms'] is not None else '-'
        lines.append(f"| {row['number']} | {row['repetition']} | {row['phase']} | {row['mode']} | {row['fetchStarts']} | {row['writes']} | {row['observedChanges']} / {row['expectedChanges']} | {row['errors']} | {p95} |")
    lines += ['', '## Results across repetitions', '',
              '| Workload | Mode | Completed repetitions | Data fetches min / median / max | p95 per repetition ms |',
              '| --- | --- | ---: | --- | --- |']
    for phase in ('idle', 'writes'):
        for mode in ('polling', 'sse'):
            group = [row for row in rows if row['phase'] == phase and row['mode'] == mode]
            if not group: continue
            counts = [row['fetchStarts'] for row in group]
            latencies = [row['latencyP95Ms'] for row in group if row['latencyP95Ms'] is not None]
            lines.append(f"| {phase} | {mode} | {len(group)} | {min(counts)} / {statistics.median(counts):g} / {max(counts)} | {', '.join(map(str, latencies)) or '-'} |")
    lines += ['', '## Paired idle reductions', '',
              '| Repetition | Fewer data fetches | Fewer received HTTP body bytes |', '| --- | ---: | ---: |']
    for pair in report['pairedIdle']:
        lines.append(f"| {pair['repetition']} | {pair['idleFetchReductionPercent']:.3f}% | {pair['idleHttpBodyReductionPercent']:.3f}% |")
    if report['resourcesLoaded']:
        lines += ['', '## Main-process observations', '',
                  '| Trial | Component | RSS max observed MiB | CPU seconds | Covered seconds | CPU mean % of one core | Coverage | Discarded pairs |',
                  '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |']
        def number(value): return f'{value:.3f}' if value is not None else 'unavailable'
        for row in rows:
            for name, process in row['pi']['processes'].items():
                rss = process['rssMaxKiB']/1024 if process['rssMaxKiB'] is not None else None
                lines.append(f"| {row['number']} | {name} | {number(rss)} | {number(process['cpuSeconds'])} | {number(process['cpuCounterSpanSeconds'])} | {number(process['cpuMeanPercentOneCore'])} | {process['cpuCoverageFractionOfTrial']*100:.2f}% | {process['discardedCpuPairs']} |")
        lines += ['', '## Whole-host network observations', '',
                  'WLAN includes production traffic, SSH and diagnostic activity. These are not isolated lab wire bytes.', '',
                  '| Trial | Host RX+TX KiB/s | Counter span seconds | Samples |',
                  '| --- | ---: | ---: | ---: |']
        for row in rows:
            network = row['pi']['hostInterface']
            if network:
                lines.append(f"| {row['number']} | {network['rxTxBytesPerSecond']/1024:.3f} | {network['counterSpanSeconds']:.3f} | {network['samples']} |")
            else:
                lines.append(f"| {row['number']} | unavailable | unavailable | unavailable |")
    lines += ['', '## Limits', ''] + ['- '+limit for limit in report['limits']]
    return '\n'.join(lines)+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--resources', type=Path)
    parser.add_argument('--output-prefix', type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.manifest.read_text(encoding='utf-8-sig'))
    manifest = source.get('manifest', source)
    samples, metadata = [], None
    if args.resources:
        for line in args.resources.read_text(encoding='utf-8-sig').splitlines():
            item = json.loads(line)
            if 'metadata' in item: metadata = item
            elif 'utc' in item: samples.append(item)
    report = summarize(manifest, samples, metadata)
    report['sourceInputSha256'] = hashlib.sha256(args.manifest.read_bytes()).hexdigest()
    if args.resources:
        report['sourceResourcesSha256'] = hashlib.sha256(args.resources.read_bytes()).hexdigest()
    args.output_prefix.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    args.output_prefix.with_suffix('.md').write_text(markdown(report), encoding='utf-8')
    print(json.dumps({'status': report['runStatus'], 'windows': len(report['trials']), 'resourcesLoaded': bool(samples)}))


if __name__ == '__main__': main()
