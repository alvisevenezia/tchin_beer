import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/api_client.dart';
import '../state/submission_controller.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, required this.onSuccess});
  final void Function(int number) onSuccess;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _cam;
  String? _permError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _permError = 'Permission caméra refusée');
      return;
    }
    final cams = await availableCameras();
    final ctrl = CameraController(
      cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back),
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await ctrl.initialize();
    if (mounted) setState(() => _cam = ctrl);
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() => _busy = true);
    final shot = await cam.takePicture();
    final bytes = await shot.readAsBytes();
    await ref
        .read(submissionControllerProvider.notifier)
        .submit(bytes: bytes, filename: shot.name, contentType: 'image/jpeg');
    final state = ref.read(submissionControllerProvider);
    if (!mounted) return;
    if (state is Success) {
      widget.onSuccess(state.number);
    } else {
      setState(() => _busy = false);
      if (!mounted) return;
      final err = state is Failed ? state.error : null;
      final msg = switch (err) {
        ApiException(code: 'DUPLICATE_PHOTO') =>
          'Cette pinte a déjà été comptée ! 🍺',
        ApiException(code: 'RATE_LIMITED') =>
          'Attends un peu avant de poster une nouvelle pinte.',
        _ => 'Échec de l\'envoi — réessaie.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14110D),
      body: SafeArea(
        child: Column(
          children: [
            // Header : ✕ à gauche, titre centré en Stack
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Text(
                    'NOUVELLE PINTE',
                    style: TextStyle(
                      color: Color(0xFFFFCB6B),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _permError != null
                    ? _PermError(message: _permError!)
                    : _cam == null
                    ? const CircularProgressIndicator()
                    : _CameraWithViewfinder(cam: _cam!),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Cadre ta pinte, puis appuie pour la valider.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _cam == null ? null : _shoot,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _busy ? Colors.white54 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Preview caméra + overlay coins ──────────────────────────────────────

class _CameraWithViewfinder extends StatelessWidget {
  const _CameraWithViewfinder({required this.cam});
  final CameraController cam;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      AspectRatio(
        aspectRatio: cam.value.aspectRatio,
        child: CameraPreview(cam),
      ),
      const Positioned.fill(child: _ViewfinderCorners()),
    ],
  );
}

// ─── Quatre coins en équerre dorés (handoff) ─────────────────────────────

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Stack(
      children: [
        Positioned(top: 0, left: 0, child: _Corner()),
        Positioned(
          top: 0,
          right: 0,
          child: Transform.flip(flipX: true, child: _Corner()),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Transform.flip(flipY: true, child: _Corner()),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Transform.flip(flipX: true, flipY: true, child: _Corner()),
        ),
      ],
    ),
  );
}

class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 28, height: 28, child: CustomPaint(painter: _CornerPainter()));
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFCB6B)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _PermError extends StatelessWidget {
  const _PermError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(message, style: const TextStyle(color: Colors.white)),
      TextButton(
        onPressed: openAppSettings,
        child: const Text('Ouvrir les réglages'),
      ),
    ],
  );
}
