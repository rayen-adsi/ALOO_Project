// lib/screens/map_screen.dart
//
// Map tab — two modes:
//   1. SETUP mode  (first launch or "change location")
//      → draggable pin, confirm button, GPS shortcut
//   2. EXPLORE mode (location saved)
//      → provider pins nearby, category filter chips
//      → "Change my location" button + fullscreen button
//
// IMPORTANT: MapScreen does NOT have its own Scaffold.
// It is placed inside home_screen's IndexedStack so the bottom nav
// always stays visible. Only the fullscreen route (_FullscreenMap)
// has its own Scaffold with a close button.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'provider_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Category meta ────────────────────────────────────────────────────────────

const Map<String, _CatMeta> _catMeta = {
  'Plombier':            _CatMeta(icon: '🔧', color: Color(0xFF2A5298)),
  'Electricien':         _CatMeta(icon: '⚡', color: Color(0xFFF59E0B)),
  'Mecanicien':          _CatMeta(icon: '🚗', color: Color(0xFF6D28D9)),
  'Femme de menage':     _CatMeta(icon: '🏠', color: Color(0xFF10B981)),
  'Professeur':          _CatMeta(icon: '📚', color: Color(0xFF0D9488)),
  'Developpeur':         _CatMeta(icon: '💻', color: Color(0xFF1A3A6B)),
  'Reparation domicile': _CatMeta(icon: '🔨', color: Color(0xFFEF4444)),
};

class _CatMeta {
  final String icon;
  final Color  color;
  const _CatMeta({required this.icon, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// MapScreen — NO Scaffold, lives inside home_screen's IndexedStack tab
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  /// If true, forces setup mode regardless of saved location.
  /// Used only by _MapSetupWrapper on first launch.
  final bool forceSetup;

  /// Called after the user confirms their pin during first-launch setup.
  /// When null (normal tab usage) the screen just switches to explore mode
  /// after confirming — it does NOT navigate away.
  final VoidCallback? onConfirmed;

  const MapScreen({super.key, this.forceSetup = false, this.onConfirmed});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final _mapCtrl = MapController();

  bool   _setupMode        = true;
  bool   _loadingGps       = true;
  bool   _saving           = false;
  bool   _loadingProviders = false;

  LatLng _pin         = const LatLng(33.8815, 10.0982); // Sfax default
  String _cityName    = '';
  String _reverseCity = '';

  int    _userId   = 0;
  String _userType = 'client';

  List<Map<String, dynamic>> _providers        = [];
  String?                    _selectedCategory;
  Map<String, dynamic>?      _selectedProvider;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await UserSession.load();
    _userId   = session['id']   ?? 0;
    _userType = session['role'] ?? 'client';

    if (_userId == 0) { setState(() => _loadingGps = false); return; }

    if (!widget.forceSetup) {
      // ① Check local storage FIRST — populated by app_start on every login.
      //    This avoids any network dependency for the location check and makes
      //    explore mode load instantly after reconnect.
      if (session['location_set'] == true) {
        final lat = (session['lat'] as num?)?.toDouble();
        final lng = (session['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _pin      = LatLng(lat, lng);
          _cityName = session['city'] as String? ?? '';
          setState(() { _setupMode = false; _loadingGps = false; });
          _loadProviders();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapCtrl.move(_pin, 13);
          });
          return;
        }
      }

      // ② Fallback: try the API (handles first-time install or cache miss).
      //    If it succeeds, also cache the result locally for next time.
      try {
        final loc = await ApiService.getLocation(
            userId: _userId, userType: _userType);
        if (loc != null && loc['location_set'] == true) {
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _pin      = LatLng(lat, lng);
            _cityName = loc['city'] ?? '';
            // Cache to local storage so next open is instant
            await UserSession.saveLocation(
                lat: lat, lng: lng, city: _cityName);
            setState(() { _setupMode = false; _loadingGps = false; });
            _loadProviders();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapCtrl.move(_pin, 13);
            });
            return;
          }
        }
      } catch (_) {}
    }

    _getGps();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _getGps() async {
    setState(() => _loadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() { _setupMode = true; _loadingGps = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _pin = LatLng(pos.latitude, pos.longitude);
      await _reverseGeocode(_pin);
      setState(() { _setupMode = true; _loadingGps = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(_pin, 14);
      });
    } catch (_) {
      setState(() { _setupMode = true; _loadingGps = false; });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p  = marks.first;
        _reverseCity = p.locality ??
            p.subAdministrativeArea ??
            p.administrativeArea ?? '';
      }
    } catch (_) {}
  }

  // ── Confirm location ──────────────────────────────────────────────────────

  Future<void> _confirmLocation() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _saving = true);

    // Reverse geocode with a 4-second timeout — if it fails, continue anyway
    try {
      await _reverseGeocode(_pin).timeout(const Duration(seconds: 4));
    } catch (_) {}

    final city = _reverseCity.isNotEmpty ? _reverseCity : _cityName;

    // Try to save to backend
    bool synced = false;
    try {
      final res = await ApiService.updateLocation(
        userId:   _userId,
        userType: _userType,
        lat:      _pin.latitude,
        lng:      _pin.longitude,
        city:     city,
      ).timeout(const Duration(seconds: 8));
      synced = res['success'] == true;
    } catch (_) {
      synced = false;
    }

    // Always save locally
    try {
      await UserSession.saveLocation(
          lat: _pin.latitude, lng: _pin.longitude, city: city);
    } catch (_) {}

    if (!mounted) return;

    // Provide feedback
    if (synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.t('location_synced') ?? 'Location synced to database'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.t('location_offline') ?? 'Saved to phone (Offline/Sync failed)'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }

    if (!mounted) return;

    if (widget.onConfirmed != null) {
      // First-launch wrapper: navigate to home
      widget.onConfirmed!.call();
    } else {
      // Normal tab: switch to explore mode
      setState(() {
        _setupMode = false;
        _saving    = false;
        _cityName  = city;
      });
      _loadProviders();
    }
  }

  // ── Load providers ────────────────────────────────────────────────────────

  Future<void> _loadProviders() async {
    setState(() => _loadingProviders = true);
    try {
      final results = await ApiService.searchProviders(
        lat:      _pin.latitude,
        lng:      _pin.longitude,
        radius:   5.0,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() { _providers = results; _loadingProviders = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD — returns a Stack, no Scaffold
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();

    return Stack(children: [

      // ── Map ───────────────────────────────────────────────────────────────
      _buildMap(),

      // ── GPS loading ───────────────────────────────────────────────────────
      if (_loadingGps)
        Container(
          color: Colors.white,
          child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Color(0xFF2A5298), strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text(lang.t('map_locating'),
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A3A6B))),
            ],
          )),
        ),

      // ── Setup mode ────────────────────────────────────────────────────────
      if (!_loadingGps && _setupMode) ...[
        _buildSetupTopBar(lang),
        _buildSetupBottomSheet(lang),
      ],

      // ── Explore mode ──────────────────────────────────────────────────────
      if (!_loadingGps && !_setupMode) ...[
        _buildExploreTopBar(lang),
        _buildCategoryFilter(lang),
        if (_selectedProvider != null) _buildProviderPopup(lang),
        _buildChangeLocationBtn(lang),
        _buildFullscreenBtn(),
      ],
    ]);
  }

  // ── Map flutter_map widget ────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _pin,
        initialZoom:   13.0,
        onTap: _setupMode
            ? (_, point) => setState(() { _pin = point; _reverseCity = ''; })
            : (_, __) => setState(() => _selectedProvider = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aloo.app',
        ),
        if (!_setupMode) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: _pin,
                color: const Color(0xFF2A5298).withOpacity(0.15),
                borderColor: const Color(0xFF2A5298).withOpacity(0.6),
                borderStrokeWidth: 3.5,
                useRadiusInMeter: true,
                radius: 5000, // 5 km in meters
              )
            ],
          ),
          MarkerLayer(markers: _buildProviderMarkers()),
        ],
        MarkerLayer(markers: [
          Marker(
            point: _pin, width: 56, height: 68,
            child: _buildHomePin()),
        ]),
      ],
    );
  }

  Widget _buildHomePin() => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color:  const Color(0xFF1A3A6B),
        shape:  BoxShape.circle,
        boxShadow: [BoxShadow(
          color: const Color(0xFF1A3A6B).withOpacity(0.4),
          blurRadius: 12, offset: const Offset(0, 4))]),
      child: const Icon(Icons.home_rounded, color: Colors.white, size: 22)),
    const SizedBox(height: 2),
    Container(width: 2, height: 10, color: const Color(0xFF1A3A6B)),
  ]);

  List<Marker> _buildProviderMarkers() {
    return _providers
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) {
      final cat        = p['category'] as String? ?? '';
      final meta       = _catMeta[cat] ??
          const _CatMeta(icon: '👤', color: Color(0xFF2A5298));
      final isSelected = _selectedProvider?['id'] == p['id'];
      return Marker(
        point: LatLng(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
        width:  isSelected ? 52 : 44,
        height: isSelected ? 64 : 54,
        child: GestureDetector(
          onTap: () => setState(() => _selectedProvider = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width:  isSelected ? 44 : 38,
                height: isSelected ? 44 : 38,
                decoration: BoxDecoration(
                  color:  meta.color, shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white, width: isSelected ? 2.5 : 1.5),
                  boxShadow: [BoxShadow(
                    color: meta.color.withOpacity(0.45),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 3))]),
                child: Center(child: Text(meta.icon,
                    style: TextStyle(fontSize: isSelected ? 20 : 17)))),
              Container(width: 2, height: 8, color: meta.color),
            ]),
          ),
        ),
      );
    }).toList();
  }

  // ── Setup top bar ─────────────────────────────────────────────────────────

  Widget _buildSetupTopBar(LanguageProvider lang) => Positioned(
    top: 0, left: 0, right: 0,
    child: SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A6B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on_rounded,
                color: Color(0xFF1A3A6B), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('map_set_location'),
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
              Text(lang.t('map_drag_pin'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
          // GPS shortcut button
          GestureDetector(
            onTap: _getGps,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF0D9488), size: 20))),
        ]),
      ),
    ),
  );

  // ── Setup bottom confirm sheet ────────────────────────────────────────────

  Widget _buildSetupBottomSheet(LanguageProvider lang) => Positioned(
    bottom: 0, left: 0, right: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 24, offset: Offset(0, -6))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Location info row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A6B).withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF1A3A6B).withOpacity(0.12))),
          child: Row(children: [
            const Icon(Icons.pin_drop_rounded,
                color: Color(0xFF1A3A6B), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reverseCity.isNotEmpty
                      ? _reverseCity
                      : lang.t('map_pin_location'),
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
                Text(
                  '${_pin.latitude.toStringAsFixed(5)}, '
                  '${_pin.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              ])),
          ])),
        const SizedBox(height: 16),

        // Confirm button
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirmLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A6B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(lang.t('map_confirm_location'),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    ]))),
      ]),
    ),
  );

  // ── Explore top bar ───────────────────────────────────────────────────────

  Widget _buildExploreTopBar(LanguageProvider lang) => Positioned(
    top: 0, left: 0, right: 0,
    child: SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 64, 0),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A6B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_city_rounded,
                color: Color(0xFF1A3A6B), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_cityName.isNotEmpty
                  ? _cityName : lang.t('map_your_area'),
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
              Text('${_providers.length} ${lang.t('map_providers_nearby')}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
            ])),
          if (_loadingProviders)
            const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF2A5298))),
        ]),
      ),
    ),
  );

  // ── Category filter chips ─────────────────────────────────────────────────

  Widget _buildCategoryFilter(LanguageProvider lang) {
    final cats = ['Plombier','Electricien','Mecanicien',
                  'Femme de menage','Professeur',
                  'Developpeur','Reparation domicile'];
    return Positioned(
      top: 92, left: 0, right: 0,
      child: SafeArea(
        child: SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cats.length + 1,
            itemBuilder: (_, i) {
              final isAll      = i == 0;
              final cat        = isAll ? null : cats[i - 1];
              final isSelected = _selectedCategory == cat;
              final meta       = cat != null ? _catMeta[cat] : null;
              final color      = meta?.color ?? const Color(0xFF1A3A6B);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedProvider = null;
                  });
                  _loadProviders();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (meta != null) ...[
                      Text(meta.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Text(isAll ? lang.t('filter_all') : cat!,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white : const Color(0xFF1A3A6B))),
                  ])),
              );
            }),
        ),
      ),
    );
  }

  // ── Provider popup card ───────────────────────────────────────────────────

  Future<void> _launchDirections(double lat, double lng) async {
    // 1. Try geo scheme (most universal for map apps)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    // 2. Try Google Maps specific scheme
    final googleUri = Uri.parse('google.navigation:q=$lat,$lng');
    // 3. Fallback to HTTPS
    final httpsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleUri)) {
        await launchUrl(googleUri);
      } else if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else if (await canLaunchUrl(httpsUri)) {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')));
      }
    }
  }

  Widget _buildProviderPopup(LanguageProvider lang) {
    final p    = _selectedProvider!;
    final cat  = p['category'] as String? ?? '';
    final meta = _catMeta[cat] ??
        const _CatMeta(icon: '👤', color: Color(0xFF2A5298));
    final dist = p['distance_km'];

    return Positioned(
      bottom: 24, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 20, offset: const Offset(0, 6))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        meta.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
              child: p['profile_photo'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(p['profile_photo'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                              child: Text(meta.icon,
                                  style: const TextStyle(fontSize: 24)))))
                  : Center(child: Text(meta.icon,
                      style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['full_name'] ?? '',
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        meta.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(cat, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: meta.color))),
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFBBF24), size: 14),
                  const SizedBox(width: 2),
                  Text((p['rating'] as num? ?? 0).toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3A6B))),
                ]),
                if (dist != null) ...[
                   const SizedBox(height: 3),
                   Row(children: [
                     Icon(Icons.near_me_rounded,
                         color: Colors.grey.shade400, size: 12),
                     const SizedBox(width: 4),
                     Text('$dist km',
                       style: TextStyle(fontSize: 11,
                           color: Colors.grey.shade500,
                           fontWeight: FontWeight.w500)),
                   ]),
                ],
              ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _popupBtn(
              label: lang.t('view_profile') ?? 'View Profile',
              icon:  Icons.person_search_rounded,
              color: const Color(0xFF1A3A6B),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                  ProviderProfileScreen(providerId: p['id'] as int))),
            )),
            const SizedBox(width: 12),
            Expanded(child: _popupBtn(
              label: lang.t('map_get_directions') ?? 'Get Directions',
              icon:  Icons.directions_rounded,
              color: const Color(0xFF10B981),
              onTap: () => _launchDirections(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble()),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _popupBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );

  // ── Change location button ────────────────────────────────────────────────

  Widget _buildChangeLocationBtn(LanguageProvider lang) {
    if (_selectedProvider != null) return const SizedBox.shrink();
    return Positioned(
      bottom: 24,
      left: 16,
      child: GestureDetector(
        onTap: () {
          setState(() { _setupMode = true; _selectedProvider = null; });
          _getGps();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.edit_location_alt_rounded,
                color: Color(0xFF1A3A6B), size: 18),
            const SizedBox(width: 6),
            Text(lang.t('map_change_location'),
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
          ])),
      ),
    );
  }

  // ── Fullscreen button ─────────────────────────────────────────────────────

  Widget _buildFullscreenBtn() => Positioned(
    top: 0, right: 0,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 16),
        child: GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _FullscreenMap(
                pin:       _pin,
                cityName:  _cityName,
                providers: _providers,
                selectedCategory: _selectedCategory,
                onCategoryChange: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedProvider = null;
                  });
                  _loadProviders();
                },
              ),
            ),
          ),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 2))]),
            child: const Icon(Icons.fullscreen_rounded,
                color: Color(0xFF1A3A6B), size: 24))),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _FullscreenMap — full-screen route with its own Scaffold + close button
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenMap extends StatefulWidget {
  final LatLng                     pin;
  final String                     cityName;
  final List<Map<String, dynamic>> providers;
  final String?                    selectedCategory;
  final ValueChanged<String?>      onCategoryChange;

  const _FullscreenMap({
    required this.pin,
    required this.cityName,
    required this.providers,
    required this.selectedCategory,
    required this.onCategoryChange,
  });

  @override
  State<_FullscreenMap> createState() => _FullscreenMapState();
}

class _FullscreenMapState extends State<_FullscreenMap> {
  final _mapCtrl = MapController();
  late List<Map<String, dynamic>> _providers;
  late String?                    _selectedCategory;
  Map<String, dynamic>?           _selectedProvider;

  @override
  void initState() {
    super.initState();
    _providers        = widget.providers;
    _selectedCategory = widget.selectedCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapCtrl.move(widget.pin, 13);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final cats = ['Plombier','Electricien','Mecanicien',
                  'Femme de menage','Professeur',
                  'Developpeur','Reparation domicile'];

    return Scaffold(
      body: Stack(children: [

        // Map
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: widget.pin,
            initialZoom:   13.0,
            onTap: (_, __) => setState(() => _selectedProvider = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aloo.app',
            ),
            MarkerLayer(markers: _buildMarkers()),
            // Home pin
            MarkerLayer(markers: [
              Marker(
                point: widget.pin, width: 56, height: 68,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color:  const Color(0xFF1A3A6B),
                      shape:  BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF1A3A6B).withOpacity(0.4),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Icon(Icons.home_rounded,
                        color: Colors.white, size: 22)),
                  const SizedBox(height: 2),
                  Container(width: 2, height: 10,
                      color: const Color(0xFF1A3A6B)),
                ]),
              ),
            ]),
          ],
        ),

        // Top bar with EXIT button
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16, offset: const Offset(0, 4))]),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A6B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_city_rounded,
                      color: Color(0xFF1A3A6B), size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  widget.cityName.isNotEmpty
                      ? widget.cityName : lang.t('map_your_area'),
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A3A6B)))),
                // Exit fullscreen
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A6B),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.fullscreen_exit_rounded,
                        color: Colors.white, size: 20))),
              ]),
            ),
          ),
        ),

        // Category chips
        Positioned(
          top: 92, left: 0, right: 0,
          child: SafeArea(
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cats.length + 1,
                itemBuilder: (_, i) {
                  final isAll      = i == 0;
                  final cat        = isAll ? null : cats[i - 1];
                  final isSelected = _selectedCategory == cat;
                  final meta       = cat != null ? _catMeta[cat] : null;
                  final color      = meta?.color ?? const Color(0xFF1A3A6B);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _selectedProvider = null;
                      });
                      widget.onCategoryChange(cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (meta != null) ...[
                          Text(meta.icon,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                        ],
                        Text(isAll ? lang.t('filter_all') : cat!,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white : const Color(0xFF1A3A6B))),
                      ])),
                  );
                }),
            ),
          ),
        ),

        // Provider popup
        if (_selectedProvider != null)
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProviderProfileScreen(
                    providerId: _selectedProvider!['id'] as int))),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 20, offset: const Offset(0, 6))]),
                child: _buildPopupContent(_selectedProvider!)),
            ),
          ),
      ]),
    );
  }

  List<Marker> _buildMarkers() {
    return _providers
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) {
      final cat        = p['category'] as String? ?? '';
      final meta       = _catMeta[cat] ??
          const _CatMeta(icon: '👤', color: Color(0xFF2A5298));
      final isSelected = _selectedProvider?['id'] == p['id'];
      return Marker(
        point: LatLng(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
        width:  isSelected ? 52 : 44,
        height: isSelected ? 64 : 54,
        child: GestureDetector(
          onTap: () => setState(() => _selectedProvider = p),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width:  isSelected ? 44 : 38,
              height: isSelected ? 44 : 38,
              decoration: BoxDecoration(
                color:  meta.color, shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white, width: isSelected ? 2.5 : 1.5),
                boxShadow: [BoxShadow(
                  color: meta.color.withOpacity(0.45),
                  blurRadius: isSelected ? 14 : 8,
                  offset: const Offset(0, 3))]),
              child: Center(child: Text(meta.icon,
                  style: TextStyle(fontSize: isSelected ? 20 : 17)))),
            Container(width: 2, height: 8, color: meta.color),
          ]),
        ),
      );
    }).toList();
  }

  Widget _buildPopupContent(Map<String, dynamic> p) {
    final cat  = p['category'] as String? ?? '';
    final meta = _catMeta[cat] ??
        const _CatMeta(icon: '👤', color: Color(0xFF2A5298));
    final dist = p['distance_km'];

    return Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color:        meta.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14)),
        child: p['profile_photo'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(p['profile_photo'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(meta.icon,
                            style: const TextStyle(fontSize: 24)))))
            : Center(child: Text(meta.icon,
                style: const TextStyle(fontSize: 24)))),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p['full_name'] ?? '',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        meta.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Text(cat, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: meta.color))),
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded,
                color: Color(0xFFFBBF24), size: 14),
            const SizedBox(width: 2),
            Text((p['rating'] as num? ?? 0).toStringAsFixed(1),
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
          ]),
          if (dist != null) ...[
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.near_me_rounded,
                  color: Colors.grey.shade400, size: 12),
              const SizedBox(width: 4),
              Text('$dist km',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
            ]),
          ],
        ])),
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)]),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.arrow_forward_ios_rounded,
            color: Colors.white, size: 14)),
    ]);
  }
}