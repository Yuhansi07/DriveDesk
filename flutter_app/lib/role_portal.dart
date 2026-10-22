import 'package:flutter/material.dart';
import 'api.dart';
import 'drive_theme.dart';
import 'customer_portal.dart';

// Dedicated scoped workspaces: these accounts never receive the staff menu.
class RolePortal extends StatefulWidget {
  final DriveApi api;
  final Future<void> Function() onLogout;
  const RolePortal({super.key,required this.api,required this.onLogout});
  @override State<RolePortal> createState()=>_RolePortalState();
}
class _RolePortalState extends State<RolePortal>{
  late Future<List<dynamic>> data;
  late final bool customer;
  @override void initState(){super.initState();customer=widget.api.currentUser?['role']=='customer';reload();}
  void reload(){setState(()=>data=widget.api.list(customer?'/api/portal/bookings':'/api/driver/jobs'));}
  Future<void> say(String message,{bool error=false})async{
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),backgroundColor:error?Colors.red.shade800:DriveColors.tealDark,behavior:SnackBarBehavior.floating));
  }
  Future<void> requestBooking()async{
    try{
      final cars=await widget.api.list('/api/portal/vehicles');
      if(!mounted)return;
      if(cars.isEmpty){say('No available vehicles yet.',error:true);return;}
      int vehicleId=(cars.first as Map)['id'] as int;
      DateTime pickup=DateTime.now().add(const Duration(days:1));
      DateTime returning=pickup.add(const Duration(days:2));
      await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
        title:const Text('Request a rental'),
        content:SizedBox(width:390,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          DropdownButtonFormField<int>(value:vehicleId,decoration:const InputDecoration(labelText:'Choose a vehicle'),isExpanded:true,
            items:[for(final car in cars)DropdownMenuItem(value:car['id'] as int,child:Text('${car['make']} ${car['model']} · LKR ${car['daily_rate']}/day',overflow:TextOverflow.ellipsis))],
            onChanged:(v){if(v!=null)update(()=>vehicleId=v);}),
          const SizedBox(height:14),
          OutlinedButton.icon(icon:const Icon(Icons.calendar_today_outlined),label:Text('Pickup: ${pickup.year}-${pickup.month.toString().padLeft(2,'0')}-${pickup.day.toString().padLeft(2,'0')}'),
            onPressed:()async{final next=await showDatePicker(context:ctx,initialDate:pickup,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(next!=null)update((){pickup=next;if(!returning.isAfter(pickup))returning=pickup.add(const Duration(days:1));});}),
          const SizedBox(height:7),
          OutlinedButton.icon(icon:const Icon(Icons.event_available),label:Text('Return: ${returning.year}-${returning.month.toString().padLeft(2,'0')}-${returning.day.toString().padLeft(2,'0')}'),
            onPressed:()async{final next=await showDatePicker(context:ctx,initialDate:returning,firstDate:pickup.add(const Duration(days:1)),lastDate:pickup.add(const Duration(days:365)));if(next!=null)update(()=>returning=next);}),
          const SizedBox(height:12),const Text('The team will review and confirm this request.',style:TextStyle(color:DriveColors.muted,fontSize:12)),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:()async{
            String date(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
            try{await widget.api.post('/api/portal/bookings',{'vehicle_id':vehicleId,'pickup_date':date(pickup),'return_date':date(returning)});
              if(!ctx.mounted)return;Navigator.pop(ctx);reload();say('Rental request submitted. Awaiting staff confirmation.');
            }catch(e){say('$e',error:true);}
          },child:const Text('Request booking'))],
      )));
    }catch(e){say('$e',error:true);}
  }
  Future<void> driverInspection(int bookingId,String status)async{
    final note=TextEditingController();
    final phase=status=='confirmed'?'pickup':'return';
    try{
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('${phase=='pickup'?'Pickup':'Return'} inspection'),
        content:SizedBox(width:350,child:TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Vehicle condition notes',hintText:'Describe any visible damage or condition'))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:()async{try{await widget.api.post('/api/driver/jobs/$bookingId/inspection',{'phase':phase,'note':note.text.trim()});
            if(!ctx.mounted)return;Navigator.pop(ctx);say('Inspection saved. Rental team can continue handover.');reload();
          }catch(e){say('$e',error:true);}},child:const Text('Save inspection'))],
      ));
    }finally{note.dispose();}
  }
  @override Widget build(BuildContext context){
    if(customer)return CustomerPortal(api:widget.api,onLogout:widget.onLogout);
    final role=customer?'Customer':'Driver';
    return Scaffold(appBar:AppBar(title:Text('DriveDesk · $role'),actions:[
      IconButton(tooltip:'Refresh',onPressed:reload,icon:const Icon(Icons.refresh_rounded)),
      IconButton(tooltip:'Sign out',onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded)),
    ]),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:960),child:
      ListView(padding:const EdgeInsets.all(24),children:[
        Row(children:[const Icon(Icons.verified_user_outlined,color:DriveColors.accent,size:33),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Welcome, ${widget.api.currentUser?['name']??role}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:23)),
            Text(customer?'Your bookings and rental requests':'Only trips assigned to you',style:const TextStyle(color:DriveColors.muted)),
          ]))]),
        const SizedBox(height:22),
        if(customer)Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[
          const Expanded(child:Text('Need a vehicle? Request a rental in a few steps.',style:TextStyle(fontSize:15))),
          FilledButton.icon(onPressed:requestBooking,icon:const Icon(Icons.add),label:const Text('New request')),
        ]))),
        const SizedBox(height:18),
        Text(customer?'My bookings':'Assigned jobs',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20)),
        const SizedBox(height:12),
        FutureBuilder<List<dynamic>>(future:data,builder:(ctx,snap){
          if(snap.connectionState!=ConnectionState.done)return const Center(child:Padding(padding:EdgeInsets.all(35),child:CircularProgressIndicator()));
          if(snap.hasError)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Text('${snap.error}',style:const TextStyle(color:Colors.redAccent))));
          final rows=snap.data??[];
          if(rows.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('Nothing here yet.')));
          return Column(children:[for(final item in rows)Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text('${item['make']} ${item['model']} · ${item['plate']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),
              Chip(label:Text('${item['status']}'))]),
            const SizedBox(height:5),Text('${item['pickup_date']} → ${item['return_date']}',style:const TextStyle(color:DriveColors.muted)),
            if(customer)Text('LKR ${item['total_amount']}',style:const TextStyle(color:DriveColors.accent)),
            if(!customer)...[Text('Customer: ${item['customer_name']}',style:const TextStyle(color:DriveColors.muted)),
              if(item['status']=='confirmed'||item['status']=='active')Align(alignment:Alignment.centerRight,child:OutlinedButton.icon(
                onPressed:()=>driverInspection(item['id'] as int,'${item['status']}'),icon:const Icon(Icons.fact_check_outlined),label:const Text('Record condition')))],
          ]))) ]);
        }),
      ])))));
  }
}
