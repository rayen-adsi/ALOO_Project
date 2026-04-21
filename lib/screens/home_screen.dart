// lib/screens/home_screen.dart
//
// Redesigned home screen:
//   • Greeting with time-of-day message + user's city
//   • Search bar — submit opens CategoryResultsScreen
//   • Categories row — tap opens CategoryResultsScreen (full page, all providers)
//   • "Near You" section — top 6 score-sorted providers within 5km
//     Score is NEVER shown to users. Internal ranking only.
//   • Pull-to-refresh
//   • Falls back to top global providers if no location set

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';
import '../core/notification_provider.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'provider_profile_screen.dart';
import 'chat_screen.dart';
import 'favorites_screen.dart';
import 'conversations_screen.dart';
import 'notifications_screen.dart';
import 'map_screen.dart';

// ── Category metadata ─────────────────────────────────────────────────────────
class _CatMeta {
  final String   key;
  final String   label;
  final IconData icon;
  final Color    color;
  const _CatMeta({required this.key, required this.label,
                  required this.icon, required this.color});
}

const List<_CatMeta> _kCategories = [
  _CatMeta(key:'cat_plumber',     label:'Plombier',            icon:Icons.water_drop_outlined,          color:Color(0xFF0EA5E9)),
  _CatMeta(key:'cat_electrician', label:'Electricien',         icon:Icons.bolt_outlined,                color:Color(0xFFF59E0B)),
  _CatMeta(key:'cat_mechanic',    label:'Mecanicien',          icon:Icons.build_outlined,               color:Color(0xFF6D28D9)),
  _CatMeta(key:'cat_home_repair', label:'Reparation domicile', icon:Icons.home_repair_service_outlined, color:Color(0xFF10B981)),
  _CatMeta(key:'cat_cleaner',     label:'Femme de menage',     icon:Icons.cleaning_services_outlined,   color:Color(0xFFEC4899)),
  _CatMeta(key:'cat_tutor',       label:'Professeur',          icon:Icons.school_outlined,              color:Color(0xFF0D9488)),
  _CatMeta(key:'cat_developer',   label:'Developpeur',         icon:Icons.laptop_outlined,              color:Color(0xFF8B5CF6)),
];

const Map<String, Color> _kCatColors = {
  'Plombier':Color(0xFF0EA5E9),'Electricien':Color(0xFFF59E0B),
  'Mecanicien':Color(0xFF6D28D9),'Reparation domicile':Color(0xFF10B981),
  'Femme de menage':Color(0xFFEC4899),'Professeur':Color(0xFF0D9488),
  'Developpeur':Color(0xFF8B5CF6),
};

// ─────────────────────────────────────────────────────────────────────────────
// homeScreen — 5-tab shell
// ─────────────────────────────────────────────────────────────────────────────
class homeScreen extends StatefulWidget {
  final String fullName;
  const homeScreen({super.key, this.fullName = ''});
  @override State<homeScreen> createState() => _homeScreenState();
}

class _homeScreenState extends State<homeScreen> {
  int    _nav     = 0;
  int    _userId  = 0;
  String _role    = 'client';

  final _favKey  = GlobalKey<FavoritesScreenState>();
  final _convKey = GlobalKey<ConversationsScreenState>();

  @override
  void initState() { super.initState(); _loadSession(); }

  Future<void> _loadSession() async {
    final s = await UserSession.load();
    if (!mounted) return;
    setState(() { _userId = s['id'] ?? 0; _role = s['role'] ?? 'client'; });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final tabs = <Widget>[
      _HomeTab(userId: _userId),
      FavoritesScreen(key: _favKey, clientId: _userId),
      SizedBox.expand(child: MapScreen()),
      ConversationsScreen(key: _convKey, userId: _userId, userRole: _role),
      const SettingsScreen(),
    ];
    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: IndexedStack(index: _nav, children: tabs),
        bottomNavigationBar: _BottomNav(
          currentIndex: _nav,
          onTap: (i) {
            setState(() => _nav = i);
            if (i == 1) _favKey.currentState?.reload();
            if (i == 3) _convKey.currentState?.reload();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HomeTab — tab 0 body
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final int userId;
  const _HomeTab({required this.userId});
  @override State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<Map<String,dynamic>> _top = [];
  bool    _loading     = true;
  bool    _hasLoc      = false;
  String  _city        = '';
  double? _lat, _lng;

  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId && widget.userId > 0) _load();
  }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await UserSession.load();
    _hasLoc = s['location_set'] == true;
    _lat    = (s['lat'] as num?)?.toDouble();
    _lng    = (s['lng'] as num?)?.toDouble();
    _city   = s['city'] as String? ?? '';
    try {
      List<Map<String,dynamic>> res;
      if (_hasLoc && _lat != null && _lng != null) {
        // GPS top-6 within 5 km, score-sorted server-side (silent to users)
        res = await ApiService.searchProviders(lat:_lat, lng:_lng, radius:5.0, limit:6);
      } else {
        final all = await ApiService.getProviders();
        res = all.take(6).toList();
      }
      if (!mounted) return;
      setState(() { _top = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _search(String q) {
    if (q.trim().isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
      CategoryResultsScreen(title:'"${q.trim()}"', searchQuery:q.trim(),
        userLat:_lat, userLng:_lng)));
  }

  void _openCat(_CatMeta c, LanguageProvider lang) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
      CategoryResultsScreen(title:lang.t(c.key), category:c.label,
        color:c.color, icon:c.icon, userLat:_lat, userLng:_lng)));

  void _profile(Map<String,dynamic> p) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
      ProviderProfileScreen(providerId: p['id'] as int)));

  void _chat(Map<String,dynamic> p) =>
    Navigator.push(context, chatScreenRoute(
      providerId:p['id'] as int,
      providerName:(p['full_name']??'') as String,
      providerCategory:(p['category']??'') as String?));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

    return Stack(children: [
      Positioned.fill(child: Image.asset('assets/images/bg.png', fit:BoxFit.cover)),
      Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
        begin:Alignment.topCenter, end:Alignment.bottomCenter,
        colors:[Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.75),
                Colors.white.withOpacity(0.97)])))),
      SafeArea(bottom:false, child: RefreshIndicator(
        onRefresh: _load, color: const Color(0xFF2A5298),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent:BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _topBar(user, lang)),
            SliverToBoxAdapter(child: _greeting(user, lang)),
            SliverToBoxAdapter(child: _searchBar(lang)),
            SliverToBoxAdapter(child: _categories(lang)),
            SliverToBoxAdapter(child: _nearYou(lang)),
            const SliverToBoxAdapter(child: SizedBox(height:28)),
          ],
        ),
      )),
    ]);
  }

  // ── top bar ───────────────────────────────────────────────────────────────
  Widget _topBar(UserProvider user, LanguageProvider lang) {
    final n = context.watch<NotificationProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18,12,18,0),
      child: Row(children:[
        Image.asset('assets/images/aloo_logo.png', height:56, fit:BoxFit.contain),
        const Spacer(),
        if (user.fullName.isNotEmpty)...[
          Text(user.fullName, style:const TextStyle(fontSize:14,
            fontWeight:FontWeight.w800, color:Colors.white)),
          const SizedBox(width:10),
        ],
        // bell
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, PageRouteBuilder(
              pageBuilder:(_,__,___)=>const NotificationsScreen(),
              transitionDuration:const Duration(milliseconds:320),
              transitionsBuilder:(_,anim,__,child)=>FadeTransition(
                opacity:CurvedAnimation(parent:anim,curve:Curves.easeOut),child:child)));
            if (mounted) context.read<NotificationProvider>().refresh();
          },
          child: Stack(clipBehavior:Clip.none, children:[
            Container(width:40,height:40,
              decoration:BoxDecoration(color:Colors.white.withOpacity(0.18),
                shape:BoxShape.circle,
                border:Border.all(color:Colors.white.withOpacity(0.30),width:1)),
              child:const Icon(Icons.notifications_rounded,color:Colors.white,size:20)),
            if (n.unreadCount>0)
              Positioned(top:-2,right:-2,child:Container(
                constraints:const BoxConstraints(minWidth:18,minHeight:18),
                padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),
                decoration:BoxDecoration(
                  color:const Color(0xFFEF4444),
                  shape:n.unreadCount<10?BoxShape.circle:BoxShape.rectangle,
                  borderRadius:n.unreadCount<10?null:BorderRadius.circular(9),
                  border:Border.all(color:Colors.white,width:1.5)),
                child:Text(n.unreadCount>99?'99+':'${n.unreadCount}',
                  style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,
                    color:Colors.white,height:1.1),
                  textAlign:TextAlign.center))),
          ])),
        const SizedBox(width:10),
        // avatar
        GestureDetector(
          onTap: () async {
            final r = await Navigator.push(context,
              MaterialPageRoute(builder:(_)=>const EditProfileScreen()));
            if (r==true && mounted) await context.read<UserProvider>().load();
          },
          child: Container(width:40,height:40,
            decoration:BoxDecoration(shape:BoxShape.circle,
              border:Border.all(color:Colors.white,width:2),
              color:const Color(0xFF2A5298).withOpacity(0.30)),
            child: user.photoPath!=null
              ? ClipOval(child:Image.network(user.photoPath!,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>_initial(user)))
              : _initial(user))),
      ]));
  }

  Widget _initial(UserProvider u) => Center(child:Text(
    u.fullName.isNotEmpty?u.fullName[0].toUpperCase():'?',
    style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Colors.white)));

  // ── greeting ──────────────────────────────────────────────────────────────
  Widget _greeting(UserProvider user, LanguageProvider lang) {
    final g = lang.t('welcome');
    final first = user.fullName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18,22,18,0),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text('$g ${first.isNotEmpty ? first : ""}', 
          style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:Colors.white,height:1.2)),
        const SizedBox(height:4),
        
        if (_hasLoc && _city.isNotEmpty)...[
          const SizedBox(height:6),
          Row(children:[
            const Icon(Icons.location_on_rounded,color:Colors.white70,size:14),
            const SizedBox(width:4),
            Text(_city,style:const TextStyle(fontSize:12,color:Colors.white70,fontWeight:FontWeight.w600)),
          ]),
        ],
      ]));
  }

  // ── search bar ────────────────────────────────────────────────────────────
  Widget _searchBar(LanguageProvider lang) => Padding(
    padding: const EdgeInsets.fromLTRB(16,16,16,0),
    child: Container(height:52,
      decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.10),blurRadius:16,offset:const Offset(0,4))]),
      child:TextField(
        controller:_searchCtrl,
        onSubmitted:_search,
        textInputAction:TextInputAction.search,
        style:const TextStyle(fontSize:15,fontWeight:FontWeight.w500),
        decoration:InputDecoration(
          hintText:lang.t('search_placeholder'),
          hintStyle:TextStyle(fontSize:15,color:Colors.grey.shade400,fontWeight:FontWeight.w400),
          prefixIcon:Icon(Icons.search_rounded,color:const Color(0xFF2A5298).withOpacity(0.7),size:22),
          suffixIcon:ValueListenableBuilder(
            valueListenable:_searchCtrl,
            builder:(_,v,__)=>(v as TextEditingValue).text.isNotEmpty
              ? IconButton(icon:Icon(Icons.close_rounded,color:Colors.grey.shade400,size:18),
                  onPressed:()=>_searchCtrl.clear())
              : const SizedBox.shrink()),
          border:InputBorder.none,
          contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16)))));

  // ── categories ────────────────────────────────────────────────────────────
  Widget _categories(LanguageProvider lang) => Padding(
    padding:const EdgeInsets.only(top:22),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:18),
        child:Text(lang.t('browse_by_category'),
          style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF0F172A)))),
      const SizedBox(height:12),
      SizedBox(height:92,child:ListView.builder(
        scrollDirection:Axis.horizontal,
        physics:const BouncingScrollPhysics(),
        padding:const EdgeInsets.symmetric(horizontal:16),
        itemCount:_kCategories.length,
        itemBuilder:(_,i)=>_CatChip(
          meta:_kCategories[i], lang:lang,
          onTap:()=>_openCat(_kCategories[i],lang)))),
    ]));

  // ── near you ──────────────────────────────────────────────────────────────
  Widget _nearYou(LanguageProvider lang) => Padding(
    padding:const EdgeInsets.fromLTRB(16,24,16,0),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(width:4,height:22,
          decoration:BoxDecoration(
            gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[Color(0xFF1A3A6B),Color(0xFF2A5298)]),
            borderRadius:BorderRadius.circular(4))),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_hasLoc ? lang.t('recommended_near_you') : lang.t('recommended'),
            style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Color(0xFF0F172A))),
          if (_hasLoc)
            Text(lang.t('within_5km'),
              style:TextStyle(fontSize:12,color:Colors.grey.shade500,fontWeight:FontWeight.w500)),
        ])),
      ]),
      const SizedBox(height:16),
      if (_loading)
        const Center(child:Padding(padding:EdgeInsets.symmetric(vertical:40),
          child:CircularProgressIndicator(color:Color(0xFF2A5298),strokeWidth:2.5)))
      else if (_top.isEmpty)
        _emptyState(lang)
      else
        GridView.builder(
          shrinkWrap:true,
          physics:const NeverScrollableScrollPhysics(),
          gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:0.67),
          itemCount:_top.length,
          itemBuilder:(_,i)=>_ProvCard(data:_top[i],lang:lang,
            onTap:()=>_profile(_top[i]),onContact:()=>_chat(_top[i]))),
    ]));

  Widget _emptyState(LanguageProvider lang) => Container(
    width:double.infinity,
    padding:const EdgeInsets.symmetric(vertical:40,horizontal:24),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
      boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.05),blurRadius:12,offset:const Offset(0,4))]),
    child:Column(children:[
      Container(width:64,height:64,
        decoration:BoxDecoration(color:const Color(0xFF2A5298).withOpacity(0.08),shape:BoxShape.circle),
        child:const Icon(Icons.travel_explore_rounded,color:Color(0xFF2A5298),size:30)),
      const SizedBox(height:14),
      Text(lang.t('no_providers_nearby'),
        style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:Color(0xFF1A3A6B))),
      const SizedBox(height:6),
      Text(lang.t('try_different_area'),textAlign:TextAlign.center,
        style:TextStyle(fontSize:13,color:Colors.grey.shade500)),
      const SizedBox(height:16),
      TextButton.icon(onPressed:_load,
        icon:const Icon(Icons.refresh_rounded,size:16),label:Text(lang.t('retry')),
        style:TextButton.styleFrom(foregroundColor:const Color(0xFF2A5298))),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// CategoryResultsScreen
// ─────────────────────────────────────────────────────────────────────────────
class CategoryResultsScreen extends StatefulWidget {
  final String    title;
  final String?   category;
  final String?   searchQuery;
  final Color     color;
  final IconData? icon;
  final double?   userLat;
  final double?   userLng;

  const CategoryResultsScreen({
    super.key,required this.title,this.category,this.searchQuery,
    this.color=const Color(0xFF2A5298),this.icon,this.userLat,this.userLng});

  @override State<CategoryResultsScreen> createState() => _CatResultsState();
}

class _CatResultsState extends State<CategoryResultsScreen> {
  List<Map<String,dynamic>> _list = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final r = await ApiService.searchProviders(
        q:widget.searchQuery,
        category:widget.category,
        lat:widget.userLat,
        lng:widget.userLng,
        radius:widget.userLat!=null ? 50.0 : 0,
        // wide radius so ALL providers in category appear,
        // still score-sorted server-side — invisible to user
      );
      if (!mounted) return;
      setState(() { _list = r; _loading = false; });
    } catch(_) { if (mounted) setState(()=>_loading=false); }
  }

  void _profile(Map<String,dynamic> p) => Navigator.push(context,
    MaterialPageRoute(builder:(_)=>ProviderProfileScreen(providerId:p['id'] as int)));

  void _chat(Map<String,dynamic> p) => Navigator.push(context, chatScreenRoute(
    providerId:p['id'] as int,
    providerName:(p['full_name']??'') as String,
    providerCategory:(p['category']??'') as String?));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor:const Color(0xFFF5F7FA),
      body:CustomScrollView(
        physics:const BouncingScrollPhysics(),
        slivers:[
          SliverAppBar(
            expandedHeight:140, pinned:true, elevation:0,
            backgroundColor:widget.color,
            leading:GestureDetector(
              onTap:()=>Navigator.pop(context),
              child:Container(margin:const EdgeInsets.all(8),
                decoration:BoxDecoration(color:Colors.white.withOpacity(0.20),
                  borderRadius:BorderRadius.circular(10)),
                child:const Icon(Icons.arrow_back_ios_new_rounded,color:Colors.white,size:18))),
            flexibleSpace:FlexibleSpaceBar(
              background:Container(
                decoration:BoxDecoration(gradient:LinearGradient(
                  begin:Alignment.topLeft,end:Alignment.bottomRight,
                  colors:[widget.color.withOpacity(0.85),widget.color])),
                padding:const EdgeInsets.fromLTRB(20,80,20,16),
                child:Row(children:[
                  if (widget.icon!=null)...[
                    Container(width:44,height:44,
                      decoration:BoxDecoration(color:Colors.white.withOpacity(0.20),
                        borderRadius:BorderRadius.circular(12)),
                      child:Icon(widget.icon,color:Colors.white,size:24)),
                    const SizedBox(width:14),
                  ],
                  Expanded(child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    mainAxisAlignment:MainAxisAlignment.center,
                    children:[
                      Text(widget.title,style:const TextStyle(fontSize:22,
                        fontWeight:FontWeight.w900,color:Colors.white)),
                      if (!_loading)
                        Text('${_list.length} ${lang.t('providers_found')}',
                          style:TextStyle(fontSize:13,color:Colors.white.withOpacity(0.80))),
                    ])),
                ]))),
          ),
          if (_loading)
            const SliverFillRemaining(child:Center(child:CircularProgressIndicator(
              color:Color(0xFF2A5298),strokeWidth:2.5)))
          else if (_list.isEmpty)
            SliverFillRemaining(child:Center(child:Padding(
              padding:const EdgeInsets.all(40),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                Icon(Icons.search_off_rounded,color:Colors.grey.shade300,size:56),
                const SizedBox(height:16),
                Text(lang.t('no_providers_found'),
                  style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(0xFF1A3A6B))),
                const SizedBox(height:8),
                Text(lang.t('try_different_area'),textAlign:TextAlign.center,
                  style:TextStyle(fontSize:13,color:Colors.grey.shade500)),
              ]))))
          else
            SliverPadding(
              padding:const EdgeInsets.fromLTRB(16,16,16,32),
              sliver:SliverGrid(
                gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:0.67),
                delegate:SliverChildBuilderDelegate(
                  (_,i)=>_ProvCard(data:_list[i],lang:lang,
                    onTap:()=>_profile(_list[i]),onContact:()=>_chat(_list[i])),
                  childCount:_list.length))),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CatChip
// ─────────────────────────────────────────────────────────────────────────────
class _CatChip extends StatefulWidget {
  final _CatMeta meta; final LanguageProvider lang; final VoidCallback onTap;
  const _CatChip({required this.meta,required this.lang,required this.onTap});
  @override State<_CatChip> createState() => _CatChipState();
}
class _CatChipState extends State<_CatChip> {
  bool _p=false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap:widget.onTap,
    onTapDown:(_)=>setState(()=>_p=true),
    onTapUp:(_)=>setState(()=>_p=false),
    onTapCancel:()=>setState(()=>_p=false),
    child:AnimatedScale(scale:_p?0.93:1.0,duration:const Duration(milliseconds:120),
      child:Container(width:78,margin:const EdgeInsets.only(right:12),
        padding:const EdgeInsets.symmetric(vertical:10),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
          boxShadow:[BoxShadow(color:widget.meta.color.withOpacity(0.18),blurRadius:10,offset:const Offset(0,4))]),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:42,height:42,
            decoration:BoxDecoration(color:widget.meta.color.withOpacity(0.12),shape:BoxShape.circle),
            child:Icon(widget.meta.icon,color:widget.meta.color,size:22)),
          const SizedBox(height:6),
          Padding(padding:const EdgeInsets.symmetric(horizontal:4),
            child:Text(widget.lang.t(widget.meta.key),
              maxLines:2,textAlign:TextAlign.center,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,
                color:Color(0xFF1E293B),height:1.2))),
        ]))));
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProvCard — shared provider card
// ─────────────────────────────────────────────────────────────────────────────
class _ProvCard extends StatelessWidget {
  final Map<String,dynamic> data;
  final LanguageProvider    lang;
  final VoidCallback        onTap;
  final VoidCallback        onContact;
  const _ProvCard({required this.data,required this.lang,
                   required this.onTap,required this.onContact});

  @override
  Widget build(BuildContext context) {
    final cat   = data['category'] as String? ?? '';
    final color = _kCatColors[cat] ?? const Color(0xFF2A5298);
    final rating= (data['rating'] as num?)?.toDouble() ?? 0.0;
    final verf  = data['is_verified']==true;
    final photo = data['profile_photo'] as String?;
    final dist  = data['distance_km'];

    return GestureDetector(onTap:onTap,child:Container(
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.07),blurRadius:16,offset:const Offset(0,6))]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Stack(children:[
          Container(height:110,width:double.infinity,
            decoration:BoxDecoration(
              gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:[color.withOpacity(0.85),color]),
              borderRadius:const BorderRadius.vertical(top:Radius.circular(18))),
            child:photo!=null
              ? ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(18)),
                  child:Image.network(photo,fit:BoxFit.cover,
                    errorBuilder:(_,__,___)=>const Icon(Icons.person_rounded,color:Colors.white54,size:48)))
              : const Icon(Icons.person_rounded,color:Colors.white54,size:48)),
          if (verf) Positioned(top:8,left:8,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[Color(0xFFFF6B35),Color(0xFFFF8C42)]),
              borderRadius:BorderRadius.circular(8),
              boxShadow:[BoxShadow(color:const Color(0xFFFF6B35).withOpacity(0.4),blurRadius:6)]),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.verified_rounded,color:Colors.white,size:10),
              const SizedBox(width:3),
              Text(lang.t('top_provider'),style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w800)),
            ]))),
          if (dist!=null) Positioned(top:8,right:8,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
            decoration:BoxDecoration(color:Colors.black.withOpacity(0.55),borderRadius:BorderRadius.circular(8)),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.near_me_rounded,color:Colors.white,size:10),
              const SizedBox(width:3),
              Text('$dist km',style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
            ]))),
        ]),
        Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(10,8,10,8),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(data['full_name'] as String? ?? '',maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:Color(0xFF0F172A))),
            const SizedBox(height:3),
            Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
              decoration:BoxDecoration(color:color.withOpacity(0.10),borderRadius:BorderRadius.circular(6)),
              child:Text(cat,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:color))),
            const SizedBox(height:5),
            Row(children:[
              const Icon(Icons.star_rounded,color:Color(0xFFFBBF24),size:13),
              const SizedBox(width:3),
              Text(rating>0?rating.toStringAsFixed(1):lang.t('new_provider'),
                style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Color(0xFF475569))),
            ]),
            const SizedBox(height:2),
            Row(children:[
              const Icon(Icons.location_on_rounded,color:Color(0xFF94A3B8),size:11),
              const SizedBox(width:2),
              Expanded(child:Text(data['city'] as String? ?? '',maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:10.5,color:Color(0xFF94A3B8),fontWeight:FontWeight.w500))),
            ]),
            const Spacer(),
            Row(children:[
              Expanded(child:GestureDetector(onTap:onContact,behavior:HitTestBehavior.opaque,
                child:Container(height:30,
                  decoration:BoxDecoration(border:Border.all(color:const Color(0xFF2174FC),width:1.3),
                    borderRadius:BorderRadius.circular(8)),
                  child:Center(child:Text(lang.t('contact'),
                    style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700,color:Color(0xFF2174FC))))))),
              const SizedBox(width:6),
              Expanded(child:GestureDetector(onTap:onTap,behavior:HitTestBehavior.opaque,
                child:Container(height:30,
                  decoration:BoxDecoration(color:const Color(0xFF2174FC),borderRadius:BorderRadius.circular(8)),
                  child:Center(child:Text(lang.t('view_profile'),
                    style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700,color:Colors.white)))))),
            ]),
          ]))),
      ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomNav
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex; final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex,required this.onTap});
  @override
  Widget build(BuildContext context) {
    const items=[
      {'icon':Icons.home_outlined,              'active':Icons.home_rounded},
      {'icon':Icons.favorite_border_rounded,    'active':Icons.favorite_rounded},
      {'icon':Icons.location_on_outlined,       'active':Icons.location_on_rounded},
      {'icon':Icons.chat_bubble_outline_rounded,'active':Icons.chat_bubble_rounded},
      {'icon':Icons.settings_outlined,          'active':Icons.settings_rounded},
    ];
    return Container(
      decoration:BoxDecoration(color:Colors.white,
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.08),blurRadius:20,offset:const Offset(0,-4))]),
      child:SafeArea(top:false,child:SizedBox(height:60,
        child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,
          children:List.generate(items.length,(i){
            final a=currentIndex==i;
            return GestureDetector(onTap:()=>onTap(i),behavior:HitTestBehavior.opaque,
              child:SizedBox(width:52,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                AnimatedContainer(duration:const Duration(milliseconds:200),
                  width:a?40:0,height:a?4:0,margin:const EdgeInsets.only(bottom:6),
                  decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(4))),
                Icon(a?items[i]['active'] as IconData:items[i]['icon'] as IconData,
                  color:Colors.black,size:24),
              ])));
          })))));
  }
}