import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

const animationDelay = Duration(milliseconds: 800);
const animationDuration = Duration(milliseconds: 300);

enum AnimationState { success, error, none }

class RfidScanner extends StatefulWidget {
  const RfidScanner({
    super.key,
    required this.onDetect,
    required this.onError,
    required this.isEnabledNotifier, // Accept ValueNotifier from outside
  });

  final bool Function(String) onDetect;
  final Function(String) onError;
  final ValueNotifier<bool> isEnabledNotifier;

  @override
  State<RfidScanner> createState() => _RfidScannerState();
}

class _RfidScannerState extends State<RfidScanner> {
  AnimationState animationState = AnimationState.none;
  double animationOpacity = 0.0;
  bool isAnimating = false;
  Timer? delayTimer;
  Timer? animationTimer;

  StreamSubscription<NFCTag>? subscription;

  @override
  void initState() {
    super.initState();

    // Listen to changes in isEnabledNotifier
    widget.isEnabledNotifier.addListener(_handleEnabledChange);

    // Start NFC stream if enabled initially
    if (widget.isEnabledNotifier.value) {
      _startNfcStream();
    }
  }

  void _handleEnabledChange() {
    if (widget.isEnabledNotifier.value) {
      _startNfcStream();
    } else {
      _stopNfcStream();
    }
  }

  void _startNfcStream() {
    subscription ??= FlutterNfcKit.tagStream.listen(
      (tag) {
        final isSuccess = widget.onDetect(tag.id);
        final state = isSuccess ? AnimationState.success : AnimationState.error;

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
      },
      onError: (error) {
        widget.onError(error);
      },
    );
  }

  void _stopNfcStream() {
    subscription?.cancel();
    subscription = null;
  }

  @override
  void dispose() {
    delayTimer?.cancel();
    animationTimer?.cancel();
    _stopNfcStream();

    widget.isEnabledNotifier.removeListener(_handleEnabledChange);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isEnabledNotifier,
      builder: (context, enabled, child) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.nfc,
                        size: 80,
                        color:
                            enabled
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        enabled
                            ? 'Hold your NFC tag near the device.\nThe NFC sensor is typically located at the back.'
                            : 'NFC scanning is disabled.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (animationState != AnimationState.none && enabled)
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
      },
    );
  }
}
