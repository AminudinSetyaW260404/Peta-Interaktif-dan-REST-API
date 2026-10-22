import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/location_model.dart';
import '../services/api_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<LocationModel> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _isPickingPoint = false;
  LatLng? _tempPoint;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _determinePosition();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final locations = await _apiService.getLocations();
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data dari server';
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
  }

  void _startPickingPoint() {
    setState(() {
      _isPickingPoint = true;
      _tempPoint = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ketuk peta untuk memilih lokasi baru'),
      ),
    );
  }

  Future<void> _useGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak aktif')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _tempPoint = LatLng(position.latitude, position.longitude);
      _isPickingPoint = true;
    });
    _mapController.move(_tempPoint!, 16);
  }

  void _cancelPicking() {
    setState(() {
      _isPickingPoint = false;
      _tempPoint = null;
    });
  }

  Future<void> _showInputForm() async {
    if (_tempPoint == null) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tambah Tempat Kuliner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Tempat',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Deskripsi tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      final newLocation = LocationModel(
        id: '',
        name: nameController.text,
        description: descriptionController.text,
        latitude: _tempPoint!.latitude,
        longitude: _tempPoint!.longitude,
      );
      final success = await _apiService.addLocation(newLocation);
      if (success) {
        _loadLocations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tempat berhasil ditambahkan')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambahkan tempat')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isPickingPoint = false;
        _tempPoint = null;
      });
    }
  }

  void _showDetail(LocationModel location) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(location.description),
              const SizedBox(height: 8),
              Text(
                '${location.latitude}, ${location.longitude}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak aktif')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KulinerHunt'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-7.8000, 110.3800),
              initialZoom: 12,
              onTap: _isPickingPoint
                  ? (tapPosition, point) {
                      setState(() => _tempPoint = point);
                      _showInputForm();
                    }
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kulinerhunt.kulinerhunt',
              ),
              MarkerLayer(
                markers: [
                  ..._locations.map(
                    (location) => Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showDetail(location),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  if (_tempPoint != null)
                    Marker(
                      point: _tempPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.add_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 30,
                      height: 30,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors',
                      onTap: () {}),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadLocations,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_isPickingPoint)
            FloatingActionButton(
              heroTag: 'myLocation',
              onPressed: _goToMyLocation,
              tooltip: 'Lokasi Saya',
              child: const Icon(Icons.my_location),
            ),
          const SizedBox(height: 12),
          if (!_isPickingPoint)
            FloatingActionButton.extended(
              heroTag: 'add',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.gps_fixed),
                            title: const Text('Gunakan GPS'),
                            onTap: () {
                              Navigator.pop(context);
                              _useGps();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.map),
                            title: const Text('Pilih di Peta'),
                            onTap: () {
                              Navigator.pop(context);
                              _startPickingPoint();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          if (_isPickingPoint)
            FloatingActionButton.extended(
              heroTag: 'cancel',
              onPressed: _cancelPicking,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.close),
              label: const Text('Batal Pilih'),
            ),
        ],
      ),
    );
  }
}
