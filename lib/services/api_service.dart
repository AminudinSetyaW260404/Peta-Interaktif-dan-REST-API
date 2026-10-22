import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_model.dart';

class ApiService {
  static const String baseUrl =
      'https://69089e042d902d0651b114ba.mockapi.io/api/v1/locations';

  Future<List<LocationModel>> getLocations() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => LocationModel.fromJson(item)).toList();
    } else {
      throw Exception('Gagal memuat data lokasi');
    }
  }

  Future<bool> addLocation(LocationModel model) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(model.toJson()),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
}
