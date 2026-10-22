import 'package:flutter/material.dart';

/// One visual system for every DriveDesk screen, based on the supplied
/// CarZone dark / teal reference. No additional standalone app is launched.
class DriveColors {
  static const bg = Color(0xFF0E1215);
  static const sidebar = Color(0xFF12191D);
  static const surface = Color(0xFF1A2226);
  static const raised = Color(0xFF232D31);
  static const line = Color(0xFF344146);
  static const accent = Color(0xFF08B9AE);
  static const tealDark = Color(0xFF07645F);
  static const text = Color(0xFFF2F8F7);
  static const muted = Color(0xFFA4B4B8);
  static const warning = Color(0xFFFFC578);
}

ThemeData driveTheme() {
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: DriveColors.line),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DriveColors.bg,
    canvasColor: DriveColors.surface,
    colorScheme: const ColorScheme.dark(
      primary: DriveColors.accent,
      onPrimary: Color(0xFF041D1B),
      secondary: DriveColors.accent,
      surface: DriveColors.surface,
      onSurface: DriveColors.text,
      error: Color(0xFFFF8F97),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: DriveColors.bg, foregroundColor: DriveColors.text,
        elevation: 0, centerTitle: false, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      elevation: 0,
      color: DriveColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DriveColors.line, width: .75)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: DriveColors.raised,
      hintStyle: const TextStyle(color: DriveColors.muted),
      labelStyle: const TextStyle(color: DriveColors.muted),
      floatingLabelStyle: const TextStyle(color: DriveColors.accent),
      border: outline, enabledBorder: outline,
      focusedBorder: outline.copyWith(borderSide: const BorderSide(color: DriveColors.accent, width: 1.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: DriveColors.accent, foregroundColor: const Color(0xFF05201F),
      disabledBackgroundColor: DriveColors.line, disabledForegroundColor: DriveColors.muted,
      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: DriveColors.accent,
      side: const BorderSide(color: DriveColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    )),
    dialogTheme: const DialogThemeData(backgroundColor: DriveColors.surface,
      surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: DriveColors.surface,
      modalBackgroundColor: DriveColors.surface),
    dividerTheme: const DividerThemeData(color: DriveColors.line),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: DriveColors.accent),
    iconTheme: const IconThemeData(color: DriveColors.muted),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: DriveColors.sidebar,
      indicatorColor: DriveColors.tealDark),
  );
}

/// Desktop-friendly replacement for Flutter's full-screen date-range picker.
/// It remains readable on both wide windows and phone-sized displays.
Future<DateTimeRange?> pickDriveDates(BuildContext context, DateTimeRange initial) async {
  final now = DateUtils.dateOnly(DateTime.now());
  DateTime start = initial.start.isBefore(now) ? now : DateUtils.dateOnly(initial.start);
  DateTime end = initial.end.isAfter(start) ? initial.end : start.add(const Duration(days: 1));
  final last = now.add(const Duration(days: 730));
  if (start.isAfter(last.subtract(const Duration(days: 1)))) start = last.subtract(const Duration(days: 1));
  if (end.isAfter(last)) end = last;
  bool choosingEnd = false;
  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: StatefulBuilder(builder: (ctx, update) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        child: LayoutBuilder(builder: (ctx, size) {
          final compact = size.maxWidth < 570;
          Widget calendar(DateTime value, bool isEnd) => CalendarDatePicker(
            key: ValueKey('${isEnd ? 'end' : 'start'}-${value.year}-${value.month}'),
            initialDate: value,
            firstDate: isEnd ? start.add(const Duration(days: 1)) : now,
            lastDate: last,
            onDateChanged: (d) => update(() {
              if (isEnd) { end = d; }
              else {
                start = d;
                if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
                if (compact) choosingEnd = true;
              }
            }),
          );
          return SingleChildScrollView(child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.event_available_rounded, color: DriveColors.accent),
                const SizedBox(width: 10), const Expanded(child: Text('Choose rental dates',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))]),
              const SizedBox(height: 6),
              const Text('Select a pick-up date and a return date.', style: TextStyle(color: DriveColors.muted)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _DateSelection(label: 'PICK-UP', date: start, active: !choosingEnd,
                  onTap: () => update(() => choosingEnd = false))),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: DriveColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(child: _DateSelection(label: 'RETURN', date: end, active: choosingEnd,
                  onTap: () => update(() => choosingEnd = true))),
              ]),
              const SizedBox(height: 8),
              if (compact) calendar(choosingEnd ? end : start, choosingEnd)
              else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [const Text('Pick-up calendar', style: TextStyle(color: DriveColors.muted)), calendar(start, false)])),
                Expanded(child: Column(children: [const Text('Return calendar', style: TextStyle(color: DriveColors.muted)), calendar(end, true)])),
              ]),
              const SizedBox(height: 10),
              Row(children: [Text('${end.difference(start).inDays} rental day(s)',
                    style: const TextStyle(color: DriveColors.accent, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(dialogContext,
                    DateTimeRange(start: start, end: end)), child: const Text('Apply dates')),
              ]),
            ]),
          ));
        }),
      )),
    ),
  );
}

class _DateSelection extends StatelessWidget {
  final String label; final DateTime date; final bool active; final VoidCallback onTap;
  const _DateSelection({required this.label,required this.date,required this.active,required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: active ? DriveColors.tealDark.withValues(alpha:.30) : DriveColors.raised,
        border: Border.all(color: active ? DriveColors.accent : DriveColors.line),
        borderRadius: BorderRadius.circular(13)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,style:const TextStyle(fontSize:10, color:DriveColors.muted, fontWeight:FontWeight.w700)),
      const SizedBox(height: 5),
      Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',
        style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
    ]),
  ));
}
