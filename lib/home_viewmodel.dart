import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:uets_remote_app/main.dart';

const nextReadDelay = Duration(milliseconds: 500);
const port = 8888;

class HomeViewModel extends ChangeNotifier {
  WebSocket? _webSocket;

  String? _ipAddress;
  String? _scanned;
  String? _error;

  int? _nInside;

  String? get ipAddress => _ipAddress;
  String? get scanned => _scanned;
  String? get error => _error;

  int? get nInside => _nInside;

  Function(String)? onMessage;

  HomeViewModel() {
    _startNfcManager();
    _startServer();
  }

  _startNfcManager() {
    NfcManager.instance.startSession(
      onDiscovered: (rawTag) async {
        final tag = getTagId(rawTag);

        if (tag == null) {
          player.play(AssetSource('detected-error.mp3'));
          _setError("Unknown tag type");
          return;
        }

        setAndBroadcastTag(tag);

        player.play(AssetSource('detected-success.mp3'));
      },
      onError: (error) async {
        _setError("Error starting NFC session: $error");
      },
    );
  }

  Future<void> _startServer() async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _ipAddress = await NetworkInfo().getWifiIP();
      notifyListeners();

      await for (final request in server) {
        if (request.uri.path == '/ws') {
          _webSocket = await WebSocketTransformer.upgrade(request);

          _webSocket!.listen(
            (rawIncoming) {
              final incoming = jsonDecode(rawIncoming) as Map<String, dynamic>;

              if (incoming['Message'] != null) {
                final message = incoming['Message'] as String;
                if (onMessage != null) {
                  onMessage!(message);
                }
              } else if (incoming['Properties'] != null) {
                final properties =
                    incoming['Properties'] as Map<String, dynamic>;

                if (properties['NInside'] != null) {
                  _nInside = properties['NInside'] as int;
                }

                notifyListeners();
              } else {
                _setError("Unknown message format");
              }
            },
            onDone: () {
              _webSocket?.close();
              _webSocket = null;
            },
            onError: (error) {
              _setError("WebSocket error: $error");
            },
          );

          _webSocket!.add(jsonEncode({"RequestProperties": null}));
        }
      }
    } on Exception catch (e) {
      _setError("Error starting server: $e");
      _ipAddress = null;
      notifyListeners();
    }
  }

  void setAndBroadcastTag(String tag) {
    _scanned = tag;
    notifyListeners();

    if (tag.isEmpty) {
      return;
    }

    _webSocket?.add(jsonEncode({"Tag": tag}));
  }

  void setAndBroadcastCode(String code) {
    _scanned = code;
    notifyListeners();

    if (code.isEmpty) {
      return;
    }

    _webSocket?.add(jsonEncode({"Code": code}));
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

String? getTagId(NfcTag tag) {
  final ndef = Ndef.from(tag);

  if (ndef != null) {
    return ndef.additionalData['identifier']
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final ndefFormatable = NdefFormatable.from(tag);

  if (ndefFormatable != null) {
    return ndefFormatable.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final nfcA = NfcA.from(tag);

  if (nfcA != null) {
    return nfcA.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final nfcB = NfcB.from(tag);

  if (nfcB != null) {
    return nfcB.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final nfcF = NfcF.from(tag);

  if (nfcF != null) {
    return nfcF.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final nfcV = NfcV.from(tag);

  if (nfcV != null) {
    return nfcV.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final isoDep = IsoDep.from(tag);

  if (isoDep != null) {
    return isoDep.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final mifareUltralight = MifareUltralight.from(tag);

  if (mifareUltralight != null) {
    return mifareUltralight.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  final mifareClassic = MifareClassic.from(tag);

  if (mifareClassic != null) {
    return mifareClassic.identifier
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toString();
  }

  return null;
}
