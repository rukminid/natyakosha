import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dance_event.dart';
import '../../../data/models/member.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/events_view_model.dart';
import 'event_card.dart';

enum _Mode { list, calendar }

/// Third tab: every event as a list, or on a month calendar.
class EventsView extends StatefulWidget {
  const EventsView({super.key});

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  _Mode _mode = _Mode.list;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, EventsViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: EventsViewModel.fromStore,
      distinct: true,
      onInit: (store) => EventsViewModel.fromStore(store).refresh(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(
          title: const Text('Events'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Mode.list, icon: Icon(Icons.view_agenda_outlined), tooltip: 'List'),
                  ButtonSegment(value: _Mode.calendar, icon: Icon(Icons.calendar_month_outlined), tooltip: 'Calendar'),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ],
        ),
        floatingActionButton: vm.isStaff
            ? FloatingActionButton.extended(
                onPressed: () => context.push(
                  _mode == _Mode.calendar
                      ? '${Routes.eventNew}?date=${DateFormat('yyyy-MM-dd').format(_selected)}'
                      : Routes.eventNew,
                ),
                icon: const Icon(Icons.add),
                label: const Text('New event'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: vm.refresh,
          child: vm.error != null && vm.all.isEmpty
              ? ListView(children: [ErrorRetry(message: vm.error!, onRetry: vm.refresh)])
              : _mode == _Mode.list
                  ? _ListBody(vm: vm)
                  : _CalendarBody(
                      vm: vm,
                      focused: _focused,
                      selected: _selected,
                      format: _format,
                      onDaySelected: (sel, foc) => setState(() {
                        _selected = sel;
                        _focused = foc;
                      }),
                      onFormatChanged: (f) => setState(() => _format = f),
                      onPageChanged: (foc) => _focused = foc,
                    ),
        ),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({required this.vm});
  final EventsViewModel vm;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (vm.loading) const LinearProgressIndicator(minHeight: 2),
          if (!vm.loading && vm.all.isEmpty)
            EmptyState(
              icon: Icons.theater_comedy_outlined,
              title: 'No events yet',
              message: vm.isStaff
                  ? 'Tap “New event” to schedule a performance.'
                  : 'Performances your school takes part in will show here.',
            ),
          if (vm.upcoming.isNotEmpty) ...[
            const _Header('Upcoming'),
            for (final e in vm.upcoming) EventCard(event: e),
          ],
          if (vm.past.isNotEmpty) ...[
            const _Header('Past performances'),
            for (final e in vm.past) EventCard(event: e),
          ],
        ],
      );
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.vm,
    required this.focused,
    required this.selected,
    required this.format,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final EventsViewModel vm;
  final DateTime focused;
  final DateTime selected;
  final CalendarFormat format;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final dayEvents = vm.onDay(selected);
    final dayBirthdays = vm.birthdaysOn(selected);
    final board = vm.birthdaysInMonth(focused);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
      children: [
        if (vm.loading) const LinearProgressIndicator(minHeight: 2),
        Card(
          child: TableCalendar<Object>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: focused,
            calendarFormat: format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 weeks',
              CalendarFormat.week: 'Week',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (d) => isSameDay(d, selected),
            eventLoader: (day) => [...vm.onDay(day), ...vm.birthdaysOn(day)],
            onDaySelected: onDaySelected,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            headerStyle: const HeaderStyle(titleCentered: true),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
              markersMaxCount: 3,
            ),
            calendarBuilders: CalendarBuilders<Object>(
              // Gold dot per event; a small cake for birthdays.
              markerBuilder: (context, day, items) {
                final events = items.whereType<DanceEvent>().length;
                final birthdays = items.whereType<Member>().isNotEmpty;
                if (events == 0 && !birthdays) return null;
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < events.clamp(0, 3); i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        ),
                      if (birthdays) const Icon(Icons.cake, size: 11, color: AppColors.maroon),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            eventDateFormat.format(selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final m in dayBirthdays) _BirthdayTile(member: m, day: selected),
        if (dayEvents.isEmpty && dayBirthdays.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              vm.isStaff ? 'Nothing scheduled. Tap “New event” to add one on this day.' : 'Nothing scheduled.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          )
        else
          for (final e in dayEvents) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: EventCard(event: e, showDate: false),
          ),
        const SizedBox(height: 8),
        _BirthdayBoard(month: focused, members: board, year: focused.year),
      ],
    );
  }
}

/// "🎂 Ananya's birthday" on the selected day.
class _BirthdayTile extends StatelessWidget {
  const _BirthdayTile({required this.member, required this.day});

  final Member member;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = isSameDay(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        color: AppColors.gold.withValues(alpha: 0.15),
        child: ListTile(
          leading: UserAvatar(name: member.name, photoUrl: member.photoUrl, radius: 22),
          title: Text(today ? 'Happy birthday, ${member.name}!' : '${member.name}’s birthday'),
          subtitle: Text(member.role.label),
          trailing: const Icon(Icons.cake_outlined, color: AppColors.maroon),
        ),
      ),
    );
  }
}

/// Everyone with a birthday in the month the calendar is showing.
class _BirthdayBoard extends StatelessWidget {
  const _BirthdayBoard({required this.month, required this.members, required this.year});

  final DateTime month;
  final List<Member> members;
  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cake_outlined, color: AppColors.maroon),
                const SizedBox(width: 8),
                Text('Birthdays in ${DateFormat('MMMM').format(month)}', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Text('No birthdays this month.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
            else
              for (final m in members)
                Builder(builder: (context) {
                  final date = m.birthdayIn(year)!;
                  final isToday = isSameDay(date, now);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: UserAvatar(name: m.name, photoUrl: m.photoUrl, radius: 18),
                    title: Text(m.name),
                    subtitle: Text(DateFormat('EEE, d MMM').format(date)),
                    trailing: isToday ? const StatusChip(label: 'Today', color: AppColors.maroon) : null,
                  );
                }),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
