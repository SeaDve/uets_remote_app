import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

const nextReadDelay = Duration(milliseconds: 500);
const port = 8888;

class EntityData {
  final String kind;
  final String? name;
  final String? possessor;
  final bool isInside;

  get isOutside => !isInside;

  get isPerson => kind == "Person";
  get isItem => kind == "Item";
  get isVehicle => kind == "Vehicle";

  EntityData({
    required this.kind,
    this.name,
    this.possessor,
    required this.isInside,
  });

  @override
  String toString() {
    return 'EntityData(kind: $kind, name: $name, possessor: $possessor, isInside: $isInside)';
  }
}

class HomeViewModel extends ChangeNotifier {
  WebSocket? _webSocket;

  bool _isConnected = false;
  String? _ipAddress;
  String? _scannedEntityId;
  String? _scannedPossessor;
  String? _error;

  bool _isAskingForPossessor = false;

  final Map<String, EntityData> _entities = {};

  bool get isConnected => _isConnected;
  String? get ipAddress => _ipAddress;
  String? get scannedEntityDisplay {
    final entityId = _scannedEntityId;

    if (entityId == null) {
      return null;
    }

    final entity = _entities[entityId];

    if (entity == null) {
      return entityId;
    } else {
      return '${entity.name} ($entityId)';
    }
  }

  String? get scannedPossessorDisplay {
    final possessor = _scannedPossessor;

    if (possessor == null) {
      return null;
    }

    final entity = _entities[possessor];

    if (entity == null) {
      return possessor;
    } else {
      return '${entity.name} ($possessor)';
    }
  }

  String? get error => _error;

  bool get isAskingForPossessor => _isAskingForPossessor;

  int get nPersons => _entities.values.where((e) => e.isPerson).length;
  int get nPersonsInside =>
      _entities.values.where((e) => e.isPerson && e.isInside).length;
  int get nItems => _entities.values.where((e) => e.isItem).length;
  int get nItemsInside =>
      _entities.values.where((e) => e.isItem && e.isInside).length;
  int get nVehicles => _entities.values.where((e) => e.isVehicle).length;
  int get nVehiclesInside =>
      _entities.values.where((e) => e.isVehicle && e.isInside).length;
  UnmodifiableMapView get entities => UnmodifiableMapView(_entities);

  Function(String)? onMessage;

  HomeViewModel() {
    _startServer();
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
              } else if (incoming['AllEntityData'] != null) {
                final allEntityData =
                    incoming['AllEntityData'] as Map<String, dynamic>;

                for (final entry in allEntityData.entries) {
                  final entityId = entry.key;
                  final entityData = entry.value as Map<String, dynamic>;

                  _entities[entityId] = EntityData(
                    kind: entityData['kind'] as String,
                    name: entityData['name'] as String?,
                    possessor: entityData['posessor'] as String?,
                    isInside: entityData['is_inside'] as bool,
                  );
                }

                notifyListeners();
              } else {
                setError("Unknown message format");
              }
            },
            onDone: () {
              _webSocket?.close();
              _webSocket = null;
              _isConnected = false;
            },
            onError: (error) {
              setError("WebSocket error: $error");
              _webSocket?.close();
              _webSocket = null;
              _isConnected = false;
            },
          );

          _isConnected = true;
          _webSocket!.add(jsonEncode({"RequestAllEntityData": null}));
        }
      }
    } on Exception catch (e) {
      setError("Error starting server: $e");
      _ipAddress = null;
      notifyListeners();
    }
  }

  void clearScannedPossessor() {
    _scannedPossessor = null;
    notifyListeners();
  }

  void confirmAskingForPossessor() {
    if (_isAskingForPossessor) {
      if (_scannedPossessor != null) {
        _broadcastEntity(_scannedEntityId!, [
          ("Possessor", _scannedPossessor!),
        ]);
      } else {
        _broadcastEntity(_scannedEntityId!, []);
      }

      _scannedEntityId = null;
      _scannedPossessor = null;
      _isAskingForPossessor = false;
      notifyListeners();
    }
  }

  void cancelAskingForPossessor() {
    _scannedEntityId = null;
    _scannedPossessor = null;
    _isAskingForPossessor = false;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void handleEntityId(String entityId) {
    if (entityId.isEmpty) {
      throw Exception("Empty entity ID");
    }

    final entity = _entities[entityId];

    if (_isAskingForPossessor) {
      if (entity == null) {
        throw Exception(
          "Cannot use this id as possessor, it is not registered.",
        );
      }

      if (!entity.isPerson) {
        throw Exception(
          "Cannot use this id as possessor, it is not associated to a person.",
        );
      }

      _scannedPossessor = entityId;
      notifyListeners();
      return;
    }

    if (entity != null && entity.possessor == null) {
      if (entity.isVehicle) {
        if (entity.isOutside) {
          _scannedPossessor = null;
          _isAskingForPossessor = true;
        }
      }
      if (entity.isItem) {
        if (entity.isInside) {
          _scannedPossessor = null;
          _isAskingForPossessor = true;
        }
      }
    }

    _scannedEntityId = entityId;
    notifyListeners();

    if (!_isAskingForPossessor) {
      _broadcastEntity(entityId, []);
    }
  }

  void handleCode(String code) {
    if (code.isEmpty) {
      throw Exception("Empty code");
    }

    if (_isAskingForPossessor) {
      throw Exception(
        "Cannot use code as possessor, please scan a possessor id.",
      );
    }

    _scannedEntityId = code;
    notifyListeners();

    _broadcastCode(code);
  }

  void _broadcastEntity(String entityId, List<(String, Object)> dataFields) {
    _webSocket?.add(
      jsonEncode({
        "Entity": [
          entityId,
          [
            for (var (fieldTy, fieldVal) in dataFields) {fieldTy: fieldVal},
          ],
        ],
      }),
    );
  }

  void _broadcastCode(String code) {
    _webSocket?.add(jsonEncode({"Code": code}));
  }
}
