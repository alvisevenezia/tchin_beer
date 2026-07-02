import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../theme/tokens.dart';

const kBigCities = [
  ('Paris', 48.8566, 2.3522),
  ('Marseille', 43.2965, 5.3698),
  ('Lyon', 45.7640, 4.8357),
  ('Toulouse', 43.6047, 1.4442),
  ('Nice', 43.7102, 7.2620),
  ('Nantes', 47.2184, -1.5536),
  ('Strasbourg', 48.5734, 7.7521),
  ('Montpellier', 43.6108, 3.8767),
  ('Bordeaux', 44.8378, -0.5792),
  ('Lille', 50.6292, 3.0573),
  ('Rennes', 48.1173, -1.6778),
  ('Reims', 49.2583, 4.0317),
  ('Saint-Étienne', 45.4397, 4.3872),
  ('Le Havre', 49.4938, 0.1077),
  ('Toulon', 43.1242, 5.9280),
  ('Grenoble', 45.1885, 5.7245),
  ('Dijon', 47.3220, 5.0415),
  ('Angers', 47.4784, -0.5632),
  ('Nîmes', 43.8367, 4.3601),
  ('Villeurbanne', 45.7667, 4.8797),
  ('Le Mans', 48.0061, 0.1996),
  ('Aix-en-Provence', 43.5297, 5.4474),
  ('Brest', 48.3904, -4.4861),
  ('Amiens', 49.8941, 2.2958),
  ('Clermont-Ferrand', 45.7772, 3.0870),
  ('Tours', 47.3941, 0.6848),
  ('Metz', 49.1193, 6.1757),
  ('Perpignan', 42.6976, 2.8946),
  ('Caen', 49.1829, -0.3707),
  ('Rouen', 49.4432, 1.0993),
  ('Limoges', 45.8336, 1.2611),
  ('Besançon', 47.2378, 6.0241),
  ('Orléans', 47.9030, 1.9039),
  ('Mulhouse', 47.7508, 7.3359),
  ('Nancy', 48.6921, 6.1844),
  ('Avignon', 43.9493, 4.8055),
  ('Poitiers', 46.5802, 0.3404),
  ('Pau', 43.2951, -0.3707),
  ('Calais', 50.9513, 1.8587),
  ('La Rochelle', 46.1591, -1.1520),
  ('Annecy', 45.8992, 6.1294),
  ('Dunkerque', 51.0343, 2.3767),
  ('Troyes', 48.2973, 4.0744),
  ('Lorient', 47.7487, -3.3760),
  ('Valence', 44.9334, 4.8924),
  ('Colmar', 48.0793, 7.3585),
  ('Bayonne', 43.4929, -1.4748),
  ('Ajaccio', 41.9190, 8.7388),
  ('Quimper', 47.9960, -4.0972),
  ('Versailles', 48.8014, 2.1301),
  ('Argenteuil', 48.9473, 2.2480),
  ('Montreuil', 48.8638, 2.4438),
  ('Boulogne-Billancourt', 48.8352, 2.2401),
  ('Cannes', 43.5528, 7.0174),
  ('Antibes', 43.5808, 7.1239),
];

/// Détecte la ville via GPS + Nominatim et ouvre le picker si nécessaire.
/// Retourne la ville choisie, ou null si annulé / erreur.
Future<String?> detectAndPickCity(BuildContext context) async {
  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
    return null;
  }

  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 10),
    ),
  );

  String? detectedCity;
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${pos.latitude}&lon=${pos.longitude}&format=json&accept-language=fr',
    );
    final resp = await http.get(uri, headers: {'User-Agent': 'tchin.beer/1.0'});
    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = j['address'] as Map<String, dynamic>?;
      detectedCity = addr?['city'] as String? ??
          addr?['town'] as String? ??
          addr?['village'] as String?;
    }
  } catch (_) {}

  if (!context.mounted) return null;

  final nearby = kBigCities
      .map((c) {
        final dist =
            Geolocator.distanceBetween(pos.latitude, pos.longitude, c.$2, c.$3) / 1000;
        return (c.$1, dist);
      })
      .where((c) => c.$2 < 30)
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));

  if (nearby.isEmpty) {
    return detectedCity;
  }
  if (nearby.length == 1 ||
      (detectedCity != null &&
          nearby.first.$1.toLowerCase() == detectedCity.toLowerCase())) {
    return nearby.first.$1;
  }

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTokens.foam,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => CityPickerSheet(detected: detectedCity, nearby: nearby),
  );
}

class CityPickerSheet extends StatelessWidget {
  const CityPickerSheet({super.key, required this.detected, required this.nearby});
  final String? detected;
  final List<(String, double)> nearby;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choisir ta ville',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 20, color: AppTokens.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Grandes villes proches (< 30 km)',
            style: TextStyle(
                color: AppTokens.muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (detected != null) ...[
            CityOption(
              name: detected!,
              subtitle: 'Localisation précise',
              onTap: () => Navigator.of(context).pop(detected),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppTokens.rail),
            const SizedBox(height: 10),
          ],
          ...nearby.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CityOption(
                  name: c.$1,
                  subtitle: '${c.$2.toStringAsFixed(0)} km',
                  onTap: () => Navigator.of(context).pop(c.$1),
                ),
              )),
        ],
      ),
    );
  }
}

class CityOption extends StatelessWidget {
  const CityOption(
      {super.key, required this.name, required this.subtitle, required this.onTap});
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTokens.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTokens.rail),
          ),
          child: Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTokens.ink)),
                    Text(subtitle,
                        style: const TextStyle(color: AppTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              const Text('›', style: TextStyle(color: AppTokens.muted, fontSize: 20)),
            ],
          ),
        ),
      );
}
