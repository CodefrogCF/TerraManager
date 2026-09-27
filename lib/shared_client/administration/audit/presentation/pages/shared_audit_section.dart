import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/shared_client/administration/audit/domain/shared_audit_models.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

const _actions = <String, (String, String)>{
  'create': ('Created', 'Erstellt'),
  'update': ('Updated', 'Geändert'),
  'delete': ('Deleted', 'Gelöscht'),
  'archive': ('Archived', 'Archiviert'),
  'restore': ('Restored', 'Wiederhergestellt'),
  'duplicate': ('Duplicated', 'Dupliziert'),
  'move': ('Moved', 'Verschoben'),
  'feeding-reminder': (
    'Feeding reminder changed',
    'Fütterungserinnerung geändert',
  ),
  'set_primary': ('Primary picture changed', 'Hauptbild geändert'),
};

String _actionLabel(BuildContext context, String action) {
  final labels = _actions[action.split('.').last];
  return labels == null ? action : sharedText(context, labels.$1, labels.$2);
}

String _recordLabel(BuildContext context, String type) => switch (type) {
  'box' => sharedText(context, 'Box', 'Box'),
  'animal' => sharedText(context, 'Animal', 'Tier'),
  'feeding' => sharedText(context, 'Feeding', 'Fütterung'),
  'weight' => sharedText(context, 'Weight', 'Gewicht'),
  'shedding' => sharedText(context, 'Shedding', 'Häutung'),
  'media' => sharedText(context, 'Picture', 'Bild'),
  'account' => sharedText(context, 'Account', 'Konto'),
  'collection' => sharedText(context, 'Collection', 'Sammlung'),
  _ => type,
};

class SharedAuditSection extends StatelessWidget {
  const SharedAuditSection({
    super.key,
    required this.api,
    required this.enabled,
  });
  final SharedApiClient api;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        sharedText(context, 'Audit', 'Audit'),
        key: const Key('shared-audit-section-heading'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      ListTile(
        key: const Key('shared-view-audit'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_outlined),
        title: Text(
          sharedText(
            context,
            'View recent events',
            'Letzte Ereignisse ansehen',
          ),
        ),
        subtitle: Text(
          sharedText(
            context,
            'Review collection and account changes. Only administrators can view this history.',
            'Sammlungs- und Kontoänderungen prüfen. Nur Administratoren können diesen Verlauf ansehen.',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled && api.session?.role == 'administrator'
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SharedAuditViewerPage(api: api),
                ),
              )
            : null,
      ),
    ],
  );
}

class SharedAuditViewerPage extends StatefulWidget {
  const SharedAuditViewerPage({super.key, required this.api});
  final SharedApiClient api;

  @override
  State<SharedAuditViewerPage> createState() => _SharedAuditViewerPageState();
}

class _SharedAuditViewerPageState extends State<SharedAuditViewerPage> {
  final _actor = TextEditingController();
  final _cursors = <String?>[null];
  String? _action;
  DateTime? _from;
  DateTime? _through;
  String? _appliedActor;
  String? _appliedAction;
  DateTime? _appliedFrom;
  DateTime? _appliedUntil;
  SharedAuditPage? _page;
  int _pageIndex = 0;
  int _request = 0;
  bool _busy = false;
  bool _denied = false;
  bool _failed = false;
  bool _invalidDates = false;
  bool get _allowed => !_denied && widget.api.session?.role == 'administrator';
  bool get _filtered =>
      _appliedActor != null ||
      _appliedAction != null ||
      _appliedFrom != null ||
      _appliedUntil != null;

  @override
  void initState() {
    super.initState();
    if (_allowed) _load();
  }

  @override
  void dispose() {
    _actor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_allowed) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _failed = false;
      _page = null;
    });
    try {
      final page = await widget.api.auditEvents(
        cursor: _cursors[_pageIndex],
        actor: _appliedActor,
        action: _appliedAction,
        from: _appliedFrom,
        until: _appliedUntil,
      );
      if (!mounted || request != _request || !_allowed) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        if (error is SharedApiException &&
            const {401, 403}.contains(error.status)) {
          _denied = true;
        }
      });
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  void _firstPage() {
    _cursors.clear();
    _cursors.add(null);
    _pageIndex = 0;
    _load();
  }

  void _apply() {
    if (_from != null && _through != null && _from!.isAfter(_through!)) {
      setState(() => _invalidDates = true);
      return;
    }
    _appliedActor = _actor.text.trim().isEmpty ? null : _actor.text.trim();
    _appliedAction = _action;
    _appliedFrom = _from;
    _appliedUntil = _through == null
        ? null
        : DateTime(_through!.year, _through!.month, _through!.day + 1);
    _invalidDates = false;
    _firstPage();
  }

  void _reset() {
    _actor.clear();
    setState(() {
      _action = null;
      _from = null;
      _through = null;
    });
    _apply();
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (start ? _from : _through) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    setState(() {
      if (start) {
        _from = date;
      } else {
        _through = date;
      }
    });
  }

  Widget _dateButton(bool start) {
    final date = start ? _from : _through;
    final label = start
        ? sharedText(context, 'From', 'Von')
        : sharedText(context, 'Through', 'Bis');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: Key(start ? 'audit-from' : 'audit-through'),
          onPressed: _busy ? null : () => _pickDate(start),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            date == null
                ? label
                : '$label: ${DateFormat.yMd(Localizations.localeOf(context).toString()).format(date)}',
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: sharedText(context, 'Clear date', 'Datum entfernen'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    if (start) {
                      _from = null;
                    } else {
                      _through = null;
                    }
                  }),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.api,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(sharedText(context, 'Audit', 'Audit')),
        actions: [
          IconButton(
            key: const Key('audit-refresh'),
            tooltip: sharedText(
              context,
              'Refresh recent events',
              'Letzte Ereignisse aktualisieren',
            ),
            onPressed: _allowed && !_busy ? _firstPage : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ConstrainedPageWidth(
        maxWidth: 960,
        child: !_allowed
            ? Center(
                child: Text(
                  sharedText(
                    context,
                    'Administrator access required.',
                    'Administratorzugang erforderlich.',
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    sharedText(
                      context,
                      'Collection and account changes from the last 365 days, newest first. Times use your local time zone. Only event metadata is shown; notes, passwords and session values are excluded.',
                      'Sammlungs- und Kontoänderungen der letzten 365 Tage, neueste zuerst. Zeiten werden in deiner lokalen Zeitzone angezeigt. Es werden nur Ereignismetadaten angezeigt; Notizen, Passwörter und Sitzungswerte bleiben ausgeschlossen.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 600;
                      final actor = TextField(
                        key: const Key('audit-actor'),
                        controller: _actor,
                        enabled: !_busy,
                        maxLength: 64,
                        decoration: InputDecoration(
                          labelText: sharedText(
                            context,
                            'Actor name',
                            'Benutzername',
                          ),
                          helperText: sharedText(
                            context,
                            'Matches the name at the event time.',
                            'Sucht im Namen zum Ereigniszeitpunkt.',
                          ),
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _apply(),
                      );
                      final action = DropdownButtonFormField<String>(
                        key: ValueKey('audit-action-${_action ?? 'all'}'),
                        initialValue: _action ?? 'all',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: sharedText(context, 'Action', 'Aktion'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              sharedText(
                                context,
                                'All actions',
                                'Alle Aktionen',
                              ),
                            ),
                          ),
                          for (final entry in _actions.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                sharedText(
                                  context,
                                  entry.value.$1,
                                  entry.value.$2,
                                ),
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _action = value == 'all' ? null : value,
                              ),
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: actor),
                                const SizedBox(width: 16),
                                Expanded(child: action),
                              ],
                            )
                          : Column(
                              children: [
                                actor,
                                const SizedBox(height: 16),
                                action,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [_dateButton(true), _dateButton(false)],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('audit-apply'),
                        onPressed: _busy ? null : _apply,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: Text(
                          sharedText(
                            context,
                            'Apply filters',
                            'Filter anwenden',
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('audit-reset'),
                        onPressed: _busy ? null : _reset,
                        child: Text(
                          sharedText(
                            context,
                            'Reset filters',
                            'Filter zurücksetzen',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_invalidDates)
                    Text(
                      sharedText(
                        context,
                        'The start date must not be after the end date.',
                        'Das Startdatum darf nicht nach dem Enddatum liegen.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_busy)
                    const LinearProgressIndicator(key: Key('audit-loading')),
                  if (_failed)
                    Column(
                      children: [
                        Text(
                          sharedText(
                            context,
                            'Events could not be loaded. Check your connection and try again.',
                            'Ereignisse konnten nicht geladen werden. Verbindung prüfen und erneut versuchen.',
                          ),
                        ),
                        TextButton(
                          key: const Key('audit-retry'),
                          onPressed: _load,
                          child: Text(
                            sharedText(
                              context,
                              'Try again',
                              'Erneut versuchen',
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_page != null && _page!.events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(Icons.history_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            _filtered
                                ? sharedText(
                                    context,
                                    'No events match these filters.',
                                    'Keine Ereignisse für diese Filter.',
                                  )
                                : sharedText(
                                    context,
                                    'No events yet.',
                                    'Noch keine Ereignisse.',
                                  ),
                            key: const Key('audit-empty'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sharedText(
                              context,
                              'Collection and account changes will appear here.',
                              'Sammlungs- und Kontoänderungen werden hier angezeigt.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final event in _page?.events ?? <SharedAuditEvent>[])
                    _AuditEventCard(event: event),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        key: const Key('audit-previous'),
                        onPressed: !_busy && _pageIndex > 0
                            ? () {
                                _pageIndex--;
                                _load();
                              }
                            : null,
                        child: Text(sharedText(context, 'Previous', 'Zurück')),
                      ),
                      Text(
                        sharedText(
                          context,
                          'Page ${_pageIndex + 1}',
                          'Seite ${_pageIndex + 1}',
                        ),
                      ),
                      OutlinedButton(
                        key: const Key('audit-next'),
                        onPressed: !_busy && _page?.nextCursor != null
                            ? () {
                                _cursors.removeRange(
                                  _pageIndex + 1,
                                  _cursors.length,
                                );
                                _cursors.add(_page!.nextCursor);
                                _pageIndex++;
                                _load();
                              }
                            : null,
                        child: Text(sharedText(context, 'Next', 'Weiter')),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );
}

class _AuditEventCard extends StatelessWidget {
  const _AuditEventCard({required this.event});
  final SharedAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.yMd(locale)
        .add_Hms()
        .format(event.occurredAt.toLocal());
    final role = switch (event.actorRole) {
      'administrator' => sharedText(context, 'Administrator', 'Administrator'),
      'caregiver' => sharedText(context, 'Caregiver', 'Betreuung'),
      _ => sharedText(context, 'Server tool', 'Serverwerkzeug'),
    };
    final outcome = switch (event.outcome) {
      'success' => sharedText(context, 'Succeeded', 'Erfolgreich'),
      'replayed' => sharedText(
        context,
        'Repeated request',
        'Wiederholte Anfrage',
      ),
      _ => sharedText(context, 'Rejected', 'Abgelehnt'),
    };
    return Card(
      key: Key('audit-event-${event.source}-${event.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_recordLabel(context, event.recordType)} · ${_actionLabel(context, event.action)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${event.actorName} · $role'),
            Text(time),
            const SizedBox(height: 8),
            SelectableText(
              event.recordId == null
                  ? _recordLabel(context, event.recordType)
                  : '${_recordLabel(context, event.recordType)} · ID ${event.recordId}',
            ),
            Text(
              outcome,
              style: TextStyle(
                color: event.outcome == 'rejected'
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
