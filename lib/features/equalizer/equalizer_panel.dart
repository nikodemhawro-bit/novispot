import "package:flutter/material.dart";
import "package:miniaudio_player/miniaudio_player.dart";

import "../../services/music_player_service.dart";

class EqualizerPanel extends StatefulWidget {
  const EqualizerPanel({
    super.key,
    required this.musicPlayer,
    required this.polish,
    required this.textColor,
    required this.mutedColor,
    required this.surfaceColor,
    required this.dividerColor,
  });

  final MusicPlayerService musicPlayer;
  final bool polish;
  final Color textColor;
  final Color mutedColor;
  final Color surfaceColor;
  final Color dividerColor;

  @override
  State<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends State<EqualizerPanel> {
  static const frequencies = [
    "31 Hz",
    "63 Hz",
    "125 Hz",
    "250 Hz",
    "500 Hz",
    "1 kHz",
    "2 kHz",
    "4 kHz",
    "8 kHz",
    "16 kHz",
  ];

  late List<double> gains;
  String selectedPreset = "Flat";

  Map<String, Equalizer> get presets => {
    "Flat": Equalizer.flat,
    "Rock": Equalizer.rock,
    "Pop": Equalizer.pop,
    "Jazz": Equalizer.jazz,
    "Classical": Equalizer.classical,
    "Bass Boost": Equalizer.bassBoost,
  };

  @override
  void initState() {
    super.initState();
    gains = widget.musicPlayer.equalizer.toList();
  }

  Future<void> applyPreset(String name) async {
    final equalizer = presets[name];
    if (equalizer == null) return;

    setState(() {
      gains = equalizer.toList();
      selectedPreset = name;
    });
    await widget.musicPlayer.setEqualizer(equalizer);
  }

  void changeBand(int index, double value) {
    setState(() {
      gains[index] = value;
      selectedPreset = "Custom";
    });
    widget.musicPlayer.setEqualizerBand(index, value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.equalizer, color: widget.textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.polish ? "Korektor dźwięku" : "Equalizer",
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => applyPreset("Flat"),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(widget.polish ? "Resetuj" : "Reset"),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedPreset,
            decoration: InputDecoration(
              labelText: widget.polish ? "Preset dźwięku" : "Sound preset",
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            dropdownColor: widget.surfaceColor,
            items: [
              ...presets.keys.map(
                (name) => DropdownMenuItem(value: name, child: Text(name)),
              ),
              DropdownMenuItem(
                value: "Custom",
                child: Text(widget.polish ? "Własne ustawienia" : "Custom"),
              ),
            ],
            onChanged: (value) {
              if (value != null && value != "Custom") {
                applyPreset(value);
              }
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text("-24 dB", style: TextStyle(color: widget.mutedColor)),
              const Spacer(),
              Text("0 dB", style: TextStyle(color: widget.mutedColor)),
              const Spacer(),
              Text("+24 dB", style: TextStyle(color: widget.mutedColor)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(frequencies.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      frequencies[index],
                      style: TextStyle(color: widget.textColor, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: -24,
                      max: 24,
                      divisions: 96,
                      value: gains[index].clamp(-24.0, 24.0),
                      onChanged: (value) => changeBand(index, value),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      "${gains[index] >= 0 ? "+" : ""}${gains[index].toStringAsFixed(1)} dB",
                      textAlign: TextAlign.end,
                      style: TextStyle(color: widget.mutedColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
