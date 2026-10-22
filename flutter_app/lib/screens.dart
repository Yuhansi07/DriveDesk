import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'rental_flow.dart';
import 'drive_theme.dart';
import 'experience.dart';

String cash(dynamic value)=>'LKR ${NumberFormat('#,##0.00').format(num.tryParse('$value')??0)}';
String dateOnly(dynamic s)=>s.toString().substring(0,s.toString().length<10?s.toString().length:10);
void toast(BuildContext ctx,String message,{bool fail=false}) => journeyNotice(ctx,message,error:fail);
Widget heading(String title,String subtitle,[Widget? trailing])=>Padding(padding:const EdgeInsets.only(bottom:20),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:DriveColors.muted))])),if(trailing!=null)trailing]));
Widget pill(String text){final color=switch(text){'available'||'completed'||'active'=>Colors.green,'pending'||'maintenance'=>Colors.orange,'cancelled'=>Colors.red,_=>DriveColors.accent};return Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:0.12),borderRadius:BorderRadius.circular(30)),child:Text(text,style:TextStyle(color:color,fontSize:12,fontWeight:FontWeight.w700)));}
Widget panel(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:child));
Widget field(TextEditingController c,String name,{TextInputType keyboard=TextInputType.text})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,keyboardType:keyboard,decoration:InputDecoration(labelText:name)));
Future<void> showError(BuildContext context,Object error)async{journeyNotice(context,'Could not complete action',next:'$error',error:true);}

class DashboardPage extends StatelessWidget {
  final DriveApi api;
  final VoidCallback onNewRental,onExplore,onRentalDesk,onTrends,onMaintenance;
  const DashboardPage({super.key,required this.api,required this.onNewRental,required this.onExplore,required this.onRentalDesk,required this.onTrends,required this.onMaintenance});

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:api.map('/api/dashboard'),builder:(ctx,s){
      if(s.hasError)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.cloud_off_rounded,size:38,color:DriveColors.warning),
        const SizedBox(height:10),Text('Dashboard unavailable: ${s.error}') ]));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final data=s.data!;
      final tiles=<({String title,String value,IconData icon,Color color})>[
        (title:'Total vehicles',value:'${data['vehicles']}',icon:Icons.directions_car_filled_rounded,color:DriveColors.accent),
        (title:'Customers',value:'${data['customers']}',icon:Icons.people_alt_rounded,color:const Color(0xFF71A5FA)),
        (title:'Total bookings',value:'${data['bookings']}',icon:Icons.calendar_month_rounded,color:const Color(0xFFC3A3F9)),
        (title:'Active rentals',value:'${data['active']}',icon:Icons.key_rounded,color:DriveColors.warning),
        (title:'Collected revenue',value:cash(data['collected_revenue']),icon:Icons.payments_rounded,color:DriveColors.accent),
      ];
      final recent=List<dynamic>.from(data['recent_bookings'] as List? ?? []);
      return LayoutBuilder(builder:(ctx,co){
        final narrow=co.maxWidth<750;
        final width=co.maxWidth>1180?(co.maxWidth-56)/5:co.maxWidth>650?(co.maxWidth-14)/2:co.maxWidth;
        return ListView(children:[
          Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('OPERATIONS / OVERVIEW',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,
              letterSpacing:2,color:DriveColors.accent)),const SizedBox(height:10),
            const Text('Fleet at a glance.',style:TextStyle(fontSize:30,letterSpacing:-1.1,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),const Text('Everything you need to manage a rental day.',
              style:TextStyle(fontSize:13,color:DriveColors.muted)),
          ])),if(!narrow)FilledButton.icon(onPressed:onNewRental,
            icon:const Icon(Icons.add_rounded),label:const Text('New reservation'))]),
          const SizedBox(height:24),
          Container(height:narrow?230:245,clipBehavior:Clip.antiAlias,
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(23),
              border:Border.all(color:DriveColors.line),
              gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:[Color(0xFF073D3C),DriveColors.surface,DriveColors.bg])),
            child:Stack(children:[
              Positioned(top:-90,right:-50,child:Container(width:330,height:330,
                decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:DriveColors.accent.withValues(alpha:.25),width:45)))),
              if(!narrow)Positioned(right:5,top:0,bottom:0,width:co.maxWidth*.43,
                child:Image.asset('assets/cars/range_rover.jpg',fit:BoxFit.cover,
                  errorBuilder:(ctx,error,stack)=>const Icon(Icons.directions_car_filled_rounded,size:145,color:DriveColors.tealDark))),
              if(!narrow)Positioned(right:0,top:0,bottom:0,width:co.maxWidth*.43,
                child:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
                  colors:[Color(0xFF093B3A),Colors.transparent])))),
              Padding(padding:EdgeInsets.all(narrow?20:29),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(
                  color:DriveColors.tealDark,borderRadius:BorderRadius.circular(20)),
                  child:const Text('DRIVEDESK  /  SMART RENTAL SYSTEM',style:TextStyle(fontSize:9,
                    color:DriveColors.text,fontWeight:FontWeight.w900,letterSpacing:1.2))),
                const SizedBox(height:17),
                const Text('Ready for the\nnext reservation?',style:TextStyle(fontSize:29,height:1.12,
                  color:Colors.white,fontWeight:FontWeight.w900,letterSpacing:-1)),
                const SizedBox(height:11),
                const Text('Select a customer, recommend a car and get started.',
                  style:TextStyle(fontSize:12,color:Color(0xFFBDD4D2))),
                const Spacer(),
                Row(children:[FilledButton.icon(onPressed:onNewRental,
                  icon:const Icon(Icons.arrow_forward_rounded,size:18),label:const Text('Create rental')),
                  const SizedBox(width:10),
                  if(!narrow)OutlinedButton(onPressed:onExplore,child:const Text('Explore fleet'))]),
              ])),
              Positioned(right:12,bottom:8,child:const Text('Illustrative fleet photo',
                style:TextStyle(fontSize:9,color:DriveColors.muted))),
            ])),
          const SizedBox(height:23),
          Wrap(spacing:14,runSpacing:14,children:[for(final tile in tiles)
            SizedBox(width:width,child:Container(padding:const EdgeInsets.all(19),
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),
                color:DriveColors.surface,border:Border.all(color:DriveColors.line)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(
                  color:tile.color.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
                  child:Icon(tile.icon,color:tile.color,size:20)),const Spacer(),
                  const Icon(Icons.north_east_rounded,color:DriveColors.muted,size:15)]),
                const SizedBox(height:17),Text(tile.value,style:TextStyle(
                  fontSize:tile.title=='Collected revenue'?21:30,fontWeight:FontWeight.w900)),
                const SizedBox(height:5),Text(tile.title,style:const TextStyle(color:DriveColors.muted,fontSize:12)),
              ]))),
          ]),
          const SizedBox(height:20),
          ContextualTip(icon:Icons.tips_and_updates_outlined,
            title:data['active'] == 0 ? 'Start with the next reservation' : 'Keep today’s rentals on track',
            description:data['active'] == 0
                ? 'Select a customer, see suitable cars and receive a price suggestion during booking.'
                : 'Check active rentals, upcoming returns and outstanding payments in the Rental Desk.',
            action:data['active'] == 0 ? 'Create a booking' : 'Continue a rental',
            onPressed:data['active'] == 0 ? onNewRental : onRentalDesk),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton.icon(icon:const Icon(Icons.trending_up),label:const Text('View rental trends'),onPressed:onTrends),
            OutlinedButton.icon(icon:const Icon(Icons.build_circle_outlined),label:const Text('Service reminders'),onPressed:onMaintenance),
          ]),
          const SizedBox(height:26),
          Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Recent reservations',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
            SizedBox(height:4),Text('Latest rental activity from the live database',
                style:TextStyle(fontSize:12,color:DriveColors.muted))])),
            TextButton.icon(onPressed:onRentalDesk,icon:const Icon(Icons.arrow_forward,size:17),
              label:const Text('Open rental desk'))]),
          const SizedBox(height:9),
          Container(decoration:BoxDecoration(color:DriveColors.surface,
            borderRadius:BorderRadius.circular(18),border:Border.all(color:DriveColors.line)),
            child:recent.isEmpty
              ? const Padding(padding:EdgeInsets.all(25),child:Text('No bookings yet. Start with New reservation.'))
              : Column(children:[for(int i=0;i<recent.length;i++)...[
                  if(i>0)const Divider(height:1,indent:18,endIndent:18),
                  ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:19,vertical:6),
                    leading:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(
                      color:DriveColors.tealDark.withValues(alpha:.35),borderRadius:BorderRadius.circular(13)),
                      child:const Icon(Icons.directions_car_rounded,color:DriveColors.accent)),
                    title:Text('${recent[i]['plate']}  •  ${recent[i]['customer_name']}',
                      style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
                    subtitle:Text('${dateOnly(recent[i]['pickup_date'])}  →  ${dateOnly(recent[i]['return_date'])}',
                      style:const TextStyle(color:DriveColors.muted,fontSize:11)),
                    trailing:narrow?pill('${recent[i]['status']}'):Column(
                      mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,
                      children:[Text(cash(recent[i]['total_amount']),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
                        const SizedBox(height:3),pill('${recent[i]['status']}')]),
                  ),
                ]]),
          ),
          const SizedBox(height:20),const Text('Pricing, recommendations and anomalies are advisory. Computer-vision modules require configured models.',
            style:TextStyle(fontSize:11,color:DriveColors.muted)),
          const SizedBox(height:22),
        ]);
      });
    });
}

class VehiclesPage extends StatefulWidget{final DriveApi api;const VehiclesPage({super.key,required this.api});@override State<VehiclesPage> createState()=>_VehiclesPageState();}
class _VehiclesPageState extends State<VehiclesPage>{int version=0;void refresh()=>setState(()=>version++);
 Future<void> editor([Map<String,dynamic>? existing])async{
   final names=['plate','make','model','category','year','daily_rate','seats','mileage_km','service_due_km','insurance_expiry'];
   final prompts=['Plate','Make','Model','Category','Year','Daily rate (LKR)','Seats','Mileage (km)','Next service (km)','Insurance expiry (YYYY-MM-DD)'];
   final c={for(final x in names)x:TextEditingController(text:'${existing?[x]??''}')};
   String status='${existing?['status']??'available'}';
   final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,upd)=>AlertDialog(title:Text(existing==null?'Add vehicle':'Edit vehicle'),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[for(int i=0;i<names.length;i++)field(c[names[i]]!,prompts[i]),DropdownButtonFormField<String>(initialValue:status,items:['available','maintenance'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(s)=>upd(()=>status=s!))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
   if(confirmed==true){try{final data=<String,dynamic>{for(final e in c.entries)e.key:e.value.text,'status':status};for(final key in ['year','daily_rate','seats','mileage_km','service_due_km']){if(data[key]=='')data[key]=null;else data[key]=num.tryParse('${data[key]}');}
     if(data['insurance_expiry']=='')data['insurance_expiry']=null;
     if(existing==null)await widget.api.post('/api/vehicles',data);else await widget.api.put('/api/vehicles/${existing['id']}',data);
     if(mounted){journeyNotice(context,existing==null?'Vehicle added':'Vehicle updated',next:'This vehicle is now available in the fleet and booking flow.');refresh();}
   }catch(e){if(mounted)showError(context,e);}}
   for(final text in c.values){text.dispose();}
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/vehicles'),builder:(ctx,s){if(s.hasError)return Center(child:Text('Error: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:[heading('Fleet management','Create, update, and maintain vehicles.',FilledButton.icon(onPressed:()=>editor(),icon:const Icon(Icons.add),label:const Text('Add vehicle'))),
   ContextualTip(icon:Icons.build_circle_outlined,title:'Keep cars ready for the next rental',
    description:'Service mileage and insurance reminders are checked from your vehicle records.',
    action:'Review fleet health',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenanceTool(api:widget.api)))),
   const SizedBox(height:12),Expanded(child:ListView(children:s.data!.map((v)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.directions_car)),title:Text('${v['make']} ${v['model']}  •  ${v['plate']}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${v['category']}  |  ${v['seats']} seats  |  ${cash(v['daily_rate'])}/day'),trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:8,children:[pill('${v['status']}'),IconButton(icon:const Icon(Icons.edit_outlined),onPressed:()=>editor(Map<String,dynamic>.from(v)))])))).toList()))]);});
}

class CustomersPage extends StatefulWidget{final DriveApi api;const CustomersPage({super.key,required this.api});@override State<CustomersPage> createState()=>_CustomersPageState();}
class _CustomersPageState extends State<CustomersPage>{int version=0;
 Future<void> editor([Map<String,dynamic>? existing])async{
   final fields=['name','phone','email','license_no','license_expiry'];final labels=['Full name','Phone','Email','Driving license number','License expiry (YYYY-MM-DD)'];
   final cs={for(final e in fields)e:TextEditingController(text:'${existing?[e]??''}')};
   final save=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(existing==null?'New customer':'Edit customer'),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[for(int i=0;i<fields.length;i++)field(cs[fields[i]]!,labels[i])]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
   if(save==true){try{final b=<String,dynamic>{for(final e in cs.entries)e.key:e.value.text};if(b['license_expiry']=='')b['license_expiry']=null;
     if(existing==null)await widget.api.post('/api/customers',b);else await widget.api.put('/api/customers/${existing['id']}',b);if(mounted){journeyNotice(context,existing==null?'Customer added':'Customer updated',next:'Customer can now be selected during a new rental.');setState(()=>version++);}
   }catch(e){if(mounted)showError(context,e);}}
   for(final t in cs.values)t.dispose();
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/customers'),builder:(ctx,s){if(s.hasError)return Center(child:Text('${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:[heading('Customers','Store contact and rental license details.',FilledButton.icon(icon:const Icon(Icons.person_add_alt),label:const Text('Add customer'),onPressed:()=>editor())),
   ContextualTip(icon:Icons.document_scanner_outlined,title:'Save time entering license details',
    description:'Scan a license where a supported OCR engine is configured. Always review extracted details before saving.',
    action:'Open license scanner',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OcrTool(api:widget.api)))),
   const SizedBox(height:12),Expanded(child:ListView(children:s.data!.map((c)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${c['phone']}   •   License ${c['license_no']}'),trailing:IconButton(onPressed:()=>editor(Map<String,dynamic>.from(c)),icon:const Icon(Icons.edit_outlined))))).toList()))]);});
}

class BookingsPage extends StatefulWidget{final DriveApi api;const BookingsPage({super.key,required this.api});@override State<BookingsPage> createState()=>_BookingsPageState();}
class _BookingsPageState extends State<BookingsPage>{int version=0;void reload()=>setState(()=>version++);
 Future<void> add()async{await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Guided new rental')),body:Padding(padding:const EdgeInsets.all(16),child:NewRentalWizardPage(api:widget.api,onCreated:(id){Navigator.pop(context);reload();})))));}
 Future<void> setStatus(Map b,String status)async{try{await widget.api.patch('/api/bookings/${b['id']}/status',{'status':status});if(mounted){journeyNotice(context,'Booking $status',next:status=='confirmed'?'Next: open Rental Desk for pickup inspection and QR handover.':status=='completed'?'Rental is closed and reflected in reports.':'Booking status updated.');reload();}}catch(e){if(mounted)showError(context,e);}}
 Future<void> showQr(Map b)async{try{final qr=await widget.api.post('/api/bookings/${b['id']}/qr',{});if(!mounted)return;await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('Pickup code • Booking #${b['id']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[QrImageView(data:'${qr['qr_payload']}',size:230),const SizedBox(height:10),const Text('Scan at handover. Code is single-use.',textAlign:TextAlign.center),SelectableText('${qr['code']}',style:const TextStyle(fontSize:11))]),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Done'))]));}catch(e){if(mounted)showError(context,e);}}
 Future<void> handover(Map b)async{String code='';bool scanning=false;final canScan=kIsWeb || (!kIsWeb&&(defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS));
   final value=await showDialog<String>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,up)=>AlertDialog(title:Text('Handover booking #${b['id']}'),content:SizedBox(width:390,height:scanning?340:180,child:Column(children:[if(scanning)Expanded(child:MobileScanner(onDetect:(capture){final s=capture.barcodes.firstOrNull?.rawValue;if(s!=null){Navigator.pop(ctx,s);}}))else TextField(decoration:const InputDecoration(labelText:'Paste QR code / token'),onChanged:(s)=>code=s),const SizedBox(height:12),if(canScan)TextButton.icon(onPressed:()=>up(()=>scanning=!scanning),icon:const Icon(Icons.qr_code_scanner),label:Text(scanning?'Use manual entry':'Scan with camera'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),if(!scanning)FilledButton(onPressed:()=>Navigator.pop(ctx,code),child:const Text('Verify pickup'))])));
   if(value!=null&&value.isNotEmpty){try{await widget.api.post('/api/bookings/${b['id']}/handover',{'code':value});if(mounted){journeyNotice(context,'Pickup verified',next:'The rental is active. Track payments and prepare for return inspection.');reload();}}catch(e){if(mounted)showError(context,e);}}
 }
 Future<void> bookingActions(Map b)async{await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Booking #${b['id']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text('${b['plate']}  •  ${b['customer_name']}'),const SizedBox(height:12),
   if(b['status']=='pending')ListTile(leading:const Icon(Icons.check_circle_outline),title:const Text('Confirm reservation'),onTap:(){Navigator.pop(ctx);setStatus(b,'confirmed');}),
   if(b['status']=='confirmed')ListTile(leading:const Icon(Icons.qr_code_2),title:const Text('Generate pickup QR'),onTap:(){Navigator.pop(ctx);showQr(b);}),
   if(b['status']=='confirmed')ListTile(leading:const Icon(Icons.key),title:const Text('Verify handover code'),onTap:(){Navigator.pop(ctx);handover(b);}),
   if(b['status']=='active')ListTile(leading:const Icon(Icons.check),title:const Text('Review return & settle in Rental Desk'),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Rental Desk')),body:Padding(padding:const EdgeInsets.all(16),child:RentalDeskPage(api:widget.api,bookingId:b['id'] as int,onCreate:()=>Navigator.pop(context))))));}),
   if(['pending','confirmed'].contains(b['status']))ListTile(leading:const Icon(Icons.cancel_outlined),title:const Text('Cancel booking'),onTap:(){Navigator.pop(ctx);setStatus(b,'cancelled');}),
   ListTile(leading:const Icon(Icons.fact_check_outlined),title:const Text('Pickup / return inspection'),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>InspectionPage(api:widget.api,bookingId:b['id'] as int)));}),
 ]))));}
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/bookings'),builder:(ctx,s){if(s.hasError)return Center(child:Text('Error: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:[heading('Reservations','Track pickup, return, QR verification and booking conflicts.',FilledButton.icon(icon:const Icon(Icons.add),label:const Text('New booking'),onPressed:add)),
   ContextualTip(icon:Icons.shield_outlined,title:'Booking checks happen in the background',
    description:'Availability conflicts are blocked automatically. Suspicious patterns are review flags, not fraud accusations.',
    action:'Review unusual patterns',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AnomaliesTool(api:widget.api)))),
   const SizedBox(height:12),Expanded(child:ListView(children:s.data!.map((b)=>Card(child:ListTile(onTap:()=>bookingActions(b),leading:const CircleAvatar(child:Icon(Icons.event_available)),title:Text('${b['plate']} — ${b['customer_name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${dateOnly(b['pickup_date'])} → ${dateOnly(b['return_date'])}  •  ${cash(b['total_amount'])}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[pill('${b['status']}'),const Icon(Icons.more_horiz,size:18)])))).toList()))]);});
}

class InspectionPage extends StatefulWidget{final DriveApi api;final int bookingId;const InspectionPage({super.key,required this.api,required this.bookingId});@override State<InspectionPage> createState()=>_InspectionPageState();}
class _InspectionPageState extends State<InspectionPage>{int version=0;String phase='pickup';final notes=TextEditingController();XFile? photo;bool busy=false;
 Future<void> takePhoto()async{try{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:65,maxWidth:1000);if(x!=null)setState(()=>photo=x);}catch(e){if(mounted)showError(context,e);}}
 Future<void> save()async{setState(()=>busy=true);try{final bytes=await photo?.readAsBytes();await widget.api.post('/api/inspections',{'booking_id':widget.bookingId,'phase':phase,'image_base64':bytes==null?null:base64Encode(bytes),'findings':notes.text.trim().isEmpty?[]:[notes.text.trim()],'reviewer_note':notes.text});if(mounted){toast(context,'Inspection saved');setState(()=>version++);}}catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Booking #${widget.bookingId} • Inspection')),body:ListView(padding:const EdgeInsets.all(18),children:[panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Before/after inspection',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:phase,items:['pickup','return'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>phase=x!)),const SizedBox(height:12),field(notes,'Visible scratches / dents and staff findings'),OutlinedButton.icon(onPressed:takePhoto,icon:const Icon(Icons.photo_camera),label:Text(photo==null?'Attach photo':'Selected: ${photo!.name}')),const SizedBox(height:10),FilledButton(onPressed:busy?null:save,child:const Text('Save inspection'))])),const SizedBox(height:14),FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/inspections?booking_id=${widget.bookingId}'),builder:(ctx,s){if(!s.hasData)return const LinearProgressIndicator();return Column(children:s.data!.map((e)=>panel(ListTile(leading:const Icon(Icons.fact_check),title:Text('${e['phase']} inspection'),subtitle:Text('${e['reviewer_note']??'No notes'}'),trailing:Text(dateOnly(e['created_at']))))).toList());})]));
 @override void dispose(){notes.dispose();super.dispose();}
}

class PaymentsPage extends StatefulWidget{final DriveApi api;const PaymentsPage({super.key,required this.api});@override State<PaymentsPage> createState()=>_PaymentsPageState();}
class _PaymentsPageState extends State<PaymentsPage>{int version=0;
 Future<void> add()async{final bookings=await widget.api.list('/api/bookings');if(!mounted||bookings.isEmpty)return;int booking=bookings.first['id'] as int;String method='cash';final amount=TextEditingController(),notes=TextEditingController();final yes=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Record payment'),content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(initialValue:booking,items:bookings.where((x)=>x['status']!='cancelled').map<DropdownMenuItem<int>>((b)=>DropdownMenuItem(value:b['id'] as int,child:Text('#${b['id']} ${b['plate']}'))).toList(),onChanged:(x)=>set(()=>booking=x!)),const SizedBox(height:12),field(amount,'Amount (LKR)',keyboard:TextInputType.number),DropdownButtonFormField<String>(initialValue:method,items:['cash','card','transfer','other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>set(()=>method=x!)),const SizedBox(height:12),field(notes,'Note') ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
 if(yes==true){try{await widget.api.post('/api/payments',{'booking_id':booking,'amount':num.tryParse(amount.text),'method':method,'note':notes.text});if(mounted){journeyNotice(context,'Payment recorded',next:'Rental Desk will show the updated outstanding balance.');setState(()=>version++);}}catch(e){if(mounted)showError(context,e);}}amount.dispose();notes.dispose();}
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/payments'),builder:(ctx,s){if(s.hasError)return Center(child:Text('Error: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:[heading('Payments','Record cash, card, and bank transfers.',FilledButton.icon(icon:const Icon(Icons.add),label:const Text('Add payment'),onPressed:add)),Expanded(child:ListView(children:s.data!.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.paid)),title:Text(cash(p['amount']),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('Booking #${p['booking_id']}  •  ${p['method']}  •  ${dateOnly(p['created_at'])}')))).toList()))]);});
}

class AlertsPage extends StatefulWidget{final DriveApi api;const AlertsPage({super.key,required this.api});@override State<AlertsPage> createState()=>_AlertsPageState();}
class _AlertsPageState extends State<AlertsPage>{int version=0;Future<void> run()async{try{final r=await widget.api.post('/api/notifications/run',{});if(mounted){journeyNotice(context,'Reminder checks complete',next:'${r['created']??0} new reminders created.');setState(()=>version++);}}catch(e){if(mounted)showError(context,e);}}
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(key:ValueKey(version),future:widget.api.list('/api/notifications'),builder:(ctx,s){if(s.hasError)return Center(child:Text('${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:[heading('Smart reminders','Insurance expiry, return dates, service reminders.',FilledButton.icon(onPressed:run,icon:const Icon(Icons.sync),label:const Text('Run checks'))),Expanded(child:ListView(children:[if(s.data!.isEmpty)panel(const Text('No reminders yet. Run checks to generate alerts.')),...s.data!.map((n)=>Card(child:ListTile(leading:Icon(n['kind']=='insurance'?Icons.shield_outlined:n['kind']=='maintenance'?Icons.build_circle_outlined:Icons.notifications_outlined),title:Text('${n['message']}'),subtitle:Text('${n['kind']}  •  ${dateOnly(n['created_at'])}'),trailing:n['is_read']==true||n['is_read']==1?const Icon(Icons.done_all):TextButton(onPressed:()async{try{await widget.api.patch('/api/notifications/${n['id']}/read',{});if(mounted){journeyNotice(context,'Reminder marked as read');setState(()=>version++);}}catch(e){if(mounted)showError(context,e);}},child:const Text('Mark read')))))]))]);});
}

// Compact, task-based utility hub. Everyday rental actions remain in their
// own workflows; users only see the chosen group here.
class SmartPage extends StatefulWidget {
  final DriveApi api;
  final VoidCallback? onNewRental;
  const SmartPage({super.key,required this.api,this.onNewRental});
  @override State<SmartPage> createState()=>_SmartPageState();
}

class _UtilityTool {
  final String title, shortLabel;
  final IconData icon;
  final Widget screen;
  final String? tag;
  const _UtilityTool(this.title,this.shortLabel,this.icon,this.screen,{this.tag});
}

class _SmartPageState extends State<SmartPage> {
  int activeGroup=0;
  static const groups=['Bookings','Vehicles','Insights'];
  static const groupIcons=[Icons.event_available_outlined,
    Icons.directions_car_filled_outlined,Icons.insights_rounded];

  List<_UtilityTool> tools(int group) => switch(group) {
    0 => [
      _UtilityTool('Price check','Check rental rates',Icons.price_check_rounded,PricingTool(api:widget.api)),
      _UtilityTool('Find a car','Match customer needs',Icons.manage_search_rounded,RecommendationTool(api:widget.api)),
      _UtilityTool('Review bookings','Check unusual activity',Icons.fact_check_outlined,AnomaliesTool(api:widget.api)),
    ],
    1 => [
      _UtilityTool('Scan document','License or number plate',Icons.document_scanner_outlined,OcrTool(api:widget.api),tag:'Setup needed'),
      _UtilityTool('Damage check','Review vehicle photos',Icons.car_crash_outlined,DamageTool(api:widget.api),tag:'Model needed'),
      _UtilityTool('Location log','Authorized locations',Icons.location_on_outlined,GeoTool(api:widget.api),tag:'Demo available'),
      _UtilityTool('Service due','Mileage and insurance',Icons.build_circle_outlined,MaintenanceTool(api:widget.api)),
    ],
    _ => [
      _UtilityTool('Rental trends','Forecast demand',Icons.trending_up_rounded,DemandTool(api:widget.api)),
      _UtilityTool('Fleet Q&A','Ask about the fleet',Icons.forum_outlined,AssistantTool(api:widget.api)),
    ],
  };

  void showHelp() => showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('About these tools'),
    content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:const Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Recommendations and pricing are already built into New rental.'),
      SizedBox(height:12),
      Text('OCR needs a supported engine. Damage checks need a trained model.'),
      SizedBox(height:12),
      Text('GPS demonstration points are simulated. Business forecasts and Q&A are advisory.'),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Got it'))],
  ));

  Widget toolCard(_UtilityTool tool,double width) => SizedBox(
    width:width,height:115,
    child:Material(color:DriveColors.surface,borderRadius:BorderRadius.circular(17),
      child:InkWell(
        borderRadius:BorderRadius.circular(17),
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>tool.screen)),
        child:Container(padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(border:Border.all(color:DriveColors.line),
            borderRadius:BorderRadius.circular(17)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(width:37,height:37,decoration:BoxDecoration(
                color:DriveColors.accent.withValues(alpha:.12),
                borderRadius:BorderRadius.circular(10)),
                child:Icon(tool.icon,color:DriveColors.accent,size:20)),
              const Spacer(),
              const Icon(Icons.arrow_outward_rounded,size:17,color:DriveColors.muted),
            ]),
            const Spacer(),
            Row(children:[Expanded(child:Column(mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(tool.title,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
              const SizedBox(height:2),
              Text(tool.shortLabel,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:11,color:DriveColors.muted)),
            ])),
            if(tool.tag!=null)Padding(padding:const EdgeInsets.only(left:6),
              child:Tooltip(message:tool.tag!,child:Icon(Icons.info_outline_rounded,
                size:16,color:DriveColors.warning))),
            ]),
          ]),
        ),
      ),
    ),
  );

  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){
    final items=tools(activeGroup);
    final cols=c.maxWidth>=930?3:c.maxWidth>=570?2:1;
    final cardWidth=(c.maxWidth-(cols-1)*12)/cols;
    return ListView(children:[
      Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Tools',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900)),
          SizedBox(height:4),
          Text('Choose what you need.',style:TextStyle(fontSize:12,color:DriveColors.muted)),
        ])),
        IconButton(tooltip:'About tools',onPressed:showHelp,
          icon:const Icon(Icons.help_outline_rounded)),
      ]),
      const SizedBox(height:20),
      Wrap(spacing:8,runSpacing:8,children:[
        for(int i=0;i<groups.length;i++)ChoiceChip(
          avatar:Icon(groupIcons[i],size:17,
            color:activeGroup==i?DriveColors.accent:DriveColors.muted),
          label:Text(groups[i]),
          selected:i==activeGroup,
          showCheckmark:false,
          selectedColor:DriveColors.tealDark,
          backgroundColor:DriveColors.surface,
          side:BorderSide(color:i==activeGroup?DriveColors.accent:DriveColors.line),
          labelStyle:TextStyle(fontWeight:FontWeight.w700,
            color:i==activeGroup?DriveColors.text:DriveColors.muted),
          onSelected:(_)=>setState(()=>activeGroup=i),
        ),
      ]),
      const SizedBox(height:18),
      Wrap(spacing:12,runSpacing:12,children:[for(final t in items)toolCard(t,cardWidth)]),
      const SizedBox(height:19),
      if(activeGroup==0 && widget.onNewRental!=null)
        OutlinedButton.icon(onPressed:widget.onNewRental,
          icon:const Icon(Icons.arrow_forward_rounded),
          label:const Text('Go to New rental')),
      if(activeGroup==1)
        const Padding(padding:EdgeInsets.only(top:5),
          child:Text('ⓘ  Some scanning features need extra setup.',
            style:TextStyle(fontSize:11,color:DriveColors.muted))),
      if(activeGroup==2)
        const Padding(padding:EdgeInsets.only(top:5),
          child:Text('ⓘ  Estimates support decisions; they are not guarantees.',
            style:TextStyle(fontSize:11,color:DriveColors.muted))),
    ]);
  });
}
class ToolScaffold extends StatelessWidget{final String title;final Widget child;const ToolScaffold({super.key,required this.title,required this.child});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title)),body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:child))));}
class PricingTool extends StatefulWidget{final DriveApi api;const PricingTool({super.key,required this.api});@override State<PricingTool> createState()=>_PricingToolState();}
class _PricingToolState extends State<PricingTool>{int? vehicle;final pickup=TextEditingController(),ret=TextEditingController();Map<String,dynamic>? result;bool loading=false;
 @override void initState(){super.initState();final d=DateTime.now().add(const Duration(days:5));pickup.text=DateFormat('yyyy-MM-dd').format(d);ret.text=DateFormat('yyyy-MM-dd').format(d.add(const Duration(days:3)));}
 Future<void> run()async{if(vehicle==null)return;setState(()=>loading=true);try{final r=await widget.api.map('/api/smart/pricing?vehicle_id=$vehicle&pickup_date=${pickup.text}&return_date=${ret.text}');if(mounted)setState(()=>result=r);}catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>loading=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'Smart pricing',child:Column(children:[panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Recommended daily rate',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:15),FutureBuilder<List<dynamic>>(future:widget.api.list('/api/vehicles'),builder:(c,s)=>DropdownButtonFormField<int>(initialValue:vehicle,decoration:const InputDecoration(labelText:'Vehicle'),items:(s.data??[]).map<DropdownMenuItem<int>>((e)=>DropdownMenuItem(value:e['id'] as int,child:Text('${e['plate']}  ${e['make']} ${e['model']}'))).toList(),onChanged:(v)=>setState(()=>vehicle=v))),const SizedBox(height:12),field(pickup,'Pickup date (YYYY-MM-DD)'),field(ret,'Return date (YYYY-MM-DD)'),FilledButton(onPressed:loading?null:run,child:Text(loading?'Calculating…':'Generate pricing recommendation'))])),
 if(result!=null)panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(cash(result!['recommended_daily_rate']),style:const TextStyle(fontSize:32,fontWeight:FontWeight.bold)),const Text('Recommended LKR per day'),const Divider(),Text('Estimated total: ${cash(result!['estimated_total'])}'),Text('Base daily rate: ${cash(result!['base_daily_rate'])}'),Text('Training observations: ${result!['training_samples']}'),Text('Method: ${result!['method']}'),const SizedBox(height:8),Text('${result!['note']}',style:const TextStyle(color:DriveColors.muted))]))]));
 @override void dispose(){pickup.dispose();ret.dispose();super.dispose();}
}
class RecommendationTool extends StatefulWidget{final DriveApi api;const RecommendationTool({super.key,required this.api});@override State<RecommendationTool> createState()=>_RecommendationToolState();}
class _RecommendationToolState extends State<RecommendationTool>{final budget=TextEditingController(text:'45000'),seats=TextEditingController(text:'5'),days=TextEditingController(text:'3'),category=TextEditingController(text:'SUV');List<dynamic> results=[];bool busy=false;
 Future<void> run()async{setState(()=>busy=true);try{final uri='/api/smart/recommendations?budget=${budget.text}&seats=${seats.text}&days=${days.text}&category=${Uri.encodeQueryComponent(category.text)}';final r=await widget.api.map(uri);if(mounted)setState(()=>results=List<dynamic>.from(r['results']));}catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'Vehicle recommendations',child:Column(children:[panel(Column(children:[field(budget,'Total budget (LKR)',keyboard:TextInputType.number),field(seats,'Minimum seats',keyboard:TextInputType.number),field(days,'Days',keyboard:TextInputType.number),field(category,'Preferred category'),FilledButton(onPressed:busy?null:run,child:const Text('Rank vehicles'))])),const SizedBox(height:14),...results.map((r)=>panel(ListTile(title:Text('${r['vehicle']} • ${r['plate']}'),subtitle:Text('${r['category']}  •  ${cash(r['price'])}\n${(r['reasons'] as List).join(' • ')}'),isThreeLine:true,trailing:CircleAvatar(child:Text('${r['score']}')))))]));
 @override void dispose(){budget.dispose();seats.dispose();days.dispose();category.dispose();super.dispose();}
}
class AnomaliesTool extends StatelessWidget{final DriveApi api;const AnomaliesTool({super.key,required this.api});@override Widget build(BuildContext context)=>ToolScaffold(title:'Booking anomaly signals',child:FutureBuilder<Map<String,dynamic>>(future:api.map('/api/smart/anomalies'),builder:(c,s){if(s.hasError)return Text('${s.error}');if(!s.hasData)return const CircularProgressIndicator();final list=s.data!['results'] as List;return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[panel(const Text('Heuristic and statistical review flags only. Never use as automatic fraud accusations.')),if(list.isEmpty)panel(const Text('No flagged bookings')),...list.map((r)=>panel(ListTile(leading:const Icon(Icons.report_problem_outlined,color:Colors.orange),title:Text('Booking #${r['booking_id']} • ${r['level']}'),subtitle:Text((r['flags'] as List).join('\n'))))) ]);}));}

class OcrTool extends StatefulWidget{final DriveApi api;const OcrTool({super.key,required this.api});@override State<OcrTool> createState()=>_OcrToolState();}
class _OcrToolState extends State<OcrTool>{String mode='plate',output='No scan yet';bool busy=false;
 Future<void> scan()async{try{final f=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1280,imageQuality:80);if(f==null)return;setState(()=>busy=true);
   String text;String engine;
   final mobile=!kIsWeb&&(defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS);
   if(mobile){final recognizer=TextRecognizer(script:TextRecognitionScript.latin);try{final input=InputImage.fromFilePath(f.path);text=(await recognizer.processImage(input)).text;engine='Google ML Kit (on-device)';}finally{await recognizer.close();}}
   else{final bytes=await f.readAsBytes();final r=await widget.api.post('/api/smart/ocr/$mode',{'image_base64':base64Encode(bytes)});text='${r['raw_text']}';engine='Tesseract (backend)';}
   final plate=RegExp(r'\b([A-Z]{2,3})\s*[- ]?\s*(\d{4})\b').firstMatch(text.toUpperCase());
   final license=RegExp(r'\b[A-Z]\d{7,9}\b').firstMatch(text.toUpperCase());
   if(mounted)setState(()=>output='Engine: $engine\nCandidate: ${mode=='plate'?(plate==null?'Not found':'${plate.group(1)}-${plate.group(2)}'):(license?.group(0)??'Not found')}\n\nRaw OCR:\n$text\n\nAlways verify manually before saving.');
 }catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'OCR: license and plate',child:Column(children:[panel(Column(children:[DropdownButtonFormField<String>(initialValue:mode,decoration:const InputDecoration(labelText:'Document type'),items:['plate','license'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(x)=>setState(()=>mode=x!)),const SizedBox(height:14),FilledButton.icon(onPressed:busy?null:scan,icon:const Icon(Icons.image_search),label:Text(busy?'Reading image…':'Choose photo and recognize')),const SizedBox(height:10),const Text('Android/iOS: on-device Google ML Kit. Windows/web: optional backend Tesseract must be installed.',style:TextStyle(color:DriveColors.muted,fontSize:12))])),panel(SelectableText(output))]));
}
class GeoTool extends StatefulWidget{final DriveApi api;const GeoTool({super.key,required this.api});@override State<GeoTool> createState()=>_GeoToolState();}
class _GeoToolState extends State<GeoTool>{int? vehicle;bool consent=false;bool busy=false;List<dynamic> logs=[];
 Future<void> run({required bool demo})async{if(vehicle==null||!consent){toast(context,'Choose a vehicle and confirm consent.',fail:true);return;}setState(()=>busy=true);
 try{double lat=6.9271,lng=79.8612;if(!demo){var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('Device location permission denied.');
   final pos=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high));lat=pos.latitude;lng=pos.longitude;}
   await widget.api.post('/api/locations',{'vehicle_id':vehicle,'latitude':lat,'longitude':lng,'source':demo?'simulated':'staff_manual','consent_confirmed':true,'geofence_center_lat':6.9271,'geofence_center_lng':79.8612,'geofence_radius_km':10});
   logs=await widget.api.list('/api/locations?vehicle_id=$vehicle');if(mounted)setState((){});
 }catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'Consent-based GPS logging',child:Column(children:[panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Location sources',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Text('The phone location is not the car location. A vehicle tracker and driver consent are required for live fleet tracking.'),const SizedBox(height:12),FutureBuilder<List<dynamic>>(future:widget.api.list('/api/vehicles'),builder:(c,s)=>DropdownButtonFormField<int>(initialValue:vehicle,decoration:const InputDecoration(labelText:'Vehicle'),items:(s.data??[]).map<DropdownMenuItem<int>>((v)=>DropdownMenuItem(value:v['id'] as int,child:Text('${v['plate']}'))).toList(),onChanged:(x)=>setState(()=>vehicle=x))),CheckboxListTile(contentPadding:EdgeInsets.zero,value:consent,onChanged:(x)=>setState(()=>consent=x??false),title:const Text('I confirm location-sharing consent and authorization')),Wrap(spacing:8,children:[FilledButton(onPressed:busy?null:()=>run(demo:false),child:const Text('Log device location')),OutlinedButton(onPressed:busy?null:()=>run(demo:true),child:const Text('SIMULATED demo point'))])])),const SizedBox(height:12),...logs.map((g)=>panel(ListTile(leading:const Icon(Icons.location_pin),title:Text('${g['latitude']}, ${g['longitude']}'),subtitle:Text('Source: ${g['source']}  •  ${dateOnly(g['recorded_at'])}'))))]));
}
class DamageTool extends StatefulWidget{final DriveApi api;const DamageTool({super.key,required this.api});@override State<DamageTool> createState()=>_DamageToolState();}
class _DamageToolState extends State<DamageTool>{String output='Attach vehicle photo to try trained YOLO damage model.';bool busy=false;
 Future<void> run()async{final image=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:65,maxWidth:1200);if(image==null)return;setState(()=>busy=true);
   try{final r=await widget.api.post('/api/smart/damage',{'image_base64':base64Encode(await image.readAsBytes())});if(mounted)setState(()=>output=const JsonEncoder.withIndent('  ').convert(r));}
   catch(e){if(mounted)setState(()=>output='$e\n\nNo trained damage model is packaged. This feature reports unavailable rather than inventing findings.');}
   finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'Damage detection AI',child:Column(children:[panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Optional AI model integration',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Connect a separately trained vehicle-damage YOLO weights file to optional_ai/service.py. Without one, the endpoint correctly returns service unavailable.'),const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:run,icon:const Icon(Icons.upload_file),label:const Text('Analyze vehicle photo'))])),panel(SelectableText(output))]));
}
class MaintenanceTool extends StatelessWidget{final DriveApi api;const MaintenanceTool({super.key,required this.api});@override Widget build(BuildContext context)=>ToolScaffold(title:'Maintenance & insurance checks',child:FutureBuilder<List<dynamic>>(future:api.list('/api/vehicles'),builder:(c,s){if(s.hasError)return Text('${s.error}');if(!s.hasData)return const CircularProgressIndicator();return Column(children:[panel(const Text('Rule-based warnings from odometer and insurance expiry. Predictive ML would require sensor and failure history.')),...s.data!.map((v){final distance=(num.tryParse('${v['service_due_km']}')??999999)-(num.tryParse('${v['mileage_km']}')??0);final flag=distance<=500;return panel(ListTile(leading:Icon(flag?Icons.warning_amber:Icons.build_circle_outlined,color:flag?Colors.orange:Colors.green),title:Text('${v['plate']}  ${v['make']} ${v['model']}'),subtitle:Text('Mileage: ${v['mileage_km']} km • Service in ${distance.toStringAsFixed(0)} km\nInsurance: ${dateOnly(v['insurance_expiry'])}'),isThreeLine:true,trailing:flag?pill('service due'):null));})]);}));}
class DemandTool extends StatelessWidget{final DriveApi api;const DemandTool({super.key,required this.api});@override Widget build(BuildContext context)=>ToolScaffold(title:'Demand forecast',child:FutureBuilder<Map<String,dynamic>>(future:api.map('/api/smart/forecast'),builder:(ctx,s){if(s.hasError)return Text('${s.error}');if(!s.hasData)return const CircularProgressIndicator();final r=s.data!;return Column(children:[panel(ListTile(title:Text('Method: ${r['method']}'),subtitle:Text('${r['note']}'))),const Align(alignment:Alignment.centerLeft,child:Text('Historical monthly rentals',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),...((r['history']??[]) as List).map((m)=>panel(ListTile(title:Text('${m['month']}'),trailing:Text('${m['bookings']} bookings')))),const Align(alignment:Alignment.centerLeft,child:Text('Next 3 months — estimated',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),...((r['forecast']??[]) as List).map((m)=>panel(ListTile(title:Text('${m['month']}'),trailing:Text('${m['predicted_bookings']} predicted'))))]);}));}
class AssistantTool extends StatefulWidget{final DriveApi api;const AssistantTool({super.key,required this.api});@override State<AssistantTool> createState()=>_AssistantToolState();}
class _AssistantToolState extends State<AssistantTool>{final msg=TextEditingController();final messages=<Map<String,String>>[];bool busy=false;
 Future<void> send()async{if(msg.text.trim().isEmpty)return;final text=msg.text;msg.clear();setState((){busy=true;messages.add({'role':'You','text':text});});try{final r=await widget.api.post('/api/smart/assistant',{'message':text});if(mounted)setState(()=>messages.add({'role':'DriveDesk','text':'${r['reply']}'}));}catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>ToolScaffold(title:'Fleet Q&A assistant',child:Column(children:[panel(const Text('Database-grounded rules only — not a generative AI model. For availability on exact dates, use the booking availability endpoint.')),for(final item in messages)panel(ListTile(title:Text('${item['role']}'),subtitle:Text('${item['text']}'))),const SizedBox(height:12),TextField(controller:msg,decoration:InputDecoration(labelText:'Ask: Show me SUV vehicles',suffixIcon:IconButton(onPressed:busy?null:send,icon:const Icon(Icons.send))),onSubmitted:(_)=>send())]));
 @override void dispose(){msg.dispose();super.dispose();}
}
