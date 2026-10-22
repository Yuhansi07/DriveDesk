import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'drive_theme.dart';

/// Customer-only workspace. Every request goes through the scoped /api/portal/* API.
/// Car photos are illustrative, not photographs of the particular fleet vehicle.
class CustomerPortal extends StatefulWidget {
  final DriveApi api;
  final Future<void> Function() onLogout;
  const CustomerPortal({super.key, required this.api, required this.onLogout});
  @override State<CustomerPortal> createState() => _CustomerPortalState();
}

class _CustomerPortalState extends State<CustomerPortal> {
  static const _pages = ['Home', 'Explore cars', 'My rentals', 'Updates', 'My profile'];
  static const _icons = [Icons.space_dashboard_rounded, Icons.directions_car_rounded,
    Icons.receipt_long_rounded, Icons.notifications_outlined, Icons.person_outline_rounded];
  static const _images = ['assets/cars/camry.jpg','assets/cars/range_rover.jpg',
    'assets/cars/bmw.jpg','assets/cars/mercedes.jpg','assets/cars/tesla.jpg','assets/cars/porsche.jpg'];
  static const _accent = DriveColors.accent;
  int current=0;
  bool loading=true;
  String? error;
  List<dynamic> vehicles=[];
  List<dynamic> bookings=[];
  List<dynamic> notifications=[];
  Map<String,dynamic> profile={};
  Map<String,dynamic> config={};
  String query='';
  String category='All';

  @override void initState(){super.initState();refresh();}
  String date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String lkr(dynamic amount) => 'LKR ${NumberFormatter.money(amount)}';
  Future<void> refresh({bool showSpinner=true}) async {
    if(showSpinner&&mounted)setState(() {loading=true;error=null;});
    try {
      final results=await Future.wait<dynamic>([
        widget.api.list('/api/portal/vehicles'),
        widget.api.list('/api/portal/bookings'),
        widget.api.list('/api/portal/notifications'),
        widget.api.map('/api/portal/me'),
        widget.api.map('/api/portal/config'),
      ]);
      if(!mounted)return;
      setState(() {vehicles=List<dynamic>.from(results[0]);bookings=List<dynamic>.from(results[1]);
        notifications=List<dynamic>.from(results[2]);profile=Map<String,dynamic>.from(results[3]);
        config=Map<String,dynamic>.from(results[4]);loading=false;error=null;});
    }catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }
  void toast(String message,{bool failed=false}){
    if(!mounted)return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Row(children:[Icon(failed?Icons.error_outline:Icons.check_circle_outline,color:Colors.white),
        const SizedBox(width:12),Expanded(child:Text(message))]),
      behavior:SnackBarBehavior.floating,duration:const Duration(seconds:4),
      backgroundColor:failed?const Color(0xFF973F46):DriveColors.tealDark,
    ));
  }
  Widget miniLabel(String value) => Text(value.toUpperCase(),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.4,color:DriveColors.muted));
  Widget pill(String label,{Color color=_accent})=>Container(
    padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
    decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(40),border:Border.all(color:color.withValues(alpha:.32))),
    child:Text(label,style:TextStyle(fontSize:11,color:color,fontWeight:FontWeight.w800)),
  );
  Color statusColor(String status) => switch(status){
    'completed'=>const Color(0xFF65D4A8), 'active'=>_accent, 'confirmed'=>const Color(0xFF8DC4FF),
    'cancelled'=>const Color(0xFFFF929A), _=>DriveColors.warning};
  Widget carPhoto(int index,{double height=162})=>Stack(children:[
    ClipRRect(borderRadius:BorderRadius.circular(15),child:Image.asset(_images[index%_images.length],
      height:height,width:double.infinity,fit:BoxFit.cover,
      errorBuilder:(_,__,___)=>Container(height:height,color:DriveColors.raised,child:const Center(child:Icon(Icons.directions_car,size:70,color:DriveColors.accent))))),
    Positioned(right:9,bottom:8,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
      decoration:BoxDecoration(color:Colors.black.withValues(alpha:.75),borderRadius:BorderRadius.circular(7)),
      child:const Text('Illustrative image',style:TextStyle(color:Colors.white70,fontSize:9))))
  ]);
  Widget metric(String title,String value,IconData icon)=>Container(
    padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:DriveColors.surface,
      borderRadius:BorderRadius.circular(18),border:Border.all(color:DriveColors.line)),
    child:Row(children:[Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(
      color:DriveColors.tealDark.withValues(alpha:.3),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:_accent)),
      const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
        Text(title,style:const TextStyle(color:DriveColors.muted,fontSize:12)),
      ]))]));

  Widget hero() => Container(
    decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[Color(0xFF15443F),Color(0xFF1B292D),Color(0xFF111A1D)]),
      borderRadius:BorderRadius.circular(25),border:Border.all(color:DriveColors.tealDark)),
    padding:const EdgeInsets.all(25),
    child:LayoutBuilder(builder:(ctx,constraints){
      final narrow=constraints.maxWidth<640;
      final copy=Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        pill('DRIVEDESK · CUSTOMER'),const SizedBox(height:18),
        Text('Find your next drive.',style:TextStyle(fontSize:narrow?29:39,fontWeight:FontWeight.w900,letterSpacing:-.9)),
        const SizedBox(height:8),const Text('Explore the fleet. Book in minutes.',style:TextStyle(fontSize:14,color:DriveColors.muted)),
        const SizedBox(height:24),FilledButton.icon(onPressed:()=>setState(()=>current=1),
          icon:const Icon(Icons.arrow_forward_rounded),label:const Text('Explore vehicles')),
      ]);
      return narrow?copy:Row(children:[Expanded(flex:3,child:copy),const SizedBox(width:16),
        Expanded(flex:2,child:Icon(Icons.directions_car_filled_rounded,size:142,color:_accent.withValues(alpha:.48)))]);
    }),
  );
  Widget home(){
    final upcoming=bookings.where((x)=>['pending','confirmed'].contains(x['status'])).length;
    final active=bookings.where((x)=>x['status']=='active').length;
    final unread=notifications.where((x)=>x['is_read']==0||x['is_read']==false).length;
    final display=vehicles.take(3).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      hero(),const SizedBox(height:19),
      LayoutBuilder(builder:(ctx,size)=>Wrap(spacing:12,runSpacing:12,children:[
        SizedBox(width:size.maxWidth<580?size.maxWidth:(size.maxWidth-24)/3,child:metric('Upcoming',upcoming.toString(),Icons.event_available_rounded)),
        SizedBox(width:size.maxWidth<580?size.maxWidth:(size.maxWidth-24)/3,child:metric('Active rentals',active.toString(),Icons.car_rental_rounded)),
        SizedBox(width:size.maxWidth<580?size.maxWidth:(size.maxWidth-24)/3,child:metric('New updates',unread.toString(),Icons.notifications_active_outlined)),
      ])),const SizedBox(height:24),
      heading('Popular choices',action:'View all',onTap:()=>setState(()=>current=1)),
      const SizedBox(height:13),carGrid(display),
      if(bookings.isNotEmpty)...[const SizedBox(height:24),heading('Your latest rental',action:'My rentals',onTap:()=>setState(()=>current=2)),
        const SizedBox(height:12),bookingCard(bookings.first)],
    ]);
  }
  Widget heading(String name,{String? action,VoidCallback? onTap})=>Row(children:[
    Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:21))),
    if(action!=null)TextButton(onPressed:onTap,child:Text(action)),
  ]);
  Widget carGrid(List<dynamic> rows){
    if(rows.isEmpty)return const Padding(padding:EdgeInsets.all(20),child:Text('No vehicles match your search.',style:TextStyle(color:DriveColors.muted)));
    return LayoutBuilder(builder:(ctx,s){
      final cols=s.maxWidth>1000?3:s.maxWidth>630?2:1;
      final width=(s.maxWidth-(cols-1)*14)/cols;
      return Wrap(spacing:14,runSpacing:14,children:[for(int i=0;i<rows.length;i++)SizedBox(width:width,child:carCard(Map<String,dynamic>.from(rows[i]),i))]);
    });
  }
  Widget carCard(Map<String,dynamic> car,int index)=>Container(
    padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:DriveColors.surface,borderRadius:BorderRadius.circular(20),
      border:Border.all(color:DriveColors.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        carPhoto(index),const SizedBox(height:13),Row(children:[Expanded(child:Text('${car['make']} ${car['model']}',
          maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))),pill('${car['category']}')]),
        const SizedBox(height:5),Text('${car['year']} · ${car['seats']} seats',style:const TextStyle(color:DriveColors.muted,fontSize:12)),
        const SizedBox(height:14),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(lkr(car['daily_rate']),style:const TextStyle(color:_accent,fontWeight:FontWeight.w900,fontSize:19)),
          const Text('per rental day',style:TextStyle(color:DriveColors.muted,fontSize:11))])),
          FilledButton.tonalIcon(onPressed:()=>vehicleDetails(car,index),icon:const Icon(Icons.arrow_forward,size:16),label:const Text('Details'))])
      ]));
  Widget explore(){
    final cats=<String>{'All',...vehicles.map((x)=>'${x['category']}')}.toList();
    final filtered=vehicles.where((x){final car=Map<String,dynamic>.from(x);
      return (category=='All'||car['category']==category) &&
        ('${car['make']} ${car['model']} ${car['category']}'.toLowerCase().contains(query.toLowerCase()));}).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      heading('Explore the fleet'),const SizedBox(height:4),
      const Text('Browse cars and check availability for your travel dates.',style:TextStyle(color:DriveColors.muted)),
      const SizedBox(height:19),TextField(onChanged:(v)=>setState(()=>query=v),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search by model, make or category')),
      const SizedBox(height:12),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final c in cats)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState(()=>category=c)))
      ])),const SizedBox(height:16),carGrid(filtered),
    ]);
  }
  Future<void> vehicleDetails(Map<String,dynamic> car,int index)async{
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(ctx)=>Dialog(
      insetPadding:const EdgeInsets.all(15),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),
        child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(22),child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text('${car['make']} ${car['model']}',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900))),
              IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),
            const SizedBox(height:9),carPhoto(index,height:230),const SizedBox(height:17),
            Wrap(spacing:8,children:[pill('${car['category']}'),pill('${car['seats']} seats'),pill('${car['year']}')]),
            const SizedBox(height:15),Text('${lkr(car['daily_rate'])} / day',style:const TextStyle(color:_accent,fontSize:24,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),const Text('Your dates are checked against existing reservations before the request is saved.',style:TextStyle(color:DriveColors.muted)),
            const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){Navigator.pop(ctx);bookVehicle(car);},
              icon:const Icon(Icons.calendar_month),label:const Text('Choose dates & request')))
          ]))))));
  }
  Future<void> bookVehicle(Map<String,dynamic> car)async{
    DateTime from=DateUtils.dateOnly(DateTime.now()).add(const Duration(days:3));
    DateTime until=from.add(const Duration(days:2));
    bool sending=false;
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(dialogCtx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:const Text('Request your rental'),
      content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${car['make']} ${car['model']}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:13),OutlinedButton.icon(onPressed:sending?null:()async{
          final next=await pickDriveDates(dialogCtx,DateTimeRange(start:from,end:until));
          if(next!=null)setDialog((){from=next.start;until=next.end;});
        },icon:const Icon(Icons.date_range),label:Text('${date(from)}  →  ${date(until)}')),
        const SizedBox(height:13),
        Text('${until.difference(from).inDays} day(s) · Estimated ${lkr((num.tryParse('${car['daily_rate']}')??0)*until.difference(from).inDays)}',
          style:const TextStyle(fontWeight:FontWeight.w800,color:_accent)),
        const SizedBox(height:10),const Text('This sends a pending request. A rental agent confirms availability and handover.',
          style:TextStyle(color:DriveColors.muted,fontSize:12)),
      ])),
      actions:[TextButton(onPressed:sending?null:()=>Navigator.pop(dialogCtx),child:const Text('Back')),
        FilledButton(onPressed:sending?null:()async{
          setDialog(()=>sending=true);
          try{
            await widget.api.post('/api/portal/bookings',{'vehicle_id':car['id'],'pickup_date':date(from),'return_date':date(until)});
            if(!dialogCtx.mounted)return;
            Navigator.pop(dialogCtx);await refresh(showSpinner:false);
            if(mounted){setState(()=>current=2);toast('Request submitted! You can follow it under My rentals.');}
          }catch(e){if(dialogCtx.mounted)setDialog(()=>sending=false);toast(e.toString(),failed:true);}
        },child:Text(sending?'Submitting...':'Send request'))],
    )));
  }
  Widget bookingCard(dynamic item){
    final b=Map<String,dynamic>.from(item);
    final status='${b['status']}';
    final total=(num.tryParse('${b['total_amount']}')??0).toDouble();
    final paid=(num.tryParse('${b['paid_amount']}')??0).toDouble();
    final balance=(total-paid).clamp(0,total);
    final pickupDate = DateTime.tryParse('${b['pickup_date']}');
    final canCancel = ['pending', 'confirmed'].contains(status) &&
        pickupDate != null &&
        pickupDate.isAfter(DateUtils.dateOnly(DateTime.now()));
    final canDemoPay=config['demo_payments']==true && !['cancelled','completed'].contains(status)&&balance>.01;
    return Container(margin:const EdgeInsets.only(bottom:13),padding:const EdgeInsets.all(19),
      decoration:BoxDecoration(color:DriveColors.surface,border:Border.all(color:DriveColors.line),borderRadius:BorderRadius.circular(19)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.car_rental_rounded,color:_accent,size:29),const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${b['make']} ${b['model']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
            Text('#${b['id']} · ${b['plate']}',style:const TextStyle(color:DriveColors.muted,fontSize:12))])),
          pill(status.toUpperCase(),color:statusColor(status)),
        ]),const SizedBox(height:14),
        Text('${b['pickup_date']} → ${b['return_date']} · ${b['days']} days',style:const TextStyle(color:DriveColors.muted)),
        const SizedBox(height:8),Row(children:[Expanded(child:Text('Total ${lkr(total)}',style:const TextStyle(fontWeight:FontWeight.w800))),
          Text('Due ${lkr(balance)}',style:const TextStyle(color:_accent,fontWeight:FontWeight.w800))]),
        if(status=='cancelled'&&b['refund_status']=='manual_review')const Padding(padding:EdgeInsets.only(top:7),
          child:Text('Paid amount: refund requires staff review (not automatic).',style:TextStyle(color:DriveColors.warning,fontSize:12))),
        const Divider(height:25),Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(onPressed:()=>showStatement(b['id'] as int),icon:const Icon(Icons.receipt_long_outlined,size:17),label:const Text('Statement')),
          if(status=='active')OutlinedButton.icon(onPressed:()=>track(b['id'] as int),icon:const Icon(Icons.location_on_outlined,size:17),label:const Text('Tracking')),
          if(canDemoPay)FilledButton.tonalIcon(onPressed:()=>demoPayment(b['id'] as int,balance),icon:const Icon(Icons.payments_outlined,size:17),label:const Text('Demo payment')),
          if(canCancel)TextButton.icon(onPressed:()=>cancelBooking(b['id'] as int),icon:const Icon(Icons.cancel_outlined,size:17),label:const Text('Cancel request')),
        ]),
      ]));
  }
  Widget rentals(){
    final future=bookings.where((x)=>['pending','confirmed','active'].contains(x['status'])).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      heading('My rentals'),const SizedBox(height:4),
      const Text('Your requests, current rentals and payment statements.',style:TextStyle(color:DriveColors.muted)),
      const SizedBox(height:19),
      if(bookings.isEmpty)emptyState(Icons.calendar_today_rounded,'No reservations yet','Explore cars to make your first request.',onTap:()=>setState(()=>current=1))
      else ...[
        if(future.isNotEmpty)miniLabel('OPEN RENTALS'),const SizedBox(height:8),for(final b in future)bookingCard(b),
        const SizedBox(height:14),miniLabel('HISTORY'),const SizedBox(height:8),
        ...bookings.where((x)=>!['pending','confirmed','active'].contains(x['status'])).map(bookingCard),
      ],
    ]);
  }
  Widget emptyState(IconData icon,String title,String subtitle,{VoidCallback? onTap})=>
    Container(width:double.infinity,padding:const EdgeInsets.all(35),decoration:BoxDecoration(color:DriveColors.surface,
      border:Border.all(color:DriveColors.line),borderRadius:BorderRadius.circular(20)),
      child:Column(children:[Icon(icon,color:_accent,size:40),const SizedBox(height:13),Text(title,
        style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:5),
        Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:DriveColors.muted)),
        if(onTap!=null)...[const SizedBox(height:14),FilledButton(onPressed:onTap,child:const Text('Explore cars'))]]));
  Future<void> cancelBooking(int id)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Cancel this booking?'),
      content:const Text('Cancellation is available before pickup day for pending and confirmed requests. If money was recorded, staff must review any refund manually.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Keep booking')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cancel booking'))]));
    if(yes!=true)return;
    try{
      final out=await widget.api.post('/api/portal/bookings/$id/cancel',{});
      await refresh(showSpinner:false);
      toast(out['refund_status']=='manual_review'?'Cancelled. Refund needs staff review.':'Booking cancelled successfully.');
    }catch(e){toast('$e',failed:true);}
  }
  Future<void> demoPayment(int id,num balance)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Simulated payment'),
      content:Text('This records a DEMO payment of ${lkr(balance)} for the interview showcase. No card is charged. No real funds move.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Back')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Simulate payment'))]));
    if(yes!=true)return;
    try{await widget.api.post('/api/portal/bookings/$id/demo-pay',{});await refresh(showSpinner:false);
      toast('Demo payment recorded. No real money charged.');
    }catch(e){toast('$e',failed:true);}
  }
  Future<void> showStatement(int id)async{
    try{
      final statement=await widget.api.map('/api/portal/bookings/$id/invoice');
      if(!mounted)return;
      String row(String label,Object? value) => '$label: ${value??'-'}';
      final summary=[row('Statement',statement['invoice_number']),row('Customer',statement['customer']),
        row('Vehicle',statement['vehicle']),row('Pickup',statement['pickup_date']),row('Return',statement['return_date']),
        row('Rental amount',lkr(statement['total'])),row('Paid',lkr(statement['paid'])),row('Balance',lkr(statement['balance'])),
        row('Booking status',statement['status']),'Demo payments are not real funds.'].join('\n');
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('Statement ${statement['invoice_number']}'),
        content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:SingleChildScrollView(
          child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${statement['vehicle']} · ${statement['plate']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
            const SizedBox(height:13),
            infoRow('Rental dates','${statement['pickup_date']} → ${statement['return_date']}'),
            infoRow('Total',lkr(statement['total'])),infoRow('Paid',lkr(statement['paid'])),infoRow('Balance',lkr(statement['balance'])),
            const Divider(),
            const Text('Payments on file',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),
            for(final pay in (statement['payments'] as List<dynamic>))Padding(padding:const EdgeInsets.only(bottom:5),
              child:Text('${pay['method']} · ${lkr(pay['amount'])}',style:const TextStyle(color:DriveColors.muted))),
            if((statement['payments'] as List).isEmpty)const Text('No payments recorded',style:TextStyle(color:DriveColors.muted)),
            const SizedBox(height:10),const Text('Rental statement only. Not a tax invoice or payment gateway receipt.',
              style:TextStyle(fontSize:11,color:DriveColors.muted)),
          ]))),
        actions:[TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:summary));
          if(ctx.mounted)Navigator.pop(ctx);toast('Statement copied.');},icon:const Icon(Icons.copy),label:const Text('Copy statement')),
          FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Done'))],
      ));
    }catch(e){toast('$e',failed:true);}
  }
  Widget infoRow(String label,String value)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Row(children:[
    Expanded(child:Text(label,style:const TextStyle(color:DriveColors.muted))),Text(value,style:const TextStyle(fontWeight:FontWeight.w800))]));
  Future<void> track(int id)async{
    try{
      final response=await widget.api.map('/api/portal/bookings/$id/location');
      if(!mounted)return;
      final position=response['position'];
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Vehicle tracking'),
        content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Icon(response['available']==true?Icons.location_on:Icons.gps_off_rounded,size:43,color:_accent),
          const SizedBox(height:14),Text(response['available']==true?'Tracker connected':'Live location unavailable',
            style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
          const SizedBox(height:9),Text(response['available']==true?
            '${position['latitude']}, ${position['longitude']} (last verified tracker position)':'${response['reason']}',
            textAlign:TextAlign.center,style:const TextStyle(color:DriveColors.muted)),
          const SizedBox(height:11),const Text('Demo/manual locations are never displayed as live tracking.',
            textAlign:TextAlign.center,style:TextStyle(color:DriveColors.muted,fontSize:11)),
        ])),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
    }catch(e){toast('$e',failed:true);}
  }
  Widget updates(){
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      heading('Updates'),const SizedBox(height:4),const Text('Status changes and payment activity for your own bookings.',
        style:TextStyle(color:DriveColors.muted)),const SizedBox(height:20),
      if(notifications.isEmpty)emptyState(Icons.notifications_none,'No updates yet','Your booking updates appear here.'),
      for(final n in notifications)Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(color:DriveColors.surface,borderRadius:BorderRadius.circular(15),border:Border.all(color:DriveColors.line)),
        child:Row(children:[Icon((n['is_read']==0||n['is_read']==false)?Icons.notifications_active:Icons.notifications_none,
          color:(n['is_read']==0||n['is_read']==false)?_accent:DriveColors.muted),const SizedBox(width:13),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${n['message']}',
            style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:5),
            Text('${n['created_at']}',style:const TextStyle(color:DriveColors.muted,fontSize:11))])),
          if(n['is_read']==0||n['is_read']==false)TextButton(onPressed:()async{
            try{await widget.api.patch('/api/portal/notifications/${n['id']}/read',{});await refresh(showSpinner:false);}
            catch(e){toast('$e',failed:true);}
          },child:const Text('Mark read')),
        ])),
    ]);
  }
  Widget profilePage(){
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      heading('My profile'),const SizedBox(height:5),
      const Text('Keep your contact and licence details current.',style:TextStyle(color:DriveColors.muted)),
      const SizedBox(height:20),Container(width:double.infinity,padding:const EdgeInsets.all(22),
        decoration:BoxDecoration(color:DriveColors.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:DriveColors.line)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const CircleAvatar(radius:29,backgroundColor:DriveColors.tealDark,child:Icon(Icons.person,size:29,color:Colors.white)),
          const SizedBox(height:13),Text('${profile['name']??''}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
          const SizedBox(height:14),infoRow('Email','${profile['email']??''}'),
          infoRow('Phone','${profile['phone']??''}'),
          infoRow('Licence','${profile['license_no']??''}'),
          infoRow('Expiry','${profile['license_expiry']??'Not provided'}'),
          const SizedBox(height:10),FilledButton.icon(onPressed:editProfile,icon:const Icon(Icons.edit_outlined),label:const Text('Edit profile')),
          const SizedBox(height:12),const Text('Licence details are customer-provided. Staff verify documents at handover.',
            style:TextStyle(color:DriveColors.muted,fontSize:11)),
        ])),
    ]);
  }
  Future<void> editProfile() async {
    final name=TextEditingController(text:'${profile['name']??''}');
    final phone=TextEditingController(text:'${profile['phone']??''}');
    final email=TextEditingController(text:'${profile['email']??''}');
    final license=TextEditingController(text:'${profile['license_no']??''}');
    final expiry=TextEditingController(text:'${profile['license_expiry']??''}');
    bool saving=false;
    try{
      await showDialog<void>(context:context,builder:(dialogCtx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
        title:const Text('Edit your profile'),
        content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),
          const SizedBox(height:11),TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone number')),
          const SizedBox(height:11),TextField(controller:email,decoration:const InputDecoration(labelText:'Email / login')),
          const SizedBox(height:11),TextField(controller:license,decoration:const InputDecoration(labelText:'Driving licence number')),
          const SizedBox(height:11),TextField(controller:expiry,decoration:const InputDecoration(labelText:'Expiry date (YYYY-MM-DD), optional')),
        ]))),
        actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(dialogCtx),child:const Text('Cancel')),
          FilledButton(onPressed:saving?null:()async{
            setDialog(()=>saving=true);
            try{
              await widget.api.patch('/api/portal/me',{'name':name.text.trim(),'phone':phone.text.trim(),
                'email':email.text.trim(),'license_no':license.text.trim(),'license_expiry':expiry.text.trim()});
              if(!dialogCtx.mounted)return;
              Navigator.pop(dialogCtx);await refresh(showSpinner:false);
              toast('Profile saved successfully.');
            }catch(e){if(dialogCtx.mounted)setDialog(()=>saving=false);toast('$e',failed:true);}
          },child:Text(saving?'Saving...':'Save changes'))],
      )));
    }finally{name.dispose();phone.dispose();email.dispose();license.dispose();expiry.dispose();}
  }
  Widget layout(){
    final page=switch(current){0=>home(),1=>explore(),2=>rentals(),3=>updates(),_=>profilePage()};
    return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1230),
      child:ListView(padding:const EdgeInsets.fromLTRB(22,25,22,36),children:[
        Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Good to see you, ${('${profile['name']??'Driver'}').split(' ').first} 👋',
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:23)),
          Text(_pages[current],style:const TextStyle(color:DriveColors.muted,fontSize:13)),
        ])),IconButton(tooltip:'Refresh',onPressed:()=>refresh(),icon:const Icon(Icons.refresh_rounded))]),
        const SizedBox(height:24),page,
      ])));
  }
  Widget navTile(int i)=>ListTile(
    selected:current==i,selectedTileColor:DriveColors.tealDark.withValues(alpha:.32),
    selectedColor:_accent,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
    leading:Icon(_icons[i]),title:Text(_pages[i],style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
    onTap:()=>setState(()=>current=i));
  @override Widget build(BuildContext context){
    final desktop=MediaQuery.sizeOf(context).width>=850;
    return Scaffold(
      appBar:AppBar(toolbarHeight:67,title:Row(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:DriveColors.tealDark,borderRadius:BorderRadius.circular(9)),
          child:const Icon(Icons.directions_car_filled_rounded,color:Colors.white)),
        const SizedBox(width:11),const Text('DriveDesk',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:-.5)),
        const SizedBox(width:7),const Text('RENTALS',style:TextStyle(color:DriveColors.accent,fontWeight:FontWeight.w900,fontSize:10)),
      ]),actions:[IconButton(tooltip:'Sign out',onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded)),const SizedBox(width:10)]),
      bottomNavigationBar:desktop?null:NavigationBar(height:74,selectedIndex:current,onDestinationSelected:(i)=>setState(()=>current=i),
        destinations:[for(int i=0;i<_pages.length;i++)NavigationDestination(icon:Icon(_icons[i]),label:switch(i){1=>'Explore',2=>'Rentals',3=>'Updates',4=>'Profile',_=>'Home'})]),
      body:Row(children:[
        if(desktop)Container(width:218,color:DriveColors.sidebar,padding:const EdgeInsets.all(15),child:Column(children:[
          const SizedBox(height:13),for(int i=0;i<_pages.length;i++)Padding(padding:const EdgeInsets.only(bottom:5),child:navTile(i)),
          const Spacer(),const Divider(),const Padding(padding:EdgeInsets.all(10),child:Text('Customer workspace',style:TextStyle(color:DriveColors.muted,fontSize:11))),
        ])),
        Expanded(child:loading?const Center(child:CircularProgressIndicator()):
          error!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.wifi_off_rounded,size:36,color:DriveColors.warning),
            const SizedBox(height:10),Text('Could not load portal: $error',textAlign:TextAlign.center),
            const SizedBox(height:12),FilledButton(onPressed:refresh,child:const Text('Try again'))])):layout()),
      ]),
    );
  }
}
class NumberFormatter {
  static String money(dynamic v){
    final n=num.tryParse('$v')??0;
    final parts=n.toStringAsFixed(2).split('.');
    final whole=parts[0];
    final chars=<String>[];
    for(int i=whole.length-1;i>=0;i--){chars.insert(0,whole[i]);if(i>0&&(whole.length-i)%3==0)chars.insert(0,',');}
    return '${chars.join()}.${parts[1]}';
  }
}
