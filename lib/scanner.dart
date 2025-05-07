import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const defaultIsTorchOn = false;
const detectionTimeoutMs = 500;

const animationDelay = Duration(milliseconds: 800);
const animationDuration = Duration(milliseconds: 300);

enum AnimationState { success, error, none }

class Scanner extends StatefulWidget {
  const Scanner({super.key, required this.onDetect});

  final Future<bool> Function(BarcodeCapture) onDetect;

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  final controller = MobileScannerController(
    detectionTimeoutMs: detectionTimeoutMs,
    torchEnabled: defaultIsTorchOn,
  );

  bool isTorchOn = defaultIsTorchOn;

  AnimationState animationState = AnimationState.none;
  double animationOpacity = 0.0;
  bool isAnimating = false;
  Timer? delayTimer;
  Timer? animationTimer;

  @override
  void initState() {
    super.initState();
    unawaited(controller.start());
  }

  @override
  Future<void> dispose() async {
    delayTimer?.cancel();
    delayTimer = null;

    animationTimer?.cancel();
    animationTimer = null;

    super.dispose();
    await controller.dispose();
  }

  Future<void> onDetect(BarcodeCapture barcode) async {
    final state =
        await widget.onDetect(barcode)
            ? AnimationState.success
            : AnimationState.error;

    if (isAnimating || animationState == state) {
      return;
    }

    setState(() {
      animationState = state;
      animationOpacity = 1.0;
      isAnimating = true;
    });

    delayTimer = Timer(animationDelay, () {
      delayTimer = null;

      setState(() {
        animationOpacity = 0.0;
      });

      animationTimer = Timer(animationDuration, () {
        animationTimer = null;

        setState(() {
          animationState = AnimationState.none;
          isAnimating = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 240,
        width: 240,
        child: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: onDetect),
            Positioned(
              bottom: 16,
              right: 16,
              child: IconButton.filled(
                icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () {
                  setState(() {
                    isTorchOn = !isTorchOn;
                  });
                  controller.toggleTorch();
                },
              ),
            ),
            if (animationState != AnimationState.none)
              AnimatedOpacity(
                duration: animationDuration,
                opacity: animationOpacity,
                child: Container(
                  color: Colors.black.withAlpha(128),
                  child: Center(
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color:
                            animationState == AnimationState.success
                                ? Colors.greenAccent
                                : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        animationState == AnimationState.success
                            ? Icons.check
                            : Icons.close,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
