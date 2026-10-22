import 'package:flutter/material.dart';
import 'api.dart';
import 'screens.dart';
import 'rental_flow.dart';
import 'carzone_ui.dart' as fleet;
import 'drive_theme.dart';
import 'team_page.dart';
import 'role_portal.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const DriveDeskApp()); }

class DriveDeskApp extends StatefulWidget {
  const DriveDeskApp({super.key});
  @override State<DriveDeskApp> createState() => _DriveDeskAppState();
}
class _DriveDeskAppState extends State<DriveDeskApp> {
  final api = DriveApi();
  bool? authenticated;
  @override void initState() {
    super.initState();
    api.restore().then((value) { if(mounted) setState(() => authenticated = value); });
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title:'DriveDesk • Fleet Management', debugShowCheckedModeBanner:false,
    theme:driveTheme(),
    home:authenticated == null
      ? const Scaffold(body:Center(child:CircularProgressIndicator()))
      : authenticated!
          ? ((api.currentUser?['role']=='customer'||api.currentUser?['role']=='driver')
             ? RolePortal(api:api,onLogout:()async {await api.logout();if(mounted)setState(()=>authenticated=false);})
             : HomeShell(api:api,onLogout:()async {
              await api.logout();
              if(mounted)setState(()=>authenticated=false);
            }))
          : LoginScreen(api:api,onLogin:()=>setState(()=>authenticated=true)),
  );
}

class LoginScreen extends StatefulWidget {
  final DriveApi api; final VoidCallback onLogin;
  const LoginScreen({super.key,required this.api,required this.onLogin});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email=TextEditingController(text:'admin@drivedesk.local');
  final password=TextEditingController(text:'Demo@12345');
  bool loading=false; String? error; String selectedDemo='admin';
  Future<void> go() async {
    if(loading)return;
    setState((){loading=true;error=null;});
    try {await widget.api.login(email.text.trim(),password.text);if(mounted)widget.onLogin();}
    catch(e){if(mounted)setState(()=>error='$e');}
    finally {if(mounted)setState(()=>loading=false);}
  }
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>850;
    return Scaffold(body:Row(children:[
      if(wide)Expanded(child:Container(
        decoration:const BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[Color(0xFF063B3A),DriveColors.sidebar,DriveColors.bg])),
        padding:const EdgeInsets.all(55),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _DriveBrand(large:true),const Spacer(),
          const Text('A smarter way\nto run your fleet.',
            style:TextStyle(fontSize:52,height:1.05,fontWeight:FontWeight.w900,letterSpacing:-1.7)),
          const SizedBox(height:22),
          const Text('Bookings, vehicle inspections, payments and smart insights.\nAll in one workspace.',
            style:TextStyle(color:DriveColors.muted,fontSize:16,height:1.7)),
          const Spacer(),
          Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:11),
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),color:DriveColors.raised),
            child:const Text('●  LOCAL DEMO  •  INTERVIEW EDITION',style:TextStyle(color:DriveColors.accent,fontWeight:FontWeight.w700,letterSpacing:1.1,fontSize:11))),
        ]),
      )),
      Expanded(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(26),child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:420),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(!wide)...[const _DriveBrand(large:true),const SizedBox(height:36)],
          const Text('Welcome back',style:TextStyle(fontSize:33,fontWeight:FontWeight.w900,letterSpacing:-.6)),
          const SizedBox(height:9),
          const Text('Sign in to your DriveDesk workspace.',style:TextStyle(color:DriveColors.muted)),
          const SizedBox(height:23),
          DropdownButtonFormField<String>(decoration:const InputDecoration(labelText:'Try a demo role',prefixIcon:Icon(Icons.badge_outlined)),
            value:selectedDemo,isExpanded:true,items:const [
              DropdownMenuItem(value:'admin',child:Text('Administrator')),
              DropdownMenuItem(value:'manager',child:Text('Operations Manager')),
              DropdownMenuItem(value:'booking',child:Text('Rental Agent')),
              DropdownMenuItem(value:'fleet',child:Text('Fleet Officer')),
              DropdownMenuItem(value:'finance',child:Text('Finance Officer')),
              DropdownMenuItem(value:'driver',child:Text('Driver')),
              DropdownMenuItem(value:'customer',child:Text('Customer')),
            ],onChanged:(v){const creds={
              'admin':['admin@drivedesk.local','Demo@12345'],
              'manager':['manager@drivedesk.local','Manager@12345'],
              'booking':['booking@drivedesk.local','Booking@12345'],
              'fleet':['fleet@drivedesk.local','Fleet@12345'],
              'finance':['finance@drivedesk.local','Finance@12345'],
              'driver':['driver@drivedesk.local','Driver@12345'],
              'customer':['customer@drivedesk.local','Customer@12345'],
            };if(v!=null){setState(()=>selectedDemo=v);email.text=creds[v]![0];password.text=creds[v]![1];}},
          ),
          const SizedBox(height:17),
          TextField(controller:email,decoration:const InputDecoration(labelText:'Work email',prefixIcon:Icon(Icons.alternate_email_rounded))),
          const SizedBox(height:16),
          TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password',prefixIcon:Icon(Icons.lock_outline_rounded)),onSubmitted:(_)=>go()),
          if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Color(0xFFFF8F97)))],
          const SizedBox(height:22),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:loading?null:go,
            icon:Icon(loading?Icons.hourglass_empty:Icons.arrow_forward_rounded),
            label:Text(loading?'Signing in…':'Sign in to workspace'))),
          const SizedBox(height:25),
          Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(
            color:DriveColors.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:DriveColors.line)),
            child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('DEMO ACCESS',style:TextStyle(color:DriveColors.accent,letterSpacing:1.4,fontWeight:FontWeight.w800,fontSize:10)),
              SizedBox(height:9),Text('admin@drivedesk.local  /  Demo@12345',style:TextStyle(fontSize:12,color:DriveColors.muted)),
            ])),
        ]),
      )))),
    ]));
  }
}

class _DriveBrand extends StatelessWidget {
  final bool large; const _DriveBrand({this.large=false});
  @override Widget build(BuildContext context) => Row(mainAxisSize:MainAxisSize.min,children:[
    Container(height:large?42:36,width:large?42:36,decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[DriveColors.accent,DriveColors.tealDark]),
      borderRadius:BorderRadius.circular(12)),
      child:const Icon(Icons.directions_car_filled_rounded,color:Colors.white,size:22)),
    const SizedBox(width:11),
    Text('DriveDesk',style:TextStyle(fontWeight:FontWeight.w900,fontSize:large?24:20,letterSpacing:-.8)),
    const SizedBox(width:8),
    Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(
      color:DriveColors.tealDark,borderRadius:BorderRadius.circular(5)),
      child:const Text('PRO',style:TextStyle(fontSize:10,color:DriveColors.text,fontWeight:FontWeight.w800,letterSpacing:.5))),
  ]);
}

class HomeShell extends StatefulWidget {
  final DriveApi api; final Future<void> Function() onLogout;
  const HomeShell({super.key,required this.api,required this.onLogout});
  @override State<HomeShell> createState()=>_HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int section=0; int? rentalId;
  static const labels=['Dashboard','New rental','Rental desk','Explore fleet','Vehicles','Customers','Bookings','More tools','Payments','Alerts','Team & access','My account'];
  static const icons=[Icons.grid_view_rounded,Icons.add_circle_outline_rounded,
    Icons.assignment_turned_in_outlined,Icons.travel_explore_rounded,Icons.directions_car_outlined,
    Icons.people_alt_outlined,Icons.event_available_outlined,Icons.auto_awesome_outlined,
    Icons.payments_outlined,Icons.notifications_active_outlined,Icons.admin_panel_settings_outlined,Icons.manage_accounts_outlined];
  bool canSee(int i){
    final role=widget.api.currentUser?['role']??'rental_agent';
    if(role=='admin'||role=='manager')return role=='admin'||i!=10;
    if(role=='rental_agent')return [0,1,2,3,5,6,8,9,11].contains(i);
    if(role=='fleet_officer')return [0,3,4,6,9,11].contains(i);
    if(role=='finance_officer')return [0,6,8,9,11].contains(i);
    return i==11;
  }
  void navigate(int value) {if(canSee(value))setState(()=>section=value);}

  Widget sidebar(bool isWide) => Container(
    color:DriveColors.sidebar,width:isWide?246:282,
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Padding(padding:EdgeInsets.fromLTRB(22,28,15,30),child:_DriveBrand()),
      const Padding(padding:EdgeInsets.fromLTRB(21,0,0,10),child:Text('WORKSPACE',style:TextStyle(
        fontSize:10,letterSpacing:2.0,fontWeight:FontWeight.w800,color:DriveColors.muted))),
      Expanded(child:ListView(padding:const EdgeInsets.symmetric(horizontal:12),children:[
        for(int i=0;i<labels.length;i++)
          if(canSee(i)) ...[
          if((i==3||i==7))Padding(padding:const EdgeInsets.fromLTRB(12,20,12,13),child:Row(children:[
            Text(i==3?'FLEET & CUSTOMERS':'FINANCE & SUPPORT',style:const TextStyle(fontSize:10,
              color:DriveColors.muted,fontWeight:FontWeight.w800,letterSpacing:1.3)),
            const SizedBox(width:8),const Expanded(child:Divider())])),
          Padding(padding:const EdgeInsets.only(bottom:4),child:Material(color:section==i?DriveColors.tealDark.withValues(alpha:.30):Colors.transparent,
            borderRadius:BorderRadius.circular(12),child:InkWell(
            borderRadius:BorderRadius.circular(12),onTap:(){navigate(i);if(!isWide)Navigator.pop(context);},
            child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),child:Row(children:[
              Icon(icons[i],size:20,color:section==i?DriveColors.accent:DriveColors.muted),
              const SizedBox(width:13),Expanded(child:Text(labels[i],style:TextStyle(fontSize:13,
                fontWeight:section==i?FontWeight.w800:FontWeight.w600,
                color:section==i?DriveColors.text:DriveColors.muted))),
              if(section==i)const Icon(Icons.circle,color:DriveColors.accent,size:7),
            ]))))),
        ],
      ])),
      const Divider(height:1),
      Padding(padding:const EdgeInsets.all(17),child:Row(children:[
        const CircleAvatar(backgroundColor:DriveColors.tealDark,foregroundColor:DriveColors.text,
          child:Icon(Icons.person_rounded)),const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${widget.api.currentUser?['name']??'Team member'}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
          Text('${widget.api.currentUser?['role']??'staff'} • rental operations',style:const TextStyle(fontSize:11,color:DriveColors.muted))])),
        IconButton(tooltip:'Sign out',onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded,size:18)),
      ])),
    ]),
  );
  @override Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>=1000;
    final pages=<Widget>[
      DashboardPage(api:widget.api,onNewRental:()=>navigate(1),onExplore:()=>navigate(3),onRentalDesk:()=>navigate(2),onTrends:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DemandTool(api:widget.api))),onMaintenance:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenanceTool(api:widget.api)))),
      NewRentalWizardPage(api:widget.api,onCreated:(id){setState((){rentalId=id;section=2;});}),
      RentalDeskPage(api:widget.api,bookingId:rentalId,onCreate:()=>navigate(1),onDamage:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DamageTool(api:widget.api))),onGps:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GeoTool(api:widget.api)))),
      fleet.CarZoneShowroom(api:widget.api,onRentalDesk:(id){setState((){rentalId=id;section=2;});}),
      VehiclesPage(api:widget.api),CustomersPage(api:widget.api),BookingsPage(api:widget.api),
      SmartPage(api:widget.api,onNewRental:()=>navigate(1)),PaymentsPage(api:widget.api),AlertsPage(api:widget.api),TeamPage(api:widget.api),MyAccountPage(api:widget.api),
    ];
    return Scaffold(
      drawer:wide?null:Drawer(backgroundColor:DriveColors.sidebar,child:SafeArea(child:sidebar(false))),
      body:SafeArea(child:Row(children:[
        if(wide)sidebar(true),
        Expanded(child:Column(children:[
          Container(height:69,padding:const EdgeInsets.symmetric(horizontal:25),
            decoration:const BoxDecoration(color:DriveColors.bg,
              border:Border(bottom:BorderSide(color:DriveColors.line,width:.7))),
            child:Row(children:[
              if(!wide)Builder(builder:(ctx)=>IconButton(
                icon:const Icon(Icons.menu_rounded),onPressed:()=>Scaffold.of(ctx).openDrawer())),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(labels[section],style:const TextStyle(fontWeight:FontWeight.w900,fontSize:19)),
                const Text('DriveDesk / Management workspace',style:TextStyle(color:DriveColors.muted,fontSize:10)),
              ])),
              if(wide)Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(
                borderRadius:BorderRadius.circular(10),color:DriveColors.surface),child:const Row(children:[
                  Icon(Icons.circle,color:DriveColors.accent,size:8),SizedBox(width:8),
                  Text('LOCAL DEMO',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))])),
              const SizedBox(width:10),
              IconButton(tooltip:'Alerts',onPressed:()=>navigate(9),icon:const Icon(Icons.notifications_none_rounded)),
              IconButton(tooltip:'My account',onPressed:()=>navigate(11),icon:const Icon(Icons.account_circle_outlined)),
            ])),
          Expanded(child:Padding(padding:EdgeInsets.all(section==3?0:(wide?26:14)),
            child:KeyedSubtree(key:ValueKey(section),child:pages[section]))),
        ])),
      ])),
    );
  }
}
