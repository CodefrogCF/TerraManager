# Issue #230: physical browser checks

Status: **foreground updates, background/resume, network recovery, multiple tabs,
draft/conflict, disconnected writes, account deactivation/reactivation and both
restore outcomes confirmed by the operator on 2026-10-19; natural twelve-hour
expiry, renewed login and automatic updates confirmed on 2026-10-21. S22 Firefox is excluded from trusted-HTTPS acceptance by the operator**. Automatic captures
are complete and the current SSE web image is restored. The disposable stack is
on port 8443. Keep the production stack on 443
outside this test. Use synthetic fixture records and the privately supplied
accounts. Do not paste account secrets, cookies, original HAR or personal backup
files into this report.

The [German operator checklist](shared-care-integrated-operator-checks-de.md)
provides concrete device/account grouping and staged steps. The current source
defines a twelve-hour session lifetime. Test natural expiry separately from
forced account revocation and from restore, which can invalidate sessions.

Use private browser windows or a dedicated test profile for port 8443, separate
from ordinary production tabs on the same IP. Both stacks use the host cookie
`__Host-TerraManagerSession`; cookie scope does not isolate ports. A test login
in the same cookie jar can replace the production login. The automatic helpers
already create separate Playwright contexts. Background checks must keep the
chosen private tab open. See [RFC 6265, section 8.5](https://httpwg.org/specs/rfc6265.html).

## Inventory and conditions

The operator has three Android devices with Firefox/Brave and a Windows laptop
with Firefox, Chrome and Edge. Record exact versions and certificate trust before
claiming coverage. A trusted HTTPS connection is required; a bypassed certificate
warning is not evidence for this gate.

| Client | Device model | OS version | Browser/version | HTTPS trusted | Result |
| --- | --- | --- | --- | --- | --- |
| Android A | Samsung Galaxy S25 Ultra | Android 16 | Brave 1.97.57; Firefox 158.0; Chrome 155.0.8059.79 | Brave warning-free, operator reported | Requested Brave functional checks pass; restore group confirmed; other browsers not tested |
| Android B | Samsung Galaxy S22 | Android 16 | Brave 1.97.56; Firefox 157.0.1; Chrome 155.0.8059.39 | Firefox warning bypassed; excluded from trusted-HTTPS acceptance by operator | Earlier Firefox foreground, resume and recovery pass under the certificate exception; excluded from restore group; other browsers not tested |
| Laptop A | model pending | Windows 11 | Chrome 155.0.8059.85 | warning-free, operator reported | Requested functional/administration/restore group confirmed |
| Laptop B | same laptop | Windows 11 | Firefox 158.0 (64-Bit) | warning-free, operator reported | Foreground, tabs, conflict and restore group confirmed |
| Laptop C | same laptop | Windows 11 | Edge 155.0.4283.62 | warning-free, operator reported | Foreground and restore group confirmed |
| Android C, optional | pending | pending | pending | pending | not run |

Android versions above were reported by the operator. Chrome .85, Edge
155.0.4283.62 and Firefox 158.0 were read from the installed executable version
metadata on the Windows controller on 2026-10-19. This verifies installation,
not physical test outcomes or the browser used on a different laptop. Confirm
the inventory if the operator uses another computer. The foreground result below
was reported in response to the requested five-client setup; the operator did
not restate individual versions or per-client view allocation. Use one foreground
browser per Android device and three visible laptop browser windows. This is five
clients on three physical devices. Alternatively use the
third Android device after recording its inventory. Repeat selected checks in
both Firefox and Brave on each available Android device if that additional
coverage is later requested. Those combinations have not been run. Record the actual
device/browser for every case. Keep tab/account counts below the server's
eight-stream/account and 32-stream/total bounds.

## Recorded operator outcome: foreground updates

Recorded **2026-10-19 09:47:26 UTC**; exact execution time was not supplied.
The [structured report](data/shared-care-integrated-physical-2026-10-19.json)
retains the user's statement and the requested setup. The operator confirmed
that everything worked and that the Animal name changed on the other clients
without reloading. This passes the manual foreground propagation case under
the requested setup. Expected markers were `TM230-G1` / `TM230-G2`; the reply
did not list the markers individually.

No numerical latency is inferred. HTTPS trust was not separately restated in
this first reply; the later trust report below qualifies the S22 observations.
Further account and restore outcomes follow below.

## Recorded operator outcome: resume and network recovery

Recorded **2026-10-19 09:52:24 UTC**; exact execution times were not supplied.
In response to the requested S25 Ultra / Brave and S22 / Firefox procedures,
the operator confirmed that the checks work. After the simulated interruption,
the changed name became visible after **approximately ten seconds, without
manual reload**. The structured report preserves the original statement.

This is an operator estimate for the requested test group, not a measured
per-device distribution or p95. The response does not separately describe the
connection indicator, OS tab discard/automatic reload behavior, or whether
authoritative state arrived through SSE or conditional fallback. Background
resume and functional outage recovery pass under the reported setup. The
two-second primary update target applies to already-connected clients. Outage
recovery is a separate scenario; no recovery percentile was measured.

Those recovery checks were followed by the draft/tab outcomes below.

## Recorded operator outcome: tabs, conflict and disconnected save

Recorded **2026-10-19 09:58:24 UTC**; exact execution times were not supplied.
In response to the three requested procedures, the operator confirmed that
everything worked as expected: two tabs update without reloading, outdated data
is flagged and missing connectivity does not overwrite data. This passes the
reported functional checks for same-browser tabs, retained draft/conflict and
disconnected-write feedback under the requested setup.

The setup was Windows Firefox (two tabs and draft), Windows Chrome (concurrent
writer), and S25 Ultra / Brave (disconnected save). The operator did not restate
each draft value, exact message or button sequence. The structured report keeps
those limits rather than inventing a screen recording or network trace.

## Recorded operator outcome: account revocation

Recorded **2026-10-19 10:03:20 UTC**; exact execution time was not supplied.
The operator confirmed that disabling and reactivating a caregiver works as
expected in the requested procedure. The exact caregiver, mobile client, message
and individual login attempts were not restated. This passes the reported
functional revocation/reactivation case; it does not test natural twelve-hour
session expiry.

## HTTPS qualification and explicit S22 exclusion

In the same reply, the operator reported that only S22 Firefox displayed a
certificate warning, which was bypassed. S25/Brave and the three requested
Windows browsers were therefore reported warning-free. The operator subsequently
confirmed that the TerraManager LAN Root CA is not installed on the S22 and chose
to **exclude S22 Firefox from trusted-HTTPS acceptance for now**. No Android CA or
Firefox trust setting was changed. Its earlier functional results remain valid
as operator observations with a certificate exception; they are not a trusted
HTTPS pass. The later restore procedure excludes that client.

The controller's separate [read-only TLS inspection](data/shared-care-integrated-tls-inspection-2026-10-19.json)
returned HTTP 200 with certificate and IP-name verification against the existing
public LAN CA, using TLS 1.3. It verifies the gateway certificate from that
controller, not the S22 trust store. No account credentials were used in this
inspection. The four warning-free clients remain the physical trusted-HTTPS
group; the original five-client functional group includes the stated exception.

## Recorded operator outcome: rejected and successful restore

Recorded **2026-10-19T10:14:19.096618+00:00**; exact execution times were not supplied.
The operator answered “alles funktioniert wie erwartet” to the two-part restore
procedure, using S25/Brave and Windows Chrome/Firefox/Edge on port 8443. First,
restoring valid backup A with a safety grant made stale by a subsequent change
was expected to be rejected, retaining name B and an unsaved mobile draft.
Second, after downloading a fresh safety backup B in the same administrator
settings view, restoring the earlier A backup was expected to succeed and update
clean observing views automatically. Both requested functional procedures are
confirmed by the operator.

The response does not separately supply the rejection message, individual marker
values, or reload/login observations. It is not an independent network trace or
measurement of the internal epoch. No backup or credentials are published.

## Recorded operator outcome: natural expiry and renewed login

On 2026-10-21 the operator confirmed that the session ended automatically after
twelve hours and the login screen appeared without manual reload, despite an
edit shortly before expiry. The reported fresh login was 2026-10-20 at 21:19
Europe/Berlin; expected expiry was approximately 2026-10-21 at 09:19. The exact
transition second was not measured. The requested setup was the Windows Firefox
test profile with a caregiver at port 8443. This is the operator's observation,
not a captured network trace or screen recording.

The operator then confirmed renewed login directly from that screen and resumed
automatic name changes from another client, following the requested procedure
without manual reload. The structured report retains both original replies.

## Final acceptance boundary

The physical functional cases are complete. The [final acceptance report](shared-care-integrated-acceptance-2026-10-21.md)
combines them with the measured matrix, soak and accepted resource budgets.
S22 Firefox remains explicitly excluded from trusted-HTTPS acceptance, not
passed. Resource limits and earlier evidence qualifications remain unchanged.

## Cases and evidence to record

1. **Foreground overview and details.** Keep the same synthetic Animal visible
   on all clients. Change its name from another signed-in client, recording
   UTC time and the expected synthetic marker. Confirm both overview and detail
   receive the committed value without a page reload. Record stale values,
   duplicates, lost focus or unexpected route changes. Human stopwatch timings
   are qualitative checks; the automatic per-trial capture supplies the latency
   distribution.
2. **Tabs and background/foreground.** Open two tabs in the same laptop browser,
   one in overview and one in details. On a mobile device, leave a relevant page
   open, switch away or lock it for at least a minute, and change the Animal from
   another client. Return and verify current data and a usable page. Repeat on
   Firefox and Brave. Record whether the OS discarded the page: a discarded tab
   reopening is a different observation from a retained page resuming.
3. **Network outage and recovery.** Disable network access on only one mobile
   client for a minute, change the synthetic Animal from another connected
   client, then restore the mobile connection. Observe connection feedback and
   eventual reconciliation. Verify that saving while disconnected is not shown
   as confirmed before the server accepts it. Record time to recovery and
   whether a reload was required; normal recovery must not require one.
4. **Draft and conflict.** Keep an unsaved synthetic edit open. Change the same
   Animal from another client, then attempt the first edit. Verify that draft
   text survives the update/recovery and that revision conflict feedback remains
   explicit. Do not count a rejected command as a successful save.
5. **Server-invalidated session.** In a separate authorized follow-up, invalidate
   only a test caregiver session/account while its page is open. Observe the
   authentication-required state, stopped protected updates and a usable login
   path. Re-enable/recreate the disposable test account if needed. Record the
   invalidation method. Ordinary user logout is not a test of passive expiry;
   actual time expiry remains distinct from forced revocation.
6. **Restore outcomes.** In a separate authorized follow-up, export a backup of
   the disposable fixture. Test a rejected restore and verify retained data,
   connection usability and drafts. Then restore a valid fixture backup with a
   distinguishable synthetic value and verify reconciliation in the other
   clients, including the changed collection epoch. Record whether authentication
   was retained or had to be renewed. Never use a production backup here.

Tests 5 and 6 change shared fixture/account state. Schedule them after matrix and
soak measurements; verify the private fixture identity before controller commands.
Do not improvise production account deletion or a database edit to simulate them.
The existing deterministic #229 tests remain separate evidence and do not fill
in these physical-browser outcomes.

## Copyable result format

```text
UTC:
Client / model / OS / browser version:
Current test web image:
HTTPS trusted:
Case / steps actually performed:
Expected synthetic marker:
Observed value and UI state:
Recovery duration, if measured:
Reload required:
Draft / conflict outcome:
Pass, fail or not tested:
Limitations:
```

Keep missing cases as `not tested`. Do not infer native-device performance from
headless desktop contexts, or claim natural expiry from an explicit logout.
