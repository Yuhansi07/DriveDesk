import 'package:flutter/material.dart';
import 'api.dart';
import 'drive_theme.dart';

// Role labels aligned with api/access.js. Shared by both dialogs and the team list.
const Map<String, String> teamRoles = {
  'admin': 'Administrator',
  'manager': 'Operations Manager',
  'rental_agent': 'Rental Agent',
  'fleet_officer': 'Fleet Officer',
  'finance_officer': 'Finance Officer',
  'driver': 'Driver',
  'customer': 'Customer',
};

// Administrators manage accounts; customer login profiles link to customer records.
// All permissions are enforced by the backend, not just hidden menu items.
class TeamPage extends StatefulWidget {
  final DriveApi api;
  const TeamPage({super.key, required this.api});
  @override State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late Future<List<dynamic>> users;
  late Future<List<dynamic>> customers;
  @override void initState() {super.initState();users=widget.api.list('/api/users');customers=widget.api.list('/api/customers');}
  void refresh() {setState(() => users=widget.api.list('/api/users'));}
  void notice(String message, {bool error=false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(message), backgroundColor:error?const Color(0xFF93383A):DriveColors.tealDark,
      behavior:SnackBarBehavior.floating,
    ));
  }
  Future<void> submit(Future<dynamic> Function() action, String success) async {
    try {await action(); if(!mounted)return; Navigator.of(context).pop(); notice(success);refresh();}
    catch(e){notice('$e',error:true);}
  }
  Future<void> add() async {
    final name=TextEditingController(),email=TextEditingController(),password=TextEditingController();
    String role='rental_agent';
    int? customerId;
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,rebuild)=>AlertDialog(
      title:const Text('Add team member'),
      content:SizedBox(width:400,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),
        const SizedBox(height:12),
        TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Work email')),
        const SizedBox(height:12),
        TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Temporary password (8+ characters)')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Access level'),
          items:[for(final item in teamRoles.entries)DropdownMenuItem(value:item.key,child:Text(item.value))],
          onChanged:(v){if(v!=null)rebuild(()=>role=v);}),
        if(role=='customer')...[
          const SizedBox(height:12),
          FutureBuilder<List<dynamic>>(future:customers,builder:(ctx,snap)=>DropdownButtonFormField<int>(
            value:customerId,decoration:const InputDecoration(labelText:'Link customer profile'),
            items:[for(final c in snap.data??[])DropdownMenuItem<int>(value:c['id'] as int,child:Text('${c['name']} · #${c['id']}'))],
            onChanged:(v)=>rebuild(()=>customerId=v),
          )),
        ],
        const SizedBox(height:12),
        const Text('Share the temporary password privately. Ask the user to change it after logging in.',style:TextStyle(fontSize:12,color:DriveColors.muted)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>submit(()=>widget.api.post('/api/users',{
          'name':name.text.trim(),'email':email.text.trim(),'password':password.text,'role':role,
          if(role=='customer')'customer_id':customerId,
        }),'User created — they can now sign in.'),child:const Text('Create user'))],
    )));
    name.dispose();email.dispose();password.dispose();
  }
  Future<void> edit(Map<String,dynamic> member) async {
    final name=TextEditingController(text:'${member['name']}');
    final email=TextEditingController(text:'${member['email']}');
    String role='${member['role']}';
    int? customerId=member['customer_id'] as int?;
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,rebuild)=>AlertDialog(
      title:const Text('Edit account'),
      content:SizedBox(width:400,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),
        const SizedBox(height:12),
        TextField(controller:email,decoration:const InputDecoration(labelText:'Work email')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Role'),
          items:[for(final item in teamRoles.entries)DropdownMenuItem(value:item.key,child:Text(item.value))],
          onChanged:(v){if(v!=null)rebuild(()=>role=v);}),
        if(role=='customer')...[
          const SizedBox(height:12),
          FutureBuilder<List<dynamic>>(future:customers,builder:(ctx,snap)=>DropdownButtonFormField<int>(
            value:customerId,decoration:const InputDecoration(labelText:'Linked customer profile'),
            items:[for(final c in snap.data??[])DropdownMenuItem<int>(value:c['id'] as int,child:Text('${c['name']} · #${c['id']}'))],
            onChanged:(v)=>rebuild(()=>customerId=v),
          )),
        ],
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>submit(()=>widget.api.patch('/api/users/${member['id']}',{
          'name':name.text.trim(),'email':email.text.trim(),'role':role,
          if(role=='customer')'customer_id':customerId,
        }),'Account updated.'),child:const Text('Save changes'))],
    )));
    name.dispose();email.dispose();
  }
  Future<void> resetPassword(Map<String,dynamic> member) async {
    final password=TextEditingController();
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Reset password · ${member['name']}'),
      content:SizedBox(width:390,child:TextField(controller:password,obscureText:true,
        decoration:const InputDecoration(labelText:'New password (8+ characters)'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>submit(()=>widget.api.patch('/api/users/${member['id']}/password',
          {'password':password.text}),'Password reset. Previous sessions signed out.'),child:const Text('Reset'))],
    ));
    password.dispose();
  }
  Future<void> toggle(Map<String,dynamic> member) async {
    final active=member['is_active']==true||member['is_active']==1;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(active?'Suspend account?':'Reactivate account?'),
      content:Text(active?'${member['name']} will lose access and be signed out.':'${member['name']} will be able to sign in again.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(active?'Suspend':'Reactivate'))],
    ));
    if(confirmed!=true)return;
    try{await widget.api.patch('/api/users/${member['id']}',{'is_active':!active});
      notice(active?'Account suspended.':'Account activated.');refresh();}
    catch(e){notice('$e',error:true);}
  }
  @override Widget build(BuildContext context)=>ListView(children:[
    Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:12,runSpacing:12,children:[
      const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Team & access',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
        SizedBox(height:4),Text('Manage who can use the rental workspace.',style:TextStyle(color:DriveColors.muted)),
      ]),FilledButton.icon(onPressed:add,icon:const Icon(Icons.person_add_alt_1),label:const Text('Add team member')),
    ]),const SizedBox(height:15),
    const Text('7 access levels · Customer accounts only see linked bookings; drivers only see assigned trips.',style:TextStyle(color:DriveColors.muted,fontSize:12)),
    const SizedBox(height:24),
    FutureBuilder<List<dynamic>>(future:users,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError)return Center(child:Text('${snapshot.error}',style:const TextStyle(color:Colors.redAccent)));
      final list=snapshot.data??[];
      return Column(children:[for(final item in list)Builder(builder:(ctx){
        final member=Map<String,dynamic>.from(item as Map);
        final active=member['is_active']==1||member['is_active']==true;
        final self = widget.api.currentUser != null && member['id'] == widget.api.currentUser!['id'];
        final displayName=member['name'].toString();
        final roleCode = member['role'].toString();
        final roleLabel = teamRoles[roleCode] ?? roleCode;
        return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(15),child:
          Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:12,runSpacing:12,children:[
            Row(mainAxisSize:MainAxisSize.min,children:[
              CircleAvatar(backgroundColor:DriveColors.tealDark,child:Text(displayName.isEmpty?'?':displayName.substring(0,1).toUpperCase())),
              const SizedBox(width:14),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${member['name']}${self?' (you)':''}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
                Text('${member['email']}',style:const TextStyle(color:DriveColors.muted,fontSize:12)),
                Text('$roleLabel  ·  ${active ? 'Active' : 'Suspended'}',style:TextStyle(fontSize:11,color:active?DriveColors.accent:DriveColors.warning)),
              ]),
            ]),
            Wrap(spacing:6,children:[
              OutlinedButton(onPressed:()=>edit(member),child:const Text('Edit')),
              OutlinedButton(onPressed:()=>resetPassword(member),child:const Text('Reset password')),
              if(!self)OutlinedButton(onPressed:()=>toggle(member),child:Text(active?'Suspend':'Activate')),
            ]),
          ])));
      })]);
    }),
  ]);
}

class MyAccountPage extends StatefulWidget{
  final DriveApi api;
  const MyAccountPage({super.key,required this.api});
  @override State<MyAccountPage> createState()=>_MyAccountPageState();
}
class _MyAccountPageState extends State<MyAccountPage>{
  final current=TextEditingController(),newPass=TextEditingController();
  bool busy=false;
  @override void dispose(){current.dispose();newPass.dispose();super.dispose();}
  Future<void> change()async{
    setState(()=>busy=true);
    try{final r=await widget.api.post('/api/auth/change-password',{
      'current_password':current.text,'new_password':newPass.text});
      current.clear();newPass.clear();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${r['message']}')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){final user=widget.api.currentUser??{};
    return ListView(children:[const Text('My account',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${user['name']??'User'}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        Text('${user['email']??''}',style:const TextStyle(color:DriveColors.muted)),
        Text('Role: ${user['role']??''}',style:const TextStyle(color:DriveColors.accent)),
      ]))),const SizedBox(height:18),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Change password',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:14),
        TextField(controller:current,obscureText:true,decoration:const InputDecoration(labelText:'Current password')),
        const SizedBox(height:12),TextField(controller:newPass,obscureText:true,decoration:const InputDecoration(labelText:'New password (8+ characters)')),
        const SizedBox(height:15),FilledButton(onPressed:busy?null:change,child:const Text('Update password')),
      ]))),
    ]);
  }
}
