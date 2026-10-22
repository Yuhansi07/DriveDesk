import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'drive_theme.dart';
import 'experience.dart';

String _money(dynamic n) => 'LKR ${NumberFormat('#,##0.00').format(num.tryParse('$n') ?? 0)}';
String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
void _message(BuildContext context, Object e) {
  journeyNotice(context,'Please check this step',next:'$e',error:true);
}
Widget _box(Widget child) => Card(child: Padding(padding: const EdgeInsets.all(20), child: child));
Widget _sectionTitle(String text, String hint) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(text, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
  const SizedBox(height: 5), Text(hint, style: const TextStyle(color: DriveColors.muted)), const SizedBox(height: 20),
]);
Widget _pair(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
  Expanded(child: Text(label, style: const TextStyle(color: DriveColors.muted))),
  Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
]));

class NewRentalWizardPage extends StatefulWidget {
  final DriveApi api;
  final ValueChanged<int> onCreated;
  const NewRentalWizardPage({super.key, required this.api, required this.onCreated});
  @override State<NewRentalWizardPage> createState() => _NewRentalWizardPageState();
}
class _NewRentalWizardPageState extends State<NewRentalWizardPage> {
  List<dynamic> vehicles = [], customers = [], matches = [];
  int? customer, vehicle;
  int step = 0;
  int seats = 5;
  String category = '';
  final budget = TextEditingController(text: '60000');
  DateTime pickup = DateTime.now().add(const Duration(days: 7));
  DateTime returns = DateTime.now().add(const Duration(days: 10));
  Map<String, dynamic>? quote;
  bool suggested = false, busy = false, loading = true;
  String? error;
  @override void initState() {super.initState();_load();}
  Future<void> _load() async {
    try {
      final data = await Future.wait([widget.api.list('/api/vehicles'), widget.api.list('/api/customers')]);
      if (!mounted) return;
      setState(() {
        vehicles = data[0].where((v) => v['status'] == 'available').toList();
        customers = data[1];
        if (vehicles.isNotEmpty) vehicle = vehicles.first['id'] as int;
        if (customers.isNotEmpty) customer = customers.first['id'] as int;
        loading = false;
      });
    } catch (e) {if(mounted)setState(() {error = '$e';loading = false;});}
  }
  Future<void> _chooseDate({required bool start}) async {
    final today = DateTime.now();
    final chosen = await showDatePicker(context: context, firstDate: DateTime(today.year,today.month,today.day),
      lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: start ? pickup : returns);
    if (chosen == null) return;
    setState(() {
      if (start) { pickup = chosen; if (!returns.isAfter(pickup)) returns = pickup.add(const Duration(days: 1)); }
      else returns = chosen;
      quote = null;matches = [];
    });
  }
  Future<void> _matching() async {
    try {
      setState(() => busy = true);
      final days = returns.difference(pickup).inDays;
      final params = Uri(queryParameters: {
        'days':'${days > 0 ? days : 1}', 'seats':'$seats', 'budget':budget.text, 'category':category,
      }).query;
      final result = await widget.api.map('/api/smart/recommendations?$params');
      if(mounted)setState(() {
        matches = List<dynamic>.from(result['results'] as List);
        if(matches.isNotEmpty)vehicle=matches.first['vehicle_id'] as int;
      });
    } catch (e) {_message(context,e);} finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> _next() async {
    if(busy)return;
    try {
      setState(() => busy = true);
      if (step == 0 && customer == null) throw Exception('Register a customer first.');
      if (step == 1) {
        if(vehicle == null)throw Exception('Select a vehicle.');
        if(!returns.isAfter(pickup))throw Exception('Return date must be after pickup.');
        final q = Uri(queryParameters:{'vehicle_id':'$vehicle','pickup_date':_date(pickup),'return_date':_date(returns)}).query;
        final availability = await widget.api.map('/api/availability?$q');
        if(availability['available'] != true)throw Exception('Vehicle not available: ${availability['reason']}');
        quote = await widget.api.map('/api/smart/pricing?$q');
        if(mounted)journeyNotice(context,'Vehicle is available',next:'A price estimate is ready to review.');
      }
      if(step == 3) {
        final created = await widget.api.post('/api/bookings', {
          'vehicle_id':vehicle,'customer_id':customer,'pickup_date':_date(pickup),'return_date':_date(returns),
          'use_suggested_price':suggested,
        });
        if(mounted){journeyNotice(context,'Booking #${created['id']} created',next:'Next: confirm the reservation, then complete pickup inspection.');widget.onCreated(created['id'] as int);}
        return;
      }
      if(mounted)setState(()=>step++);
      if(step==1 && matches.isEmpty) _matching();
    } catch (e) {_message(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(error!=null)return Center(child:Text(error!));
    final chosenCar=vehicles.where((v)=>v['id']==vehicle).firstOrNull;
    final chosenCustomer=customers.where((v)=>v['id']==customer).firstOrNull;
    final steps=['Customer','Vehicle & dates','Rental quote','Review'];
    Widget content;
    if(step==0){
      content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _sectionTitle('Select a customer','Customer must have a driving license and contact information.'),
        if(customers.isEmpty)const Text('No customers yet. Use Customers → Add customer first.'),
        if(customers.isNotEmpty)DropdownButtonFormField<int>(initialValue:customer,decoration:const InputDecoration(labelText:'Customer'),
          items:customers.map<DropdownMenuItem<int>>((c)=>DropdownMenuItem(value:c['id'] as int,child:Text('${c['name']}'))).toList(),onChanged:(id)=>setState(()=>customer=id)),
        if(chosenCustomer!=null)...[const SizedBox(height:18),_pair('Phone','${chosenCustomer['phone']}'),
          _pair('License','${chosenCustomer['license_no']}'),_pair('Expires','${chosenCustomer['license_expiry']??'Not recorded'}')],
      ]);
    }else if(step==1){
      content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _sectionTitle('Choose available fleet','Date availability is checked on the backend before pricing.'),
        Wrap(spacing:12,runSpacing:10,children:[
          OutlinedButton.icon(onPressed:()=>_chooseDate(start:true),icon:const Icon(Icons.calendar_month),label:Text('Pickup ${_date(pickup)}')),
          OutlinedButton.icon(onPressed:()=>_chooseDate(start:false),icon:const Icon(Icons.calendar_today),label:Text('Return ${_date(returns)}')),
        ]),const SizedBox(height:18),
        TextField(controller:budget,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Total budget (LKR)')),
        const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:seats,decoration:const InputDecoration(labelText:'Minimum seats'),items:[2,4,5,7,9,12].map((x)=>DropdownMenuItem(value:x,child:Text('$x seats'))).toList(),onChanged:(s)=>setState(()=>seats=s??5)),
        const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Preferred category'),
          items:['',...{for(final c in vehicles)'${c['category']}'}].map((x)=>DropdownMenuItem(value:x,child:Text(x.isEmpty?'All categories':x))).toList(),onChanged:(v)=>setState(()=>category=v??'')),
        const SizedBox(height:15),
        ContextualTip(icon:Icons.tips_and_updates_outlined,
          title:matches.isNotEmpty?'Best matches are ready':'Find the right car without guessing',
          description:matches.isNotEmpty?'Options are ranked for the budget, seats and class you selected. Final availability is checked before booking.':'We can compare your budget, seats and category automatically. Change filters and refresh any time.',
          action:'Refresh vehicle matches',onPressed:busy?null:_matching),
        const SizedBox(height:18),...((matches.isEmpty?vehicles:matches.map((m)=>vehicles.firstWhere((v)=>v['id']==m['vehicle_id'])).toList()).map((v)=>Card(
          color:vehicle==v['id']?DriveColors.tealDark.withValues(alpha:.34):DriveColors.surface,
          child:RadioListTile<int>(value:v['id'] as int,groupValue:vehicle,onChanged:(id)=>setState(() {vehicle=id;quote=null;}),
            title:Text('${v['make']} ${v['model']} · ${v['plate']}',style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text('${v['category']} · ${v['seats']} seats · ${_money(v['daily_rate'])}/day'))))),
      ]);
    }else if(step==2){
      content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _sectionTitle('Your rental quote','The recommended rate is calculated for this vehicle and your selected dates.'),
        Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:DriveColors.tealDark,borderRadius:BorderRadius.circular(18)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Recommended rental total',style:TextStyle(color:Colors.white70)),
            const SizedBox(height:8),Text(_money(quote?['estimated_total']),style:const TextStyle(fontSize:30,color:Colors.white,fontWeight:FontWeight.w800))])),
        const SizedBox(height:15),_pair('Standard daily rate',_money(chosenCar?['daily_rate'])),
        _pair('Recommended daily rate',_money(quote?['recommended_daily_rate'])),
        ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('How was this rate calculated?',
          style:TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
          children:[_pair('Calculation method','${quote?['method']??'not available'}'),
            _pair('Historical observations','${quote?['training_samples']??0}'),
            Text('${quote?['note']??''}',style:const TextStyle(fontSize:12,color:DriveColors.muted))]),
        const ContextualTip(icon:Icons.price_check_outlined,title:'Price guidance included in this booking',
          description:'A recommendation is prepared automatically. You choose whether to apply it; staff still confirms the final price.'),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Use recommended price'),subtitle:const Text('Only applies after staff review'),value:suggested,onChanged:(x)=>setState(()=>suggested=x)),
      ]);
    }else{
      final total=suggested?num.tryParse('${quote?['estimated_total']}')??0:(num.tryParse('${chosenCar?['daily_rate']}')??0)*returns.difference(pickup).inDays;
      content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _sectionTitle('Review before creating','A pending booking is created; approval, pickup, payments and return are separate stages.'),
        _pair('Customer','${chosenCustomer?['name']}'),
        _pair('Vehicle','${chosenCar?['make']} ${chosenCar?['model']}'),
        _pair('Registration','${chosenCar?['plate']}'),_pair('Dates','${_date(pickup)} → ${_date(returns)}'),
        _pair('Price type',suggested?'Smart suggested':'Standard'),const Divider(),
        Text(_money(total),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:DriveColors.accent)),
      ]);
    }
    return ListView(children:[_sectionTitle('New rental','Complete the four steps. The backend validates each reservation.'),
      Wrap(spacing:8,runSpacing:8,children:List.generate(steps.length,(i)=>Chip(backgroundColor:i==step?const Color(0xFF14524D):i<step?const Color(0xFF24403E):null,
        avatar:CircleAvatar(radius:12,child:Text(i<step?'✓':'${i+1}',style:const TextStyle(fontSize:11))),label:Text(steps[i])))),
      const SizedBox(height:20),_box(content),
      Row(mainAxisAlignment:MainAxisAlignment.end,children:[if(step>0)OutlinedButton(onPressed:busy?null:()=>setState(()=>step--),child:const Text('Back')),
        const SizedBox(width:12),FilledButton.icon(onPressed:busy?null:_next,icon:Icon(step==3?Icons.check:Icons.arrow_forward),
          label:Text(busy?'Please wait…':step==3?'Create booking':'Continue'))]),const SizedBox(height:45)]);
  }
  @override void dispose(){budget.dispose();super.dispose();}
}

class RentalDeskPage extends StatefulWidget {
  final DriveApi api;
  final int? bookingId;
  final VoidCallback onCreate;
  final VoidCallback? onDamage, onGps;
  const RentalDeskPage({super.key,required this.api,this.bookingId,required this.onCreate,this.onDamage,this.onGps});
  @override State<RentalDeskPage> createState()=>_RentalDeskPageState();
}
class _RentalDeskPageState extends State<RentalDeskPage> {
  List<dynamic> bookings=[];List<dynamic> drivers=[];Map<String,dynamic>? workflow;
  int? selected;bool busy=false,loading=true;
  final note=TextEditingController(),token=TextEditingController(),amount=TextEditingController();
  String method='cash';XFile? photo;
  @override void initState(){super.initState();selected=widget.bookingId;_load();}
  @override void didUpdateWidget(covariant RentalDeskPage old){super.didUpdateWidget(old);if(widget.bookingId!=old.bookingId&&widget.bookingId!=null){selected=widget.bookingId;_load();}}
  Future<void> _load() async {
    try{
      final list=await widget.api.list('/api/bookings');
      if(!mounted)return;
      bookings=list;
      final canAssign=['admin','manager','rental_agent'].contains(widget.api.currentUser?['role']);
      if(canAssign)drivers=await widget.api.list('/api/drivers');
      if(list.isNotEmpty && (selected==null || !list.any((b)=>b['id']==selected))) {
        selected=(list.firstWhere((b)=>!['completed','cancelled'].contains(b['status']),orElse:()=>list.first))['id'] as int;
      }
      final result=selected==null?null:await widget.api.map('/api/bookings/$selected/workflow');
      if(mounted)setState(() {workflow=result;loading=false;amount.text='${result?['balance']??''}';});
    }catch(e){if(mounted){setState(()=>loading=false);_message(context,e);}}
  }
  Future<void> _action(Future<void> Function() task,{String? success,String? next})async {
    if(busy)return;setState(()=>busy=true);
    try{await task();if(mounted){await _load();if(success!=null)journeyNotice(context,success,next:next);}}catch(e){_message(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _inspection(String phase)async {
    if(note.text.trim().isEmpty&&photo==null)throw Exception('Add inspection notes or a photo.');
    final bytes=await photo?.readAsBytes();if(bytes!=null && bytes.length>950000)throw Exception('Choose a compressed photo under 950 KB.');
    await widget.api.post('/api/inspections',{'booking_id':selected,'phase':phase,'reviewer_note':note.text,'findings':note.text.trim().isEmpty?[]:[note.text.trim()],
      'image_base64':bytes==null?null:base64Encode(bytes)});
    note.clear();photo=null;
  }
  Future<void> _qr()async{
    final result=await widget.api.post('/api/bookings/$selected/qr',{});
    if(!mounted)return;
    token.text='${result['qr_payload']}';
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('One-time pickup QR'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      QrImageView(data:'${result['qr_payload']}',size:220),const SizedBox(height:12),SelectableText('${result['code']}',style:const TextStyle(fontSize:11)),
      const Text('Verify during handover. Do not share this token.',textAlign:TextAlign.center)]),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Done'))]));
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(bookings.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('No rentals yet.'),FilledButton(onPressed:widget.onCreate,child:const Text('Create one'))]));
    final w=workflow,b=w?['booking'];
    final next=switch(w?['next_action']){'qr_handover'=>'Secure QR handover','settle_payment'=>'Collect payment','pickup_inspection'=>'Pickup inspection','return_inspection'=>'Return inspection','complete'=>'Complete rental','confirm'=>'Confirm reservation',_=>'Review rental'};
    final inspectionPhase=b?['status']=='confirmed'?'pickup':'return';
    return ListView(children:[_sectionTitle('Rental desk','Follow pickup inspection → QR handover → return inspection → payment → completion.'),
      Row(children:[Expanded(child:DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'Rental booking'),
        items:bookings.map<DropdownMenuItem<int>>((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('#${x['id']}  ${x['plate']} • ${x['status']}'))).toList(),
        onChanged:(v){setState(()=>selected=v);_load();})),const SizedBox(width:12),IconButton(onPressed:widget.onCreate,icon:const Icon(Icons.add_circle_outline),tooltip:'New rental')]),
      const SizedBox(height:16),if(b!=null)...[
        Wrap(spacing:8,children:['pending','confirmed','active','completed'].map((s)=>Chip(label:Text(s),
          backgroundColor:s==b['status']?const Color(0xFF14524D):null)).toList()),const SizedBox(height:13),
        _box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${b['make']} ${b['model']} · ${b['plate']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),Text('${b['customer_name']} · ${b['pickup_date']} → ${b['return_date']}'),
          const Divider(height:35),_pair('Contract total',_money(b['total_amount'])),_pair('Paid',_money(w?['paid'])),
          _pair('Outstanding',_money(w?['balance'])),const SizedBox(height:12),
          if(['admin','manager','rental_agent'].contains(widget.api.currentUser?['role']))...[
            DropdownButtonFormField<int>(value:b['assigned_driver_id'] as int?,decoration:const InputDecoration(labelText:'Assigned driver'),
              items:[const DropdownMenuItem<int>(value:null,child:Text('Not assigned')),
                for(final d in drivers)DropdownMenuItem<int>(value:d['id'] as int,child:Text('${d['name']}'))],
              onChanged:(id)=>_action(()async{await widget.api.patch('/api/bookings/$selected/driver',{'driver_id':id});},
                success:'Driver assignment saved',next:'The driver can now see this trip in their own workspace.')),
            const SizedBox(height:15),
          ],
          ContextualTip(icon:Icons.route_outlined,title:'Your next step: ${next.toUpperCase()}',
            description:switch(w?['next_action']){
              'confirm'=>'Review the details and confirm this reservation.',
              'pickup_inspection'=>'Record the vehicle condition before handing over the keys.',
              'qr_handover'=>'Generate the pickup code and verify it with the customer.',
              'return_inspection'=>'Check the returned vehicle and note the condition.',
              'settle_payment'=>'Collect the outstanding balance before closing the rental.',
              'complete'=>'All required checks are done. Complete the rental to close it.',
              _=>'Follow the next available action below. Only valid steps are enabled.',
            }),
        ])),
        if(b['status']=='pending')_box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Confirm reservation',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          const SizedBox(height:8),const Text('After checking customer information, confirm the reservation.'),
          const SizedBox(height:14),FilledButton(onPressed:busy?null:()=>_action(()async{await widget.api.patch('/api/bookings/$selected/status',{'status':'confirmed'});},success:'Reservation confirmed',next:'Next: record pickup inspection before QR handover.'),child:const Text('Confirm booking'))])),
        if(b['status']=='confirmed'||b['status']=='active')_box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${inspectionPhase=='pickup'?'Pickup':'Return'} inspection',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),Text(w?[inspectionPhase=='pickup'?'pickup_inspected':'return_inspected']==true?'✓ Inspection recorded':'Inspection required before proceeding'),
          const SizedBox(height:14),TextField(controller:note,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Condition notes',hintText:'Scratches, fuel, odometer, return observations…')),
          const SizedBox(height:11),Wrap(spacing:9,children:[OutlinedButton.icon(onPressed:()=>ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1000,imageQuality:60).then((x){if(mounted){setState(()=>photo=x);if(x!=null)journeyNotice(context,'Inspection photo selected',next:'Add any condition notes, then save the inspection.');}}),icon:const Icon(Icons.photo_library_outlined),label:Text(photo==null?'Add photo':'Photo selected')),
          FilledButton(onPressed:busy?null:()=>_action(()=>_inspection(inspectionPhase),success:'${inspectionPhase=='pickup'?'Pickup':'Return'} inspection saved',next:inspectionPhase=='pickup'?'Next: generate the one-time handover QR code.':'Next: settle any outstanding balance, then complete the rental.'),child:const Text('Save inspection'))]),
          if(widget.onDamage!=null)Padding(padding:const EdgeInsets.only(top:12),child:ContextualTip(
            icon:Icons.photo_camera_outlined,title:'Need help reviewing vehicle damage?',
            description:'Optional AI photo analysis needs a separately trained model. Manual inspection works without it.',
            action:'Open photo analysis',onPressed:widget.onDamage)),
        ])),
        if(b['status']=='confirmed')_box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('QR handover',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),
          const Text('First record the pickup inspection, then generate and verify the code.'),
          const SizedBox(height:12),OutlinedButton.icon(onPressed:busy||w?['pickup_inspected']!=true?null:()=>_action(_qr),icon:const Icon(Icons.qr_code),label:const Text('Generate QR code')),
          const SizedBox(height:14),TextField(controller:token,decoration:const InputDecoration(labelText:'Paste QR payload or pickup token')),
          const SizedBox(height:12),FilledButton(onPressed:busy||w?['pickup_inspected']!=true?null:()=>_action(()async{await widget.api.post('/api/bookings/$selected/handover',{'code':token.text});token.clear();},success:'Vehicle handed over',next:'Rental is now active. Track payment and plan the return inspection.'),child:const Text('Verify and activate rental')),
        ])),
        if(b['status']=='active')_box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Settlement & return',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
          _pair('Balance due',_money(w?['balance'])),
          if((num.tryParse('${w?['balance']}')??0)>0)...[
            TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount (LKR)')),
            const SizedBox(height:12),DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment method'),
              items:['cash','card','transfer','other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>method=x??'cash')),
            const SizedBox(height:12),OutlinedButton(onPressed:busy?null:()=>_action(()async{await widget.api.post('/api/payments',{'booking_id':selected,'amount':num.tryParse(amount.text),'method':method});},success:'Payment recorded',next:'Outstanding balance has been recalculated.'),child:const Text('Record payment')),
          ],const SizedBox(height:14),
          FilledButton.icon(onPressed:busy||w?['next_action']!='complete'?null:()=>_action(()async{await widget.api.patch('/api/bookings/$selected/status',{'status':'completed'});},success:'Rental completed',next:'The vehicle rental is closed and the booking history is updated.'),
            icon:const Icon(Icons.check_circle_outline),label:const Text('Complete rental')),
          if(w?['next_action']!='complete')const Text('To enable completion: save return inspection and pay any outstanding balance.',style:TextStyle(fontSize:12,color:DriveColors.muted)),
          if(widget.onGps!=null)Padding(padding:const EdgeInsets.only(top:12),child:ContextualTip(
            icon:Icons.location_on_outlined,title:'Need to record a location?',
            description:'Optional. Only record authorized locations. A simulated demo point is not live vehicle tracking.',
            action:'Open location logging',onPressed:widget.onGps)),
        ])),
        if(b['status']=='completed'||b['status']=='cancelled')_box(Text('This booking is ${b['status']}.',style:const TextStyle(fontWeight:FontWeight.w800))),
        _box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Activity history',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const Divider(),
          for(final i in List<dynamic>.from(w?['inspections']??[]))ListTile(leading:const Icon(Icons.fact_check_outlined),title:Text('${i['phase']} inspection'),subtitle:Text('${i['reviewer_note']??''}')),
          for(final p in List<dynamic>.from(w?['payments']??[]))ListTile(leading:const Icon(Icons.payments_outlined),title:Text(_money(p['amount'])),subtitle:Text('${p['method']}')),
        ])),
      ],const SizedBox(height:40)]);
  }
  @override void dispose(){note.dispose();token.dispose();amount.dispose();super.dispose();}
}
