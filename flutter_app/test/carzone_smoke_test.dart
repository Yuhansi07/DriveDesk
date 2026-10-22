import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivedesk_pro/api.dart';
import 'package:drivedesk_pro/carzone_ui.dart';

class TestDriveApi extends DriveApi {
  @override
  Future<List<dynamic>> list(String path) async {
    if (path == '/api/vehicles') return [
      {
        'id': 11,'make':'Toyota','model':'Axio','plate':'CAZ-1148',
        'year':2019,'category':'Sedan','daily_rate':10500,
        'seats':5,'status':'available',
      },
    ];
    if (path == '/api/bookings') return [];
    if (path == '/api/customers') return [
      {'id':3,'name':'Sample Customer','license_no':'DEMO0001'},
    ];
    throw StateError('Unexpected route: $path');
  }
}

void main() {
  testWidgets('CarZone showroom renders real fleet data and exposes unified fleet navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CarZoneShowroom(api: TestDriveApi(), onRentalDesk: (_) {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your next ride,\nmade effortless.'),findsOneWidget);
    expect(find.textContaining('Toyota Axio'),findsWidgets);
    await tester.tap(find.text('All vehicles').last);
    await tester.pumpAndSettle();
    expect(find.text('Discover cars'),findsOneWidget);
    expect(find.text('1 available cars'),findsOneWidget);
  });
}
