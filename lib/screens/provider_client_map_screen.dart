// lib/screens/provider_client_map_screen.dart
//
// Provider's map tab — two modes:
//   1. SETUP mode  (first launch or "change location")
//      → draggable pin, confirm button, GPS shortcut
//   2. EXPLORE mode (location saved)
//      → provider's own location pin (home icon)
//      → client pins (accepted reservations only)
//      → "Change my location" button + refresh button
//
// No Scaffold — lives inside provider_home_screen's IndexedStack tab.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a client pin on the map
// ─────────────────────────────────────────────────────────────────────────────

class _ClientPin {
  final int     clientId;
  final String  clientName;
  final String? clientPhoto;
  final int     clientAvatar;
  final double  lat;
  final double  lng;
  final String  city;
  // reservation details
  final String  description;
  final String  date;
  final String  time;
  final String  status; // 'accepted'

  const _ClientPin({
    required this.clientId,
    required this.clientName,
    required this.clientPhoto,
    required this.clientAvatar,
    required this.lat,
    required this.lng,
    required this.city,
    required this.description,
    required this.date,
    required this.time,
    required this.status,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ProviderClientMapScreen — NO Scaffold, tab body only
// ─────────────────────────────────────────────────────────────────────────────

class ProviderClientMapScreen extends StatefulWidget {
  final int providerId;
  const ProviderClientMapScreen({super.key, required this.providerId});

  @override
  State<ProviderClientMapScreen> createState() =>
      _ProviderClientMapScreenState();
}

class _ProviderClientMapScreenState extends State<ProviderClientMapScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final _mapCtrl = MapController();

  // ── Loading / mode flags ──────────────────────────────────────────────────
  bool _loadingInit = true; // true while fetching own location + client pins
  bool _setupMode   = false; // true when in drag-pin-to-change-location mode
  bool _saving      = false; // true while saving location

  // ── Provider's own location ───────────────────────────────────────────────
  LatLng? _myLocation;   // null if not set yet
  String  _myCity   = '';

  // ── Setup-mode pin ────────────────────────────────────────────────────────
  LatLng _pin         = const LatLng(33.8815, 10.0982); // Sfax default
  String _reverseCity = '';

  // ── Client reservation pins ───────────────────────────────────────────────
  List<_ClientPin>       _pins     = [];
  _ClientPin?            _selected;

  // ── Fallback map center ───────────────────────────────────────────────────
  LatLng get _center => _myLocation ?? const LatLng(33.8815, 10.0982);

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ── Init: load own location + client pins ─────────────────────────────────

  Future<void> _init() async {
    setState(() { _loadingInit = true; _pins = []; _selected = null; _setupMode = false; });

    // ① Check local storage FIRST — populated by app_start on every login.
    //    Same pattern as the client map: no network dependency.
    final session = await UserSession.load();
    if (session['location_set'] == true) {
      final lat = (session['lat'] as num?)?.toDouble();
      final lng = (session['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _myLocation = LatLng(lat, lng);
        _myCity     = session['city'] as String? ?? '';
        _pin        = _myLocation!;
      }
    }

    // ② If local storage empty, try API as fallback
    if (_myLocation == null) {
      try {
        final loc = await ApiService.getLocation(
            userId: widget.providerId, userType: 'provider');
        if (loc != null && loc['location_set'] == true) {
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _myLocation = LatLng(lat, lng);
            _myCity     = loc['city'] as String? ?? '';
            _pin        = _myLocation!;
            // Cache to local storage so next open is instant
            await UserSession.saveLocation(
                lat: lat, lng: lng, city: _myCity);
          }
        }
      } catch (_) {}
    }

    // ③ No location anywhere → enter setup mode (same as client map)
    if (_myLocation == null) {
      if (!mounted) return;
      setState(() { _loadingInit = false; _setupMode = true; });
      _getGps(); // pre-position pin using device GPS
      return;
    }

    // ④ Location found → explore mode: load client reservation pins
    await _loadClientPins();

    if (!mounted) return;
    setState(() => _loadingInit = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapCtrl.move(_center, 12);
    });
  }

  // ── Load client pins only (used by refresh button too) ───────────────────

  Future<void> _loadClientPins() async {
    try {
      final resPins = await ApiService.getProviderReservationPins(widget.providerId);
      final pins = <_ClientPin>[];

      for (final p in resPins) {
        pins.add(_ClientPin(
          clientId:     p['client_id']      as int?    ?? 0,
          clientName:   p['client_name']    as String? ?? '',
          clientPhoto:  p['client_photo']   as String?,
          clientAvatar: p['client_avatar']  as int?    ?? 0,
          lat:          (p['lat']  as num?)?.toDouble() ?? 0.0,
          lng:          (p['lng']  as num?)?.toDouble() ?? 0.0,
          city:         p['city']           as String? ?? '',
          description:  p['description']    as String? ?? '',
          date:         p['date']           as String? ?? '',
          time:         p['time']           as String? ?? '',
          status:       'accepted',
        ));
      }

      if (mounted) setState(() => _pins = pins);
    } catch (_) {}
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _getGps() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _pin = LatLng(pos.latitude, pos.longitude);
      await _reverseGeocode(_pin);
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(_pin, 14);
      });
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final marks = await placemarkFromCoordinates(
          pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p  = marks.first;
        _reverseCity = p.locality ??
            p.subAdministrativeArea ??
            p.administrativeArea ?? '';
      }
    } catch (_) {}
  }

  // ── Confirm new location ──────────────────────────────────────────────────

  Future<void> _confirmLocation() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _saving = true);

    try {
      await _reverseGeocode(_pin).timeout(const Duration(seconds: 4));
    } catch (_) {}

    final city = _reverseCity.isNotEmpty ? _reverseCity : _myCity;

    // Try to save to backend
    bool synced = false;
    try {
      final res = await ApiService.updateLocation(
        userId:   widget.providerId,
        userType: 'provider',
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
    setState(() {
      _myLocation = _pin;
      _myCity     = city;
      _setupMode  = false;
      _saving     = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapCtrl.move(_myLocation!, 13);
    });
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

      // ── Loading overlay ───────────────────────────────────────────────────
      if (_loadingInit)
        Container(
          color: Colors.white,
          child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Color(0xFF2A5298), strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Chargement de la carte…',
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A3A6B))),
            ],
          )),
        ),

      // ── Setup mode ────────────────────────────────────────────────────────
      if (!_loadingInit && _setupMode) ...[
        _buildSetupTopBar(lang),
        _buildSetupBottomSheet(lang),
      ],

      // ── Explore mode ──────────────────────────────────────────────────────
      if (!_loadingInit && !_setupMode) ...[
        _buildTopBar(lang),
        if (_pins.isEmpty) _buildEmptyClientsNote(lang),
        if (_selected != null) _buildClientPopup(lang),
        _buildChangeLocationBtn(lang),
        _buildRefreshBtn(),
      ],
    ]);
  }

  // ── Map widget ────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _center,
        initialZoom:   12.0,
        onTap: _setupMode
            ? (_, point) => setState(() { _pin = point; _reverseCity = ''; })
            : (_, __) => setState(() => _selected = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aloo.app',
        ),
        // Client pins (explore mode only)
        if (!_setupMode) MarkerLayer(markers: _buildClientMarkers()),
        // Provider's own location pin (explore mode) OR draggable setup pin
        MarkerLayer(markers: [
          if (_setupMode)
            Marker(
              point: _pin, width: 56, height: 68,
              child: _buildHomePin(color: const Color(0xFF0D9488))),
          if (!_setupMode && _myLocation != null)
            Marker(
              point: _myLocation!, width: 56, height: 68,
              child: _buildHomePin(color: const Color(0xFF1A3A6B))),
        ]),
      ],
    );
  }

  Widget _buildHomePin({required Color color}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:  color,
            shape:  BoxShape.circle,
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 22)),
        const SizedBox(height: 2),
        Container(width: 2, height: 10, color: color),
      ]);

  // ── Client markers ────────────────────────────────────────────────────────

  List<Marker> _buildClientMarkers() {
    return _pins.map((pin) {
      final isSelected = _selected?.clientId == pin.clientId;
      return Marker(
        point: LatLng(pin.lat, pin.lng),
        width:  isSelected ? 56 : 48,
        height: isSelected ? 68 : 58,
        child: GestureDetector(
          onTap: () => setState(() => _selected = pin),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width:  isSelected ? 48 : 40,
                height: isSelected ? 48 : 40,
                decoration: BoxDecoration(
                  color:  const Color(0xFF10B981),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: Colors.white, width: isSelected ? 3 : 2),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.45),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 3))]),
                child: pin.clientPhoto != null
                    ? ClipOval(child: Image.network(
                        pin.clientPhoto!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _clientInitial(pin)))
                    : _clientInitial(pin),
              ),
              Container(width: 2.5, height: 10,
                  color: const Color(0xFF10B981)),
            ]),
          ),
        ),
      );
    }).toList();
  }

  Widget _clientInitial(_ClientPin pin) => Center(
    child: Text(
      pin.clientName.isNotEmpty ? pin.clientName[0].toUpperCase() : '?',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
          color: Colors.white)));

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
            child: const Icon(Icons.edit_location_alt_rounded,
                color: Color(0xFF1A3A6B), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Définir ma position',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
              Text('Faites glisser le marqueur',
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
          const SizedBox(width: 8),
          // Cancel button (if already has a location)
          if (_myLocation != null)
            GestureDetector(
              onTap: () => setState(() {
                _setupMode  = false;
                _pin        = _myLocation!;
                _reverseCity = '';
              }),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.red, size: 20))),
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
                      : 'Position du marqueur',
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
                      const Text('Confirmer ma position',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    ]))),
      ]),
    ),
  );

  // ── Explore top bar ───────────────────────────────────────────────────────

  Widget _buildTopBar(LanguageProvider lang) {
    return Positioned(
      top: 0, left: 0, right: 56, // leave room for refresh button
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16, offset: const Offset(0, 4))]),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A6B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.people_rounded,
                  color: Color(0xFF1A3A6B), size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myCity.isNotEmpty ? _myCity : 'Ma zone',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                Text('${_pins.length} client${_pins.length != 1 ? 's' : ''}'
                    ' avec réservation acceptée',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              ])),
          ]),
        ),
      ),
    );
  }

  // ── Empty clients note (shown as a small overlay, not blocking the map) ───

  Widget _buildEmptyClientsNote(LanguageProvider lang) {
    return Positioned(
      bottom: 100, left: 16, right: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A6B).withOpacity(0.07),
                shape: BoxShape.circle),
              child: const Icon(Icons.people_outline_rounded,
                  color: Color(0xFF1A3A6B), size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Text(
              'Aucun client avec réservation acceptée pour le moment.',
              style: TextStyle(fontSize: 13, color: Color(0xFF1A3A6B),
                  fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Change location button ────────────────────────────────────────────────

  Widget _buildChangeLocationBtn(LanguageProvider lang) => Positioned(
    bottom: _selected != null ? 200 : 24,
    left: 16,
    child: GestureDetector(
      onTap: () {
        _reverseCity = '';
        _pin = _myLocation ?? const LatLng(33.8815, 10.0982);
        setState(() { _setupMode = true; _selected = null; });
        // Move map to current pin so user can see where they're dragging from
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapCtrl.move(_pin, 13);
        });
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
          const Text('Changer ma position',
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
        ])),
    ),
  );

  // ── Refresh button (top right) ────────────────────────────────────────────

  Widget _buildRefreshBtn() => Positioned(
    top: 0, right: 0,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 16),
        child: GestureDetector(
          onTap: () async {
            setState(() => _selected = null);
            await _loadClientPins();
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 2))]),
            child: const Icon(Icons.refresh_rounded,
                color: Color(0xFF1A3A6B), size: 22)),
        ),
      ),
    ),
  );

  // ── Client popup card ─────────────────────────────────────────────────────

  Widget _buildClientPopup(LanguageProvider lang) {
    final p = _selected!;
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

          // Client row
          Row(children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color:  const Color(0xFF10B981).withOpacity(0.12),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    width: 2)),
              child: p.clientPhoto != null
                  ? ClipOval(child: Image.network(p.clientPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _clientInitialCircle(p)))
                  : _clientInitialCircle(p)),
            const SizedBox(width: 12),

            // Name + city
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.clientName,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                if (p.city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        color: Colors.grey.shade400, size: 13),
                    const SizedBox(width: 3),
                    Text(p.city,
                      style: TextStyle(fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  ]),
                ],
              ])),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        const Color(0xFF10B981).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Accepté',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981))),
              ])),
          ]),

          // Reservation details
          if (p.description.isNotEmpty || p.date.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A6B).withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1A3A6B).withOpacity(0.10))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.description.isNotEmpty)
                    Text(p.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                          color: Color(0xFF1A3A6B),
                          fontWeight: FontWeight.w600)),
                  if (p.date.isNotEmpty || p.time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        [if (p.date.isNotEmpty) p.date,
                         if (p.time.isNotEmpty) p.time].join(' • '),
                        style: TextStyle(fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ]),
            ),
          ],

          const SizedBox(height: 12),

          // Chat button
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                chatScreenRoute(
                  providerId:   widget.providerId,
                  providerName: '',
                  clientId:     p.clientId,
                  clientName:   p.clientName,
                )),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A6B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                'Envoyer un message à ${p.clientName.split(' ').first}',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            )),
        ]),
      ),
    );
  }

  Widget _clientInitialCircle(_ClientPin p) => Center(
    child: Text(
      p.clientName.isNotEmpty ? p.clientName[0].toUpperCase() : '?',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
          color: Color(0xFF10B981))));
}