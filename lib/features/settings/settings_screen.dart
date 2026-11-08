
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const SettingsScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final polish = language == 'pl';

    return Scaffold(
      appBar: AppBar(
        title: Text(polish ? 'Ustawienia' : 'Settings'),
        backgroundColor: const Color(0xFF151515),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text(
                polish ? 'Personalizacja' : 'Personalization',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                polish
                    ? 'Dostosuj Novispot do swoich potrzeb.'
                    : 'Customize Novispot to your needs.',
                style: const TextStyle(color: Color(0xFF999999)),
              ),
              const SizedBox(height: 35),
              Text(
                polish ? 'JĘZYK APLIKACJI' : 'APPLICATION LANGUAGE',
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: language,
                dropdownColor: const Color(0xFF222222),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.language),
                  filled: true,
                  fillColor: const Color(0xFF1B1B1B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'pl',
                    child: Text('Polski'),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('English'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onLanguageChanged(value);
                  }
                },
              ),
              const SizedBox(height: 35),
              const Divider(color: Color(0xFF303030)),
              const SizedBox(height: 28),
              Text(
                polish ? 'POŁĄCZENIE Z SERWEREM' : 'SERVER CONNECTION',
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                polish
                    ? 'Połączenie z Navidrome dodamy w kolejnym etapie.'
                    : 'Navidrome connection will be added in the next step.',
                style: const TextStyle(color: Color(0xFF999999)),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Novispot',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Text(
                    'NOVISPOT 1.0.0 (BETA)',
                    style: TextStyle(color: Color(0xFF777777)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


