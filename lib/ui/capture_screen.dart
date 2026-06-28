import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
      cams.first,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'envoi — réessaie.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14110D),
      body: SafeArea(
        child: Column(
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
              ),
            ),
            Expanded(
              child: Center(
                child: _permError != null
                    ? _PermError(message: _permError!)
                    : _cam == null
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: _cam!.value.aspectRatio,
                        child: CameraPreview(_cam!),
                      ),
              ),
            ),
            const Text(
              'Cadre ta pinte, puis appuie pour la valider.',
              style: TextStyle(color: Colors.white70),
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
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
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
