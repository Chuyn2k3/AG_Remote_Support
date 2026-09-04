import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && UrlParser.isAntigravityUrl(rawValue)) {
        _isProcessing = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, rawValue);
        break;
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (UrlParser.isAntigravityUrl(text)) {
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.black87,
            content: Text(
              'Link trong clipboard không phải link Antigravity hợp lệ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = (size.width * 0.7).clamp(240.0, 300.0);
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: scanSize,
      height: scanSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Stream
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Apple Viewfinder Cutout Overlay
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow: scanWindow),
          ),

          // Top Controls (Close, Title, Flash, Switch Camera)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassCircleButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Quét mã QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Row(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            final isTorchOn = state.torchState == TorchState.on;
                            return _buildGlassCircleButton(
                              icon: isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              iconColor: isTorchOn ? AppColors.statusWarning : Colors.white,
                              onTap: () => _controller.toggleTorch(),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildGlassCircleButton(
                          icon: Icons.cameraswitch_rounded,
                          onTap: () => _controller.switchCamera(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Instruction & Manual Paste Button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36, left: 24, right: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hướng camera vào mã QR trên Antigravity Desktop',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text(
                            'Dán liên kết từ Clipboard',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: iconColor, size: 20),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double cornerRadius;
  final double cornerLength;

  ScannerOverlayPainter({
    required this.scanWindow,
    this.cornerRadius = 18.0,
    this.cornerLength = 26.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(cornerRadius)));

    // Semi-transparent dark background outside viewfinder
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw 4 Apple Viewfinder corner brackets
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = scanWindow.left;
    final top = scanWindow.top;
    final right = scanWindow.right;
    final bottom = scanWindow.bottom;
    final r = cornerRadius;
    final l = cornerLength;

    // Top-Left
    final tl = Path()
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..lineTo(left + l, top);
    canvas.drawPath(tl, cornerPaint);

    // Top-Right
    final tr = Path()
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, top + l);
    canvas.drawPath(tr, cornerPaint);

    // Bottom-Left
    final bl = Path()
      ..moveTo(left, bottom - l)
      ..lineTo(left, bottom - r)
      ..arcToPoint(Offset(left + r, bottom), radius: Radius.circular(r))
      ..lineTo(left + l, bottom);
    canvas.drawPath(bl, cornerPaint);

    // Bottom-Right
    final br = Path()
      ..moveTo(right - l, bottom)
      ..lineTo(right - r, bottom)
      ..arcToPoint(Offset(right, bottom - r), radius: Radius.circular(r))
      ..lineTo(right, bottom - l);
    canvas.drawPath(br, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
