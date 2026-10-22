import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'drive_theme.dart';

// CarZone-inspired DriveDesk showroom. Actual inventory, customers, and bookings
// come from DriveDesk authenticated Node.js API. Illustrative map and optional
// driver cards remain explicitly demo-only. No payment gateway is implied.

class C {
  static const bg = Color(0xFF101213);
  static const panel = Color(0xFF1C2022);
  static const panel2 = Color(0xFF252A2C);
  static const teal = Color(0xFF00A19D);
  static const tealDeep = Color(0xFF006B6A);
  static const muted = Color(0xFF929A9C);
  static const border = Color(0xFF33393A);
  static const white = Color(0xFFF8FAF9);
}

class RentalCar {
  final String id, brand, name, type, photo, fuel, gearbox, description;
  final int seats, price, mpg;
  final double rating;
  final List<String> features;
  const RentalCar({
    required this.id,
    required this.brand,
    required this.name,
    required this.type,
    required this.photo,
    required this.fuel,
    required this.gearbox,
    required this.description,
    required this.seats,
    required this.price,
    required this.mpg,
    required this.rating,
    required this.features,
  });
}

// Illustrative stock photos shipped in the user's CarZone reference; the cars
// in those pictures are NOT representations of individual registered vehicles.
String _imageForFleet(String make, String category) {
  final key = '$make $category'.toLowerCase();
  if(key.contains('suv') || key.contains('x-trail') || key.contains('vezel'))return 'assets/cars/range_rover.jpg';
  if(key.contains('hybrid') || key.contains('aqua'))return 'assets/cars/tesla.jpg';
  if(key.contains('luxury') || key.contains('benz'))return 'assets/cars/mercedes.jpg';
  if(key.contains('sedan') || key.contains('axio'))return 'assets/cars/camry.jpg';
  return 'assets/cars/bmw.jpg';
}

RentalCar _vehicleFromApi(dynamic raw){
  final v=Map<String,dynamic>.from(raw as Map);
  int integer(String k,[int fallback=0])=>(num.tryParse('${v[k]??''}')??fallback).round();
  return RentalCar(id:'${v['id']}',brand:'${v['make']??'Unknown'}',
    name:'${v['make']??''} ${v['model']??''}'.trim(),type:'${v['category']??'Other'}',
    photo:_imageForFleet('${v['make']??''}', '${v['category']??''}'),fuel:'Not specified',gearbox:'Not specified',
    description:'Registration: ${v['plate']??'—'}. Model year: ${v['year']??'—'}. Vehicle details are read from the DriveDesk fleet database.',
    seats:integer('seats',5),price:integer('daily_rate'),mpg:0,rating:0,
    features:['Registered fleet vehicle','Plate: ${v['plate']??'—'}']);
}
String _iso(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';


class RentalBooking {
  final RentalCar car;
  final DateTimeRange dates;
  final String driver;
  final int total;
  final int bookingId;
  final String status, customer;
  const RentalBooking(this.car, this.dates, this.driver, this.total,
    {this.bookingId=0,this.status='pending',this.customer=''});
}

class CarZoneShowroom extends StatelessWidget {
  final DriveApi api;
  final ValueChanged<int> onRentalDesk;
  const CarZoneShowroom({super.key,required this.api,required this.onRentalDesk});
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(primary:C.teal, secondary:C.teal, surface:C.panel),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor:C.bg, elevation:0, centerTitle:true, foregroundColor:C.white),
      textTheme: const TextTheme(
        headlineLarge:TextStyle(fontSize:35, fontWeight:FontWeight.w800, letterSpacing:-1.4, height:1.10, color:C.white),
        headlineMedium:TextStyle(fontSize:26, fontWeight:FontWeight.w800, letterSpacing:-.7, color:C.white),
        titleLarge:TextStyle(fontSize:21, fontWeight:FontWeight.w800, color:C.white),
        titleMedium:TextStyle(fontSize:16, fontWeight:FontWeight.w700, color:C.white),
        bodyMedium:TextStyle(fontSize:13.5, height:1.5, color:C.muted),
      ),
      dividerColor: C.border,
    ),
    child: AppShell(api:api,onRentalDesk:onRentalDesk),
  );
}

String dateLabel(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
int daysIn(DateTimeRange range) => math.max(1, range.end.difference(range.start).inDays);
void note(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content:Text(message), backgroundColor:C.panel2, behavior:SnackBarBehavior.floating, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
);

class AppShell extends StatefulWidget {
  final DriveApi api;
  final ValueChanged<int> onRentalDesk;
  const AppShell({super.key,required this.api,required this.onRentalDesk});
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int tab = 0;
  final Set<String> favorites = {};
  List<RentalCar> fleet = [];
  List<RentalBooking> bookings = [];
  bool loading=true;
  String? error;
  @override void initState(){super.initState();_reload();}
  Future<void> _reload() async {
    try{
      final data=await Future.wait([widget.api.list('/api/vehicles'),widget.api.list('/api/bookings')]);
      if(!mounted)return;
      final all=data[0].map(_vehicleFromApi).toList();
      final indexed={for(final c in all)c.id:c};
      final rows=<RentalBooking>[];
      for(final entry in data[1]){
        final b=Map<String,dynamic>.from(entry as Map);
        final c=indexed['${b['vehicle_id']}'];
        if(c==null)continue;
        final start=DateTime.tryParse('${b['pickup_date']}');
        final end=DateTime.tryParse('${b['return_date']}');
        if(start==null||end==null)continue;
        rows.add(RentalBooking(c,DateTimeRange(start:start,end:end), 'Self-drive',
          (num.tryParse('${b['total_amount']}')??0).round(),bookingId:(b['id'] as num).toInt(),
          status:'${b['status']}',customer:'${b['customer_name']??''}'));
      }
      setState(() {fleet=[for(final v in data[0])if(v['status']=='available')_vehicleFromApi(v)];
        bookings=rows;loading=false;error=null;});
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  String pickup = 'Colombo, Sri Lanka';
  String dropoff = 'Same as pick-up';
  DateTimeRange range = DateTimeRange(start:DateTime.now(), end:DateTime.now().add(const Duration(days:3)));

  void toggleFavorite(RentalCar car) => setState(() {
    if (!favorites.add(car.id)) favorites.remove(car.id);
  });
  void openCar(RentalCar car) => Navigator.push(context, MaterialPageRoute<void>(
    builder:(_) => CarDetailPage(car:car, initialDates:range,api:widget.api,
      onRentalDesk:widget.onRentalDesk,
      isFavorite:()=>favorites.contains(car.id),toggleFavorite:()=>toggleFavorite(car),
      onBook:(_){_reload();}),
  ));
  Future<void> chooseRange() async {
    final chosen = await pickDriveDates(context,range);
    if(chosen!=null && mounted)setState(()=>range=chosen);
  }
  Future<void> selectLocation({required bool isPickup}) async {
    const locations=['Colombo, Sri Lanka','Bandaranaike Airport','Mount Lavinia','Negombo','Kandy','Galle'];
    final selection=await showModalBottomSheet<String>(context:context, backgroundColor:C.panel, isScrollControlled:true,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))), builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start, children:[
        const Text('Choose a location',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:14),
        ...locations.map((location)=>ListTile(contentPadding:EdgeInsets.zero, leading:const Icon(Icons.location_on_outlined,color:C.teal),title:Text(location),onTap:()=>Navigator.pop(ctx,location))),
        if(!isPickup) ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.repeat,color:C.teal),title:const Text('Same as pick-up'),onTap:()=>Navigator.pop(ctx,'Same as pick-up')),
      ]))));
    if(selection!=null) setState(() { if(isPickup) {pickup=selection;} else {dropoff=selection;} });
  }
  @override
  Widget build(BuildContext context) {
    if(loading)return const ColoredBox(color:C.bg,child:Center(child:CircularProgressIndicator(color:C.teal)));
    if(error!=null)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.wifi_off,color:C.teal,size:48),const SizedBox(height:16),
      Text('Fleet connection failed: $error',textAlign:TextAlign.center),
      const SizedBox(height:15),MainButton(text:'Retry connection',onTap:_reload)]));
    if(fleet.isEmpty)return Center(child:EmptyState(icon:Icons.directions_car,title:'No vehicles available',
      message:'Register an available vehicle in Fleet Management to use fleet exploration.',
      button:'Refresh fleet',onTap:_reload));
    final pages=<Widget>[
      HomePage(fleet:fleet,onExplore:()=>setState(()=>tab=1), onOpen:openCar, favoriteIds:favorites, onFav:toggleFavorite, range:range, onDates:chooseRange, pickup:pickup, dropoff:dropoff, onLocation:selectLocation),
      ExplorePage(fleet:fleet,onOpen:openCar, favoriteIds:favorites, onFav:toggleFavorite),
      BookingsPage(bookings:bookings, onExplore:()=>setState(()=>tab=1)),
      SavedPage(fleet:fleet,favoriteIds:favorites, onOpen:openCar, onFav:toggleFavorite),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor:C.bg,
      body:Column(children:[
        Container(
          width:double.infinity,
          padding:const EdgeInsets.fromLTRB(23,21,23,10),
          child:Row(children:[
            const Icon(Icons.travel_explore_rounded,color:C.teal,size:24),
            const SizedBox(width:12),
            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Explore fleet',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
              Text('Browse registered DriveDesk vehicles',style:TextStyle(color:C.muted,fontSize:11)),
            ])),
            IconButton(tooltip:'Refresh fleet',onPressed:_reload,
                icon:const Icon(Icons.refresh_rounded,color:C.teal)),
          ]),
        ),
        SizedBox(height:57,child:ListView(
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:5),
          scrollDirection:Axis.horizontal,
          children:[
            _topTab(Icons.home_outlined,'Discover',0),
            _topTab(Icons.search_rounded,'All vehicles',1),
            _topTab(Icons.calendar_month_outlined,'Rental history',2),
            _topTab(Icons.favorite_border_rounded,'Saved',3),
            _topTab(Icons.person_outline_rounded,'Staff profile',4),
          ],
        )),
        const Divider(height:1),
        Expanded(child:IndexedStack(index:tab,children:pages)),
      ]),
    );
  }
  Widget _topTab(IconData icon,String label,int index){
    final active=tab==index;
    return Padding(padding:const EdgeInsets.only(right:7),child:InkWell(
      onTap:()=>setState(()=>tab=index),borderRadius:BorderRadius.circular(11),
      child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),
          color:active?C.tealDeep.withValues(alpha:.6):C.panel,
          border:Border.all(color:active?C.teal:C.border)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Icon(icon,color:active?C.white:C.muted,size:17),
          const SizedBox(width:8),
          Text(label,style:TextStyle(color:active?C.white:C.muted,
            fontSize:12,fontWeight:active?FontWeight.w800:FontWeight.w500)),
        ])),
    ));
  }
}

// ---- Shared visual components ------------------------------------------------
class MainButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool outline;
  const MainButton({super.key,required this.text,required this.onTap,this.trailing,this.outline=false});
  @override Widget build(BuildContext context)=>SizedBox(height:53,width:double.infinity,child:ElevatedButton(
    onPressed:onTap,
    style:ElevatedButton.styleFrom(backgroundColor:outline?C.panel:C.teal,foregroundColor:C.white,
      elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),side:BorderSide(color:outline?C.border:C.teal))),
    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text(text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),if(trailing!=null)...[const SizedBox(width:10),Icon(trailing,size:19)]]),
  ));
}
class SquareIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final Color? background;
  const SquareIcon({super.key,required this.icon,this.onTap,this.background});
  @override Widget build(BuildContext context)=>Material(color:background??C.panel2,borderRadius:BorderRadius.circular(13),child:InkWell(borderRadius:BorderRadius.circular(13),onTap:onTap,child:SizedBox(width:42,height:42,child:Icon(icon,color:C.white,size:20))));
}
class SectionHeader extends StatelessWidget {
  final String title; final String action; final VoidCallback? onTap;
  const SectionHeader({super.key,required this.title,this.action='',this.onTap});
  @override Widget build(BuildContext context)=>Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,letterSpacing:-.5)),
    if(action.isNotEmpty) GestureDetector(onTap:onTap,child:Text(action,style:const TextStyle(fontSize:12,color:C.teal,fontWeight:FontWeight.w700))),
  ]);
}
class Pill extends StatelessWidget {
  final String text; final bool selected; final VoidCallback onTap;
  const Pill({super.key,required this.text,required this.selected,required this.onTap});
  @override Widget build(BuildContext context)=>InkWell(borderRadius:BorderRadius.circular(100),onTap:onTap,child:AnimatedContainer(duration:const Duration(milliseconds:160),padding:const EdgeInsets.symmetric(horizontal:19,vertical:11),decoration:BoxDecoration(color:selected?C.teal:C.panel,border:Border.all(color:selected?C.teal:C.border),borderRadius:BorderRadius.circular(30)),child:Text(text,style:TextStyle(fontSize:12,color:selected?Colors.white:C.muted,fontWeight:selected?FontWeight.w800:FontWeight.w600))));
}
class CarPhoto extends StatelessWidget {
  final RentalCar car; final double? height; final BorderRadius radius;
  const CarPhoto({super.key,required this.car,this.height, this.radius=const BorderRadius.all(Radius.circular(18))});
  @override Widget build(BuildContext context)=>ClipRRect(borderRadius:radius,child:car.photo.isEmpty?
    Container(height:height,width:double.infinity,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF193A3C),Color(0xFF202628)])),
      child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.directions_car_filled,color:C.teal,size:52),SizedBox(height:5),Text('NO VERIFIED PHOTO',style:TextStyle(fontSize:9,color:C.muted,letterSpacing:1.2))])):
    Stack(fit:StackFit.passthrough,children:[Image.asset(car.photo,width:double.infinity,height:height,fit:BoxFit.cover,
      errorBuilder:(_,__,___)=>Container(color:C.panel2,height:height,child:const Center(child:Icon(Icons.directions_car_rounded,color:C.teal,size:65)))), Positioned(bottom:7,right:7,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:C.bg.withValues(alpha:.78),borderRadius:BorderRadius.circular(6)),child:const Text('ILLUSTRATIVE PHOTO',style:TextStyle(color:C.white,fontSize:8,fontWeight:FontWeight.w700))))]));
}
class CarTile extends StatelessWidget {
  final RentalCar car; final VoidCallback onOpen,onFav; final bool favorite; final bool horizontal;
  const CarTile({super.key,required this.car,required this.onOpen,required this.onFav,required this.favorite,this.horizontal=false});
  @override Widget build(BuildContext context) => GestureDetector(onTap:onOpen,child:Container(
    width:horizontal?240:null,
    decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(19),border:Border.all(color:C.border.withOpacity(.6))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Stack(children:[
        CarPhoto(car:car,height:horizontal?143:125,radius:const BorderRadius.vertical(top:Radius.circular(18))),
        Positioned(top:10,right:10,child:Material(color:C.bg.withOpacity(.65),shape:const CircleBorder(),child:InkWell(customBorder:const CircleBorder(),onTap:onFav,child:Padding(padding:const EdgeInsets.all(9),child:Icon(favorite?Icons.favorite_rounded:Icons.favorite_border_rounded,size:18,color:favorite?C.teal:C.white))))),
        Positioned(left:11,bottom:10,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:C.bg.withOpacity(.72),borderRadius:BorderRadius.circular(12)),child:Text(car.type.toUpperCase(),style:const TextStyle(letterSpacing:.8,fontSize:9,fontWeight:FontWeight.w800)))),
      ]),
      Padding(padding:const EdgeInsets.fromLTRB(12,12,12,13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(car.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),const SizedBox(height:7),
        Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFFFCB6A),size:16),Text(car.rating>0?' ${car.rating.toStringAsFixed(1)}':' Fleet',style:const TextStyle(color:C.muted,fontSize:11)),const Spacer(),const Icon(Icons.event_seat_outlined,color:C.muted,size:14),Text(' ${car.seats}',style:const TextStyle(color:C.muted,fontSize:11))]),
        const SizedBox(height:10),Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('LKR ${car.price}',style:const TextStyle(fontSize:19,color:C.teal,fontWeight:FontWeight.w900)),const Text(' /day',style:TextStyle(color:C.muted,fontSize:11)),const Spacer(),const Icon(Icons.arrow_outward_rounded,color:C.teal,size:19)]),
      ])),
    ]),
  ));
}

class HomePage extends StatelessWidget {
  final List<RentalCar> fleet;
  final VoidCallback onExplore,onDates;
  final void Function(RentalCar) onOpen,onFav;
  final Set<String> favoriteIds;
  final DateTimeRange range;
  final String pickup,dropoff;
  final Future<void> Function({required bool isPickup}) onLocation;
  const HomePage({super.key,required this.fleet,required this.onExplore,required this.onOpen,required this.favoriteIds,required this.onFav,required this.onDates,required this.range,required this.pickup,required this.dropoff,required this.onLocation});
  @override
  Widget build(BuildContext context)=>CustomScrollView(slivers:[SliverToBoxAdapter(child:Padding(
    padding:const EdgeInsets.fromLTRB(22,20,22,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:48,height:48,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0B6F6C),C.teal]),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.person_rounded,color:Colors.white,size:27)),const SizedBox(width:11),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('GOOD MORNING 👋',style:TextStyle(color:C.muted,fontWeight:FontWeight.w800,fontSize:10,letterSpacing:1.2)),SizedBox(height:3),Text('Hey, welcome back!',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800))])),SquareIcon(icon:Icons.notifications_none_rounded,onTap:()=>note(context,'You’re all caught up!'))]),
      const SizedBox(height:25),const Text('Your next ride,\nmade effortless.',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900,letterSpacing:-1.2,height:1.13)),const SizedBox(height:8),const Text('Discover your perfect car. Your journey starts here.',style:TextStyle(color:C.muted,fontSize:13)),
      const SizedBox(height:23),
      _hero(context),
      const SizedBox(height:24),const SectionHeader(title:'Find your car'),const SizedBox(height:13),
      Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:C.border.withOpacity(.7))),child:Column(children:[
        _locationRow('PICK-UP LOCATION',pickup,Icons.trip_origin_rounded,()=>onLocation(isPickup:true)),const Divider(color:C.border,height:23),
        _locationRow('DROP-OFF LOCATION',dropoff,Icons.location_on_outlined,()=>onLocation(isPickup:false)),const Divider(color:C.border,height:23),
        InkWell(onTap:onDates,child:Row(children:[const Icon(Icons.calendar_month_outlined,color:C.teal,size:22),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('TRAVEL DATES',style:TextStyle(color:C.muted,fontSize:9,letterSpacing:1.1,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text('${dateLabel(range.start)}  →  ${dateLabel(range.end)}',style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w700))])),const Icon(Icons.keyboard_arrow_down_rounded,color:C.muted)])),
        const SizedBox(height:19),MainButton(text:'Search available cars',trailing:Icons.arrow_forward_rounded,onTap:onExplore),
      ])),
      const SizedBox(height:27),SectionHeader(title:'Featured fleet',action:'See all',onTap:onExplore),const SizedBox(height:15),
      SizedBox(height:260,child:ListView.separated(scrollDirection:Axis.horizontal,clipBehavior:Clip.none,itemCount:math.min(4,fleet.length),separatorBuilder:(_,__)=>const SizedBox(width:13),itemBuilder:(ctx,i){final car=fleet[i];return CarTile(car:car,horizontal:true,favorite:favoriteIds.contains(car.id),onFav:()=>onFav(car),onOpen:()=>onOpen(car));})),
      const SizedBox(height:27),const SectionHeader(title:'Map concept preview'),const SizedBox(height:14),
      GestureDetector(onTap:onExplore,child:const DemoMap(height:200)),
      const SizedBox(height:10),const Text('Map is an illustrative UI preview • Explore cars to book',style:TextStyle(color:C.muted,fontSize:10)),
      const SizedBox(height:22),
    ]),
  ))]);
  Widget _hero(BuildContext context)=>GestureDetector(onTap:()=>onOpen(fleet.first),child:Container(height:235,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),color:C.panel),child:Stack(fit:StackFit.expand,children:[
    CarPhoto(car:fleet.first),
    const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xEA101213),Color(0xAA101213),Color(0x00101213)]))),
    Positioned(left:19,top:19,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:C.teal,borderRadius:BorderRadius.circular(20)),child:const Text('FEATURED RIDE',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.2)))),
    Positioned(left:19,bottom:23,right:20,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('WEEKEND\nESCAPE',style:TextStyle(fontSize:33,fontWeight:FontWeight.w900,letterSpacing:-1.4,height:1.01)),const SizedBox(height:10),Row(children:[Text('Explore ${fleet.first.name}',style:const TextStyle(fontSize:12,color:Colors.white70)),const Spacer(),Container(padding:const EdgeInsets.all(10),decoration:const BoxDecoration(color:C.teal,shape:BoxShape.circle),child:const Icon(Icons.arrow_outward_rounded,size:18))])])),
  ])));
  Widget _locationRow(String label,String value,IconData icon,VoidCallback onTap)=>InkWell(onTap:onTap,child:Row(children:[Icon(icon,size:22,color:C.teal),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:C.muted,fontSize:9,letterSpacing:1.1,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700))])),const Icon(Icons.keyboard_arrow_down_rounded,color:C.muted)]));
}

// Original illustrative map art. No Mapbox key or geolocation required.
class DemoMap extends StatelessWidget {
  final double height;
  const DemoMap({super.key,required this.height});
  @override Widget build(BuildContext context)=>Container(height:height,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),color:const Color(0xFF1D3137)),child:Stack(children:[
    const Positioned.fill(child:CustomPaint(painter:RoadMapPainter())),
    const Positioned(left:17,top:17,child:Row(children:[Icon(Icons.location_on_rounded,color:C.teal,size:16),SizedBox(width:5),Text('COLOMBO',style:TextStyle(fontWeight:FontWeight.w900,color:Colors.white,letterSpacing:1.2,fontSize:10))])),
    const Positioned(left:42,top:65,child:MapPrice(text:'DEMO')),const Positioned(right:42,top:40,child:MapPrice(text:'DEMO')),const Positioned(right:90,bottom:40,child:MapPrice(text:'DEMO')),
    Positioned(left:15,bottom:15,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(12)),child:const Row(children:[Icon(Icons.directions_car,color:C.teal,size:16),SizedBox(width:7),Text('Fleet availability',style:TextStyle(color:C.white,fontSize:11,fontWeight:FontWeight.w700))]))),
  ]));
}
class MapPrice extends StatelessWidget {
  final String text;const MapPrice({super.key,required this.text});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.directions_car_filled_rounded,size:15,color:C.teal),const SizedBox(width:5),Text(text,style:const TextStyle(color:C.bg,fontWeight:FontWeight.w800,fontSize:12))]));
}
class RoadMapPainter extends CustomPainter {
  const RoadMapPainter();
  @override void paint(Canvas canvas, Size size){
    final minor=Paint()..color=const Color(0xFF4E666D).withOpacity(.44)..style=PaintingStyle.stroke..strokeWidth=1.1;
    final main=Paint()..color=const Color(0xFF7F989A).withOpacity(.52)..style=PaintingStyle.stroke..strokeWidth=2.9;
    final route=Paint()..color=C.teal..style=PaintingStyle.stroke..strokeWidth=3.7..strokeCap=StrokeCap.round;
    for(int i=-4;i<18;i++){
      final y=i*25.0;
      final path=Path()..moveTo(0,y+math.sin(i*1.3)*13)..quadraticBezierTo(size.width*.45,y-30,size.width,y+25);
      canvas.drawPath(path,i%4==0?main:minor);
    }
    for(int i=-5;i<19;i++){
      final x=i*32.0;
      final path=Path()..moveTo(x,0)..cubicTo(x+50,size.height*.27,x-38,size.height*.62,x+25,size.height);
      canvas.drawPath(path,i%5==0?main:minor);
    }
    final p=Path()..moveTo(size.width*.14,size.height*.68)..cubicTo(size.width*.33,size.height*.27,size.width*.63,size.height*.73,size.width*.88,size.height*.21);
    canvas.drawPath(p,route);
    canvas.drawCircle(Offset(size.width*.14,size.height*.68),5,Paint()..color=C.teal);
    canvas.drawCircle(Offset(size.width*.88,size.height*.21),5,Paint()..color=C.teal);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class ExplorePage extends StatefulWidget {
  final List<RentalCar> fleet;
  final void Function(RentalCar) onOpen,onFav;
  final Set<String> favoriteIds;
  const ExplorePage({super.key,required this.fleet,required this.onOpen,required this.onFav,required this.favoriteIds});
  @override State<ExplorePage> createState()=>_ExplorePageState();
}
class _ExplorePageState extends State<ExplorePage> {
  String category='All', query='';
  bool cheapFirst=false;
  bool showMap=false;
  // Categories come from the actual fleet, not the original UI mock data.
  @override Widget build(BuildContext context){
    final categories=['All',...{for(final c in widget.fleet)c.type}];
    final filtered=widget.fleet.where((c)=>(category=='All'||category==c.type) && ('${c.name} ${c.brand} ${c.fuel}'.toLowerCase().contains(query.toLowerCase()))).toList();
    if(cheapFirst)filtered.sort((a,b)=>a.price.compareTo(b.price));
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(22,19,22,0),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Discover cars',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.9)),const SizedBox(height:4),const Text('Find the right car for every journey',style:TextStyle(color:C.muted,fontSize:13)),const SizedBox(height:21),
        Container(height:52,decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(15)),child:TextField(onChanged:(v)=>setState(()=>query=v),style:const TextStyle(fontSize:13),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded,color:C.teal),hintText:'Search model, brand or category...',hintStyle:TextStyle(color:C.muted,fontSize:13),border:InputBorder.none,contentPadding:EdgeInsets.only(top:15)))),
        const SizedBox(height:18),SizedBox(height:43,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:categories.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(ctx,i)=>Pill(text:categories[i],selected:category==categories[i],onTap:()=>setState(()=>category=categories[i])))),
        const SizedBox(height:22),Row(children:[Text('${filtered.length} available cars',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),const Spacer(),InkWell(onTap:()=>setState(()=>cheapFirst=!cheapFirst),child:Row(children:[Icon(cheapFirst?Icons.arrow_upward_rounded:Icons.sort_rounded,color:C.teal,size:17),const SizedBox(width:5),Text(cheapFirst?'Price: low to high':'Popular',style:const TextStyle(fontSize:11,color:C.muted))])),const SizedBox(width:14),GestureDetector(onTap:()=>setState(()=>showMap=!showMap),child:Icon(showMap?Icons.grid_view_rounded:Icons.map_outlined,color:C.teal,size:23))]),
      ])),
      Expanded(child:showMap?Padding(padding:const EdgeInsets.all(22),child:Column(children:[const Expanded(child:DemoMap(height:1000)),const SizedBox(height:12),Text('Illustrative map only • ${filtered.length} cars match your filters',style:const TextStyle(color:C.muted,fontSize:12)),const SizedBox(height:12),MainButton(text:'Switch to car list',onTap:()=>setState(()=>showMap=false))])):
        filtered.isEmpty?const Center(child:Text('No cars found. Try another filter.',style:TextStyle(color:C.muted))):
        GridView.builder(padding:const EdgeInsets.fromLTRB(20,20,20,25),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.66,crossAxisSpacing:12,mainAxisSpacing:13),itemCount:filtered.length,itemBuilder:(ctx,i){final car=filtered[i];return CarTile(car:car,onFav:()=>widget.onFav(car),favorite:widget.favoriteIds.contains(car.id),onOpen:()=>widget.onOpen(car));}),
      ),
    ]);
  }
}

// ---- Car detail and booking flow --------------------------------------------
class CarDetailPage extends StatefulWidget {
  final RentalCar car;
  final DateTimeRange initialDates;
  final DriveApi api;
  final ValueChanged<int> onRentalDesk;
  final bool Function() isFavorite;
  final VoidCallback toggleFavorite;
  final ValueChanged<RentalBooking> onBook;
  const CarDetailPage({super.key,required this.car,required this.initialDates,required this.api,required this.onRentalDesk,required this.isFavorite,required this.toggleFavorite,required this.onBook});
  @override State<CarDetailPage> createState()=>_CarDetailPageState();
}
class _CarDetailPageState extends State<CarDetailPage>{
  @override Widget build(BuildContext context){final car=widget.car;return Scaffold(
    body:Stack(children:[
      CustomScrollView(slivers:[
        SliverToBoxAdapter(child:Stack(children:[
          CarPhoto(car:car,height:315,radius:BorderRadius.zero),
          Container(height:315,decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0x7A101213),Color(0x00101213),C.bg],stops:[0,.52,1]))),
          Positioned(top:MediaQuery.of(context).padding.top+12,left:19,child:SquareIcon(icon:Icons.arrow_back_rounded,background:C.bg.withOpacity(.74),onTap:()=>Navigator.pop(context))),
          Positioned(top:MediaQuery.of(context).padding.top+12,right:19,child:SquareIcon(icon:widget.isFavorite()?Icons.favorite_rounded:Icons.favorite_border_rounded,background:C.bg.withOpacity(.74),onTap:(){widget.toggleFavorite();setState((){});})),
          Positioned(left:22,bottom:17,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:C.teal,borderRadius:BorderRadius.circular(24)),child:Text(car.type.toUpperCase(),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)))),
        ])),
        SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(22,5,22,135),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(car.name,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-1)),const SizedBox(height:3),Text('${car.brand}  •  Fleet vehicle',style:const TextStyle(color:C.muted,fontSize:12))])),const Icon(Icons.star_rounded,color:Color(0xFFFFCB6A),size:21),Text(car.rating>0?car.rating.toStringAsFixed(1):'Fleet',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800))]),
          const SizedBox(height:23),
          Container(padding:const EdgeInsets.symmetric(vertical:19,horizontal:9),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(18)),child:Row(children:[
            _spec(Icons.event_seat_outlined,'${car.seats} Seats'),_spec(Icons.local_gas_station_outlined,car.fuel),_spec(Icons.settings_outlined,car.gearbox),_spec(Icons.badge_outlined,'DriveDesk'),
          ])),
          const SizedBox(height:27),const Text('Car specifications',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:13),
          Row(children:[Expanded(child:_infoBox(Icons.local_gas_station_outlined,'Fuel type',car.fuel)),const SizedBox(width:12),Expanded(child:_infoBox(Icons.event_seat_outlined,'Capacity','${car.seats} passenger seats'))]),
          const SizedBox(height:27),const Text('Features',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:13),
          Wrap(spacing:9,runSpacing:9,children:car.features.map((feature)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(14)),child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.check_rounded,size:15,color:C.teal),const SizedBox(width:7),Text(feature,style:const TextStyle(fontSize:11.5,color:C.white))]))).toList()),
          const SizedBox(height:26),const Text('About this car',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(car.description,style:const TextStyle(color:C.muted,fontSize:13,height:1.6)),
        ]))),
      ]),
      Positioned(bottom:0,left:0,right:0,child:Container(padding:EdgeInsets.fromLTRB(22,16,22,MediaQuery.of(context).padding.bottom+16),decoration:const BoxDecoration(color:C.panel,border:Border(top:BorderSide(color:C.border))),child:Row(children:[Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text('LKR ${car.price}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:C.teal)),const Text('per day',style:TextStyle(color:C.muted,fontSize:11))]),const SizedBox(width:24),Expanded(child:MainButton(text:'Book now',trailing:Icons.arrow_forward_rounded,onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DatesPage(car:car,initialDates:widget.initialDates,api:widget.api,onRentalDesk:widget.onRentalDesk,onBook:widget.onBook)))))]))),
    ]),
  );}
  Widget _spec(IconData icon,String label)=>Expanded(child:Column(children:[Icon(icon,color:C.teal,size:21),const SizedBox(height:8),Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700))]));
  Widget _infoBox(IconData icon,String title,String text)=>Container(height:102,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:C.teal,size:20),const Spacer(),Text(title,style:const TextStyle(fontSize:10,color:C.muted)),Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))]));
}

class FlowHeader extends StatelessWidget {
  final String title,step;
  const FlowHeader({super.key,required this.title,required this.step});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(22,14,22,20),child:Row(children:[SquareIcon(icon:Icons.arrow_back_rounded,onTap:()=>Navigator.pop(context)),Expanded(child:Column(children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(step,style:const TextStyle(color:C.muted,fontSize:10,letterSpacing:1))])),const SizedBox(width:42)]));
}
class DatesPage extends StatefulWidget {
  final RentalCar car;
  final DateTimeRange initialDates;
  final DriveApi api;
  final ValueChanged<int> onRentalDesk;
  final ValueChanged<RentalBooking> onBook;
  const DatesPage({super.key,required this.car,required this.initialDates,required this.api,required this.onRentalDesk,required this.onBook});
  @override State<DatesPage> createState()=>_DatesPageState();
}
class _DatesPageState extends State<DatesPage>{
  late DateTimeRange dates;
  TimeOfDay pickup=const TimeOfDay(hour:10,minute:0),dropoff=const TimeOfDay(hour:10,minute:0);
  @override void initState(){super.initState();dates=widget.initialDates;}
  Future<void> _pickDates() async {
    final chosen = await pickDriveDates(context,dates);
    if(chosen!=null && mounted)setState(()=>dates=chosen);
  }
  Future<void> _pickTime(bool start) async {
    final result=await showTimePicker(context:context,initialTime:start?pickup:dropoff,builder:(ctx,child)=>Theme(data:Theme.of(ctx).copyWith(colorScheme:const ColorScheme.dark(primary:C.teal,onPrimary:Colors.white,surface:C.panel,onSurface:C.white)),child:child!));
    if(result!=null)setState((){if(start){pickup=result;}else{dropoff=result;}});
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Column(children:[
    const FlowHeader(title:'Select dates',step:'STEP 1 OF 3'),
    Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,0,22,20),children:[
      ClipRRect(borderRadius:BorderRadius.circular(20),child:Stack(children:[CarPhoto(car:widget.car,height:170),Positioned(bottom:12,left:14,child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:C.bg.withOpacity(.83),borderRadius:BorderRadius.circular(12)),child:Text(widget.car.name,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900))))])),
      const SizedBox(height:24),const Text('When do you need the car?',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,letterSpacing:-.5)),const SizedBox(height:6),const Text('Pick your dates and times for a perfect trip.',style:TextStyle(fontSize:13,color:C.muted)),const SizedBox(height:22),
      GestureDetector(onTap:_pickDates,child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:C.border)),child:Column(children:[const Row(children:[Icon(Icons.calendar_month_rounded,color:C.teal,size:20),SizedBox(width:9),Text('RENTAL DATES',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1)),Spacer(),Icon(Icons.edit_calendar_outlined,color:C.teal,size:20)]),const Divider(color:C.border,height:26),Row(children:[Expanded(child:_dateText('PICK-UP',dates.start)),const Icon(Icons.arrow_forward_rounded,color:C.teal,size:20),Expanded(child:_dateText('DROP-OFF',dates.end))])]))),
      const SizedBox(height:23),const Text('Pick-up time',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),const SizedBox(height:10),_timeTile(pickup,()=>_pickTime(true)),
      const SizedBox(height:22),const Text('Drop-off time',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),const SizedBox(height:10),_timeTile(dropoff,()=>_pickTime(false)),
      const SizedBox(height:20),Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:15),decoration:BoxDecoration(color:C.teal.withOpacity(.13),borderRadius:BorderRadius.circular(14)),child:Row(children:[const Icon(Icons.info_outline_rounded,color:C.teal,size:20),const SizedBox(width:9),Text('Total rental duration: ${daysIn(dates)} days',style:const TextStyle(color:C.teal,fontWeight:FontWeight.w800,fontSize:13))])),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(22,13,22,16),child:MainButton(text:'Continue to driver options',trailing:Icons.arrow_forward_rounded,onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DriversPage(car:widget.car,api:widget.api,onRentalDesk:widget.onRentalDesk,dates:dates,onBook:widget.onBook))))),
  ])));
  Widget _dateText(String text, DateTime date)=>Column(crossAxisAlignment:CrossAxisAlignment.center,children:[Text(text,style:const TextStyle(color:C.muted,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:1)),const SizedBox(height:7),Text(dateLabel(date),style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800))]);
  Widget _timeTile(TimeOfDay time,VoidCallback onTap)=>InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(15)),child:Row(children:[const Icon(Icons.access_time_rounded,color:C.teal,size:20),const SizedBox(width:12),Text(time.format(context),style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700)),const Spacer(),const Icon(Icons.keyboard_arrow_down_rounded,color:C.muted)])));
}

class DemoDriver {
  final String name, experience;
  final int price;
  final double rating;
  const DemoDriver(this.name,this.experience,this.price,this.rating);
}
const drivers=[DemoDriver('James Wilson','8 years experience',80,4.9),DemoDriver('Robert Garcia','6 years experience',75,4.8),DemoDriver('David Chen','4 years experience',70,4.7)];
class DriversPage extends StatefulWidget {
  final RentalCar car;
  final DriveApi api;
  final ValueChanged<int> onRentalDesk;
  final DateTimeRange dates;
  final ValueChanged<RentalBooking> onBook;
  const DriversPage({super.key,required this.car,required this.api,required this.onRentalDesk,required this.dates,required this.onBook});
  @override State<DriversPage> createState()=>_DriversPageState();
}
class _DriversPageState extends State<DriversPage> {
  bool hireDriver=false;
  int selected=1;
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Column(children:[
    const FlowHeader(title:'Driver hire',step:'STEP 2 OF 3'),
    Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,8,22,20),children:[
      const Text('Would you like a driver?',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,letterSpacing:-.7)),const SizedBox(height:7),const Text('Driver-hire cards are a concept preview, not connected to staff or payment.',style:TextStyle(fontSize:13,color:C.muted)),
      const SizedBox(height:23),Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(18)),child:Row(children:[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:C.teal.withOpacity(.13),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.sports_motorsports_outlined,color:C.teal,size:22)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Hire a driver',style:TextStyle(fontWeight:FontWeight.w800,fontSize:14)),SizedBox(height:4),Text('Demo selection only • not connected to staff',style:TextStyle(color:C.muted,fontSize:11))])),Switch.adaptive(value:hireDriver,activeTrackColor:C.teal,onChanged:(v)=>setState(()=>hireDriver=v))])),
      const SizedBox(height:25),if(hireDriver)...[
        const Text('Select a driver',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:15),
        ...List.generate(drivers.length,(i){final d=drivers[i];final active=i==selected;return GestureDetector(onTap:()=>setState(()=>selected=i),child:Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:active?C.teal.withOpacity(.11):C.panel,border:Border.all(color:active?C.teal:C.border,width:active?1.2:1),borderRadius:BorderRadius.circular(17)),child:Row(children:[CircleAvatar(radius:24,backgroundColor:C.panel2,child:Text(d.name.split(' ').map((e)=>e[0]).join(),style:const TextStyle(color:C.teal,fontWeight:FontWeight.w900))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.name,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text('⭐ ${d.rating}  •  ${d.experience}',style:const TextStyle(fontSize:10,color:C.muted))])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Icon(active?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:active?C.teal:C.muted,size:22),const SizedBox(height:9),Text('Demo \$${d.price}/day',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:C.teal))])])));}),
        const SizedBox(height:8),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF173038),borderRadius:BorderRadius.circular(13)),child:const Row(children:[Icon(Icons.verified_user_outlined,color:Color(0xFF71C9DF)),SizedBox(width:12),Expanded(child:Text('Demo drivers are shown for UI testing; their identities and credentials have not been verified.',style:TextStyle(color:Color(0xFFB5E2E8),fontSize:11)))])),
      ]else Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(18)),child:const Column(children:[Icon(Icons.key_rounded,color:C.teal,size:38),SizedBox(height:10),Text('Self-drive freedom',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),SizedBox(height:7),Text('You will drive the car yourself. No driver fees will be added.',textAlign:TextAlign.center,style:TextStyle(color:C.muted,fontSize:12))])),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(22,12,22,16),child:MainButton(text:'Review booking',trailing:Icons.arrow_forward_rounded,onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>BookingReviewPage(car:widget.car,api:widget.api,onRentalDesk:widget.onRentalDesk,dates:widget.dates,driver:hireDriver?drivers[selected]:null,onBook:widget.onBook))))),
  ])));
}

class BookingReviewPage extends StatefulWidget {
  final RentalCar car;
  final DateTimeRange dates;
  final DemoDriver? driver;
  final DriveApi api;
  final ValueChanged<RentalBooking> onBook;
  final ValueChanged<int> onRentalDesk;
  const BookingReviewPage({super.key,required this.car,required this.dates,
    required this.driver,required this.api,required this.onBook,required this.onRentalDesk});
  @override State<BookingReviewPage> createState()=>_BookingReviewPageState();
}
class _BookingReviewPageState extends State<BookingReviewPage> {
  List<dynamic> customers=[];
  int? customerId;
  bool loading=true,submitting=false;
  String? error;
  @override void initState(){super.initState();_loadCustomers();}
  Future<void> _loadCustomers()async{
    try{final rows=await widget.api.list('/api/customers');if(mounted)setState((){
      customers=rows;customerId=rows.isNotEmpty?(rows.first['id'] as num).toInt():null;loading=false;});}
    catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  Future<void> _confirm()async{
    if(submitting||customerId==null||widget.driver!=null)return;
    setState((){submitting=true;error=null;});
    try{
      final from=_iso(widget.dates.start),to=_iso(widget.dates.end),vid=int.parse(widget.car.id);
      if(!widget.dates.end.isAfter(widget.dates.start))throw Exception('Return must be after pickup.');
      final q=Uri(queryParameters:{'vehicle_id':'$vid','pickup_date':from,'return_date':to}).query;
      final availability=await widget.api.map('/api/availability?$q');
      if(availability['available']!=true)throw Exception('Unavailable on these dates: ${availability['reason']}');
      final result=await widget.api.post('/api/bookings',{
        'vehicle_id':vid,'customer_id':customerId,'pickup_date':from,'return_date':to,
        'use_suggested_price':false,
      });
      final id=(result['id'] as num).toInt();
      widget.onBook(RentalBooking(widget.car,widget.dates,'Self-drive',
        (num.tryParse('${result['total_amount']}')??0).round(),bookingId:id,
        customer:customers.firstWhere((c)=>c['id']==customerId)['name'].toString()));
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute<void>(builder:(_)=>BookingSuccessPage(
        car:widget.car,dates:widget.dates,total:(num.tryParse('${result['total_amount']}')??0).round(),
        bookingId:id,onRentalDesk:()=>widget.onRentalDesk(id))));
    }catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>submitting=false);}
  }
  @override Widget build(BuildContext context){
    final car=widget.car,days=daysIn(widget.dates),total=days*car.price;
    return Scaffold(body:SafeArea(child:Column(children:[
      const FlowHeader(title:'Review booking',step:'STEP 3 OF 3'),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,0,22,20),children:[
        const Text('Almost there!',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900)),
        const SizedBox(height:9),const Text('Staff-assisted booking • real fleet and customer database',style:TextStyle(color:C.muted,fontSize:12)),
        const SizedBox(height:20),CarPhoto(car:car,height:160),const SizedBox(height:14),
        Text(car.name,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:19),
        _row('Pick-up',dateLabel(widget.dates.start)),_row('Return',dateLabel(widget.dates.end)),
        _row('Duration','$days rental days'),_row('Driver',widget.driver?.name??'Self-drive'),
        const SizedBox(height:10),const Text('Registered customer',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),if(loading)const Center(child:CircularProgressIndicator(color:C.teal)),
        if(!loading && customers.isEmpty)const Text('Register a customer in DriveDesk → Customers first.',style:TextStyle(color:C.muted)),
        if(customers.isNotEmpty)DropdownButtonFormField<int>(key:ValueKey(customerId),value:customerId,
          dropdownColor:C.panel2,decoration:const InputDecoration(labelText:'Choose customer',border:OutlineInputBorder()),
          items:customers.map<DropdownMenuItem<int>>((c)=>DropdownMenuItem(value:(c['id'] as num).toInt(),child:Text('${c['name']}'))).toList(),
          onChanged:(id)=>setState(()=>customerId=id)),
        const SizedBox(height:20),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(17)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Rental estimate',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
            const SizedBox(height:12),_row('LKR ${car.price} x $days days','LKR $total'),
            const Divider(color:C.border,height:20),const Text('Backend calculates final payable total when the booking is created.',style:TextStyle(color:C.muted,fontSize:11))])),
        const SizedBox(height:14),if(widget.driver!=null)const Text('Driver-hire integration is not configured. Select Self-drive to create an actual reservation.',
          style:TextStyle(color:Colors.orangeAccent,fontSize:12)),
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(error!,style:const TextStyle(color:Colors.redAccent))),
        const SizedBox(height:12),const Text('This creates a PENDING booking, not a payment or confirmed pickup. Complete approval and inspections in Rental Desk.',style:TextStyle(color:C.muted,fontSize:11,height:1.4)),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(22,10,22,16),child:MainButton(text:submitting?'Saving booking…':'Create pending booking',trailing:Icons.check_rounded,
        onTap:(submitting||loading||customerId==null||widget.driver!=null)?null:_confirm)),
    ])));
  }
  Widget _row(String title,String value)=>Padding(padding:const EdgeInsets.only(bottom:13),child:Row(children:[Text(title,style:const TextStyle(color:C.muted,fontSize:12)),const Spacer(),Flexible(child:Text(value,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12),textAlign:TextAlign.right))]));
}

class BookingSuccessPage extends StatelessWidget {
  final RentalCar car;
  final DateTimeRange dates;
  final int total,bookingId;
  final VoidCallback onRentalDesk;
  const BookingSuccessPage({super.key,required this.car,required this.dates,
    required this.total,required this.bookingId,required this.onRentalDesk});
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.all(25),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    const Icon(Icons.check_circle,color:C.teal,size:82),const SizedBox(height:22),
    Text('Booking #$bookingId saved!',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900)),
    const SizedBox(height:12),const Text('Pending reservation saved in DriveDesk database. No payment has been taken.',textAlign:TextAlign.center,style:TextStyle(color:C.muted)),
    const SizedBox(height:20),Text('${car.name}  •  ${dateLabel(dates.start)} – ${dateLabel(dates.end)}',textAlign:TextAlign.center),
    const SizedBox(height:10),Text('LKR $total',style:const TextStyle(color:C.teal,fontSize:24,fontWeight:FontWeight.w900)),
    const SizedBox(height:25),MainButton(text:'Continue in Rental Desk',trailing:Icons.arrow_forward,onTap:(){Navigator.of(context).popUntil((r)=>r.isFirst);onRentalDesk();}),
    const SizedBox(height:12),MainButton(text:'Return to showroom',outline:true,onTap:()=>Navigator.of(context).popUntil((route)=>route.isFirst)),
  ]))));
}

// ---- Other navigation tabs --------------------------------------------------
class BookingsPage extends StatelessWidget {
  final List<RentalBooking> bookings;
  final VoidCallback onExplore;
  const BookingsPage({super.key,required this.bookings,required this.onExplore});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Padding(padding:EdgeInsets.fromLTRB(22,23,22,9),child:Text('Fleet bookings',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900))),
    Expanded(child:bookings.isEmpty?EmptyState(icon:Icons.calendar_month_outlined,title:'No bookings yet',message:'Choose a registered vehicle and create a pending reservation.',button:'Explore cars',onTap:onExplore):ListView.separated(padding:const EdgeInsets.all(22),itemCount:bookings.length,separatorBuilder:(_,__)=>const SizedBox(height:15),itemBuilder:(ctx,i){final b=bookings[i];return Container(decoration:BoxDecoration(color:C.panel,border:Border.all(color:C.border),borderRadius:BorderRadius.circular(19)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CarPhoto(car:b.car,height:160,radius:const BorderRadius.vertical(top:Radius.circular(18))),Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(b.car.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:C.teal.withOpacity(.13),borderRadius:BorderRadius.circular(9)),child:Text('#${b.bookingId} ${b.status.toUpperCase()}',style:const TextStyle(color:C.teal,fontSize:9,fontWeight:FontWeight.w900)))]),const SizedBox(height:7),Text('${dateLabel(b.dates.start)} – ${dateLabel(b.dates.end)}',style:const TextStyle(color:C.muted,fontSize:12)),const SizedBox(height:6),Text('Customer: ${b.customer}',style:const TextStyle(color:C.muted,fontSize:12)),const SizedBox(height:8),Text('LKR ${b.total}',style:const TextStyle(color:C.teal,fontSize:22,fontWeight:FontWeight.w900))]))]));})),
  ]);
}
class SavedPage extends StatelessWidget {
  final List<RentalCar> fleet;
  final Set<String> favoriteIds;
  final void Function(RentalCar) onOpen,onFav;
  const SavedPage({super.key,required this.fleet,required this.favoriteIds,required this.onOpen,required this.onFav});
  @override Widget build(BuildContext context){final saved=fleet.where((c)=>favoriteIds.contains(c.id)).toList();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Padding(padding:EdgeInsets.fromLTRB(22,23,22,3),child:Text('Saved cars',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900))),const Padding(padding:EdgeInsets.symmetric(horizontal:22),child:Text('Saved fleet vehicles (this session only)',style:TextStyle(color:C.muted,fontSize:12))),const SizedBox(height:19),Expanded(child:saved.isEmpty?const EmptyState(icon:Icons.favorite_border_rounded,title:'No favorites yet',message:'Tap the heart on any car to save it.'):GridView.builder(padding:const EdgeInsets.symmetric(horizontal:20),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.66,crossAxisSpacing:12,mainAxisSpacing:13),itemCount:saved.length,itemBuilder:(ctx,i){final car=saved[i];return CarTile(car:car,onOpen:()=>onOpen(car),onFav:()=>onFav(car),favorite:true);})),]);}
}
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(22,23,22,22),children:[
    const Text('My profile',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900)),const SizedBox(height:24),
    Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(color:C.panel,borderRadius:BorderRadius.circular(19)),child:const Row(children:[CircleAvatar(radius:27,backgroundColor:C.teal,child:Icon(Icons.person_rounded,color:Colors.white,size:31)),SizedBox(width:15),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('DriveDesk Staff',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),SizedBox(height:4),Text('DriveDesk unified rental workspace',style:TextStyle(color:C.muted,fontSize:11))])])),
    const SizedBox(height:29),const Text('ACCOUNT',style:TextStyle(letterSpacing:1.5,color:C.muted,fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:13),
    _item(context,Icons.person_outline_rounded,'Account information'),_item(context,Icons.payment_outlined,'Payment methods'),_item(context,Icons.notifications_none_rounded,'Notifications'),
    const SizedBox(height:24),const Text('SUPPORT',style:TextStyle(letterSpacing:1.5,color:C.muted,fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:13),
    _item(context,Icons.help_outline_rounded,'Help & support'),_item(context,Icons.info_outline_rounded,'About this demo'),
    const SizedBox(height:33),const Center(child:Text('DRIVEDESK PRO  •  v2.3',style:TextStyle(color:C.muted,fontSize:10,letterSpacing:1.1))),
  ]);
  Widget _item(BuildContext context,IconData icon,String title)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:C.panel,borderRadius:BorderRadius.circular(14),child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>note(context,'$title: demo UI only'),child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:17),child:Row(children:[Icon(icon,color:C.teal,size:21),const SizedBox(width:13),Expanded(child:Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700))),const Icon(Icons.chevron_right_rounded,color:C.muted,size:18)])))));
}
class EmptyState extends StatelessWidget {
  final IconData icon;final String title,message,button;final VoidCallback? onTap;
  const EmptyState({super.key,required this.icon,required this.title,required this.message,this.button='',this.onTap});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.symmetric(horizontal:35),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:88,height:88,decoration:BoxDecoration(color:C.teal.withOpacity(.12),shape:BoxShape.circle),child:Icon(icon,color:C.teal,size:42)),const SizedBox(height:21),Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:C.muted,fontSize:13)),if(onTap!=null && button.isNotEmpty)...[const SizedBox(height:23),SizedBox(width:210,child:MainButton(text:button,onTap:onTap))]])));
}
