import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/call_model.dart';
import '../providers/call_controller.dart';
import '../services/calling_service.dart';

String phaseLabel(CallPhase phase) {
  return switch (phase) {
    CallPhase.idle => 'Idle',
    CallPhase.calling => 'Calling…',
    CallPhase.ringing => 'Ringing…',
    CallPhase.connected => 'Connected',
    CallPhase.inCall => 'In call',
    CallPhase.ended => 'Call ended',
    CallPhase.rejected => 'Call declined',
    CallPhase.missed => 'Missed call',
    CallPhase.cancelled => 'Call cancelled',
    CallPhase.busy => 'User busy',
    CallPhase.failed => 'Call failed',
    CallPhase.disconnected => 'Disconnected',
  };
}

class NetworkQualityChip extends StatelessWidget {
  const NetworkQualityChip({super.key, required this.quality});

  final NetworkQuality quality;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (quality) {
      NetworkQuality.good => ('Good', AppColors.online),
      NetworkQuality.fair => ('Fair', Colors.orange),
      NetworkQuality.poor => ('Poor', AppColors.decline),
      NetworkQuality.unknown => ('Network', AppColors.offline),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.signal_cellular_alt, size: 16, color: color),
      label: Text(label),
    );
  }
}

class CallControlBar extends StatelessWidget {
  const CallControlBar({
    super.key,
    required this.session,
    required this.video,
    required this.onMute,
    required this.onSpeaker,
    required this.onCamera,
    required this.onSwitchCamera,
    required this.onEnd,
  });

  final CallSession session;
  final bool video;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundControl(
          icon: session.muted ? Icons.mic_off : Icons.mic,
          label: session.muted ? 'Unmute' : 'Mute',
          selected: session.muted,
          onTap: onMute,
        ),
        if (!video)
          _RoundControl(
            icon: session.speakerOn ? Icons.volume_up : Icons.hearing,
            label: session.speakerOn ? 'Speaker' : 'Earpiece',
            selected: session.speakerOn,
            onTap: onSpeaker,
          ),
        if (video) ...[
          _RoundControl(
            icon: session.cameraOff ? Icons.videocam_off : Icons.videocam,
            label: session.cameraOff ? 'Camera off' : 'Camera',
            selected: session.cameraOff,
            onTap: onCamera,
          ),
          _RoundControl(
            icon: Icons.cameraswitch,
            label: 'Flip',
            onTap: onSwitchCamera,
          ),
        ],
        _RoundControl(
          icon: Icons.call_end,
          label: 'End',
          color: AppColors.decline,
          onTap: onEnd,
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ??
        (selected ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final fg = color != null
        ? Colors.white
        : selected
            ? Colors.black
            : Colors.white;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: bg,
            child: Icon(icon, color: fg),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
