import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera bulunamadı')),
          );
          Navigator.pop(context);
        }
        return;
      }

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Kamera başlatma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera başlatılamadı: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    });

    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Fotoğrafı çek
      final XFile imageFile = await _controller!.takePicture();

      // Görüntüyü oku
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Görüntü decode edilemedi');
      }

      // Kamera preview boyutlarını al
      final Size previewSize = _controller!.value.previewSize!;
      final double screenWidth = MediaQuery.of(context).size.width;
      final double screenHeight = MediaQuery.of(context).size.height;

      // Dikdörtgen çerçeve boyutları (ekranın %80'i genişlik, %50'si yükseklik)
      final double frameWidth = screenWidth * 0.8;
      final double frameHeight = screenHeight * 0.5;

      // Çerçevenin ekrandaki konumu (merkezde)
      final double frameLeft = (screenWidth - frameWidth) / 2;
      final double frameTop = (screenHeight - frameHeight) / 2;

      // Preview aspect ratio
      final double previewAspectRatio = previewSize.width / previewSize.height;
      final double screenAspectRatio = screenWidth / screenHeight;

      double scaleX, scaleY;
      double offsetX = 0, offsetY = 0;

      // Ekran dolu olacak şekilde ölçeklendirme hesapla
      if (previewAspectRatio > screenAspectRatio) {
        // Preview daha geniş - yüksekliğe göre ölçekle
        scaleY = image.height / screenHeight;
        scaleX = scaleY;
        offsetX = (image.width - (screenWidth * scaleX)) / 2;
      } else {
        // Preview daha dar - genişliğe göre ölçekle
        scaleX = image.width / screenWidth;
        scaleY = scaleX;
        offsetY = (image.height - (screenHeight * scaleY)) / 2;
      }

      // Kırpma koordinatlarını hesapla (orijinal görüntü koordinatlarında)
      final int cropX = ((frameLeft * scaleX) + offsetX).round().clamp(0, image.width);
      final int cropY = ((frameTop * scaleY) + offsetY).round().clamp(0, image.height);
      final int cropWidth = (frameWidth * scaleX).round().clamp(1, image.width - cropX);
      final int cropHeight = (frameHeight * scaleY).round().clamp(1, image.height - cropY);

      // Görüntüyü kırp
      img.Image croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Geçici dosya oluştur
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File croppedFile = File(filePath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      // Kırpılmış görüntüyü geri döndür
      if (mounted) {
        Navigator.pop(context, croppedFile.path);
      }
    } catch (e) {
      debugPrint('Fotoğraf çekme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf çekilemedi: $e')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera önizlemesi
          Center(
            child: CameraPreview(_controller!),
          ),

          // Overlay (karanlık bölgeler + dikdörtgen çerçeve)
          CustomPaint(
            painter: _OverlayPainter(
              color: Colors.black.withOpacity(0.6),
              frameColor: theme.colorScheme.primary,
            ),
          ),

          // Üst bar (flash ve kapat butonları)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Kapat butonu
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                  ),
                ),

                // Flash butonu
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                    color: Colors.white,
                    size: 30,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          // Orta kısım - yardım metni
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25 - 60,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Soruyu çerçeve içine hizalayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alt bar - çekim butonu
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessing ? null : _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing
                            ? Colors.grey
                            : theme.colorScheme.primary,
                      ),
                      child: _isProcessing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay çizici - ortada dikdörtgen açık alan, etrafı karanlık
class _OverlayPainter extends CustomPainter {
  final Color color;
  final Color frameColor;

  _OverlayPainter({required this.color, required this.frameColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    // Dikdörtgen çerçeve boyutları
    final double frameWidth = size.width * 0.8;
    final double frameHeight = size.height * 0.5;
    final double frameLeft = (size.width - frameWidth) / 2;
    final double frameTop = (size.height - frameHeight) / 2;

    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight);

    // Tüm ekranı kaplayan path
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Dikdörtgen deliği aç
    path.addRect(frameRect);
    path.fillType = PathFillType.evenOdd;

    // Karanlık overlay'i çiz
    canvas.drawPath(path, paint);

    // Çerçeve kenarlığı çiz
    final framePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(frameRect, framePaint);

    // Köşelerde vurgu çizgileri (opsiyonel, daha şık görünüm için)
    final cornerPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Sol üst
    canvas.drawLine(
      Offset(frameLeft, frameTop),
      Offset(frameLeft + cornerLength, frameTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft, frameTop),
      Offset(frameLeft, frameTop + cornerLength),
      cornerPaint,
    );

    // Sağ üst
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop),
      Offset(frameLeft + frameWidth - cornerLength, frameTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop),
      Offset(frameLeft + frameWidth, frameTop + cornerLength),
      cornerPaint,
    );

    // Sol alt
    canvas.drawLine(
      Offset(frameLeft, frameTop + frameHeight),
      Offset(frameLeft + cornerLength, frameTop + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft, frameTop + frameHeight),
      Offset(frameLeft, frameTop + frameHeight - cornerLength),
      cornerPaint,
    );

    // Sağ alt
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + frameHeight),
      Offset(frameLeft + frameWidth - cornerLength, frameTop + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + frameHeight),
      Offset(frameLeft + frameWidth, frameTop + frameHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

