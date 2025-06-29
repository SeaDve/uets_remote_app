import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:uets_remote_app/main.dart' show player;
import 'package:uets_remote_app/scanner.dart';
import 'home_viewmodel.dart';

class Home extends StatefulWidget {
  final HomeViewModel _viewModel;

  const Home({super.key, required HomeViewModel viewModel})
    : _viewModel = viewModel;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _showDetails = false; // State to toggle visibility

  @override
  void initState() {
    super.initState();

    FlutterNfcKit.tagStream.listen(
      (tag) {
        final entityId = tag.id;

        try {
          widget._viewModel.handleEntityId(entityId);
          widget._viewModel.clearError();
        } catch (e) {
          player.play(AssetSource('detected-error.mp3'));
          widget._viewModel.setError("Error handling tag: $e");
        }
      },
      onError: (error) {
        widget._viewModel.setError("NFC tag stream error: $error");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    widget._viewModel.onMessage = (message) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    };

    return Scaffold(
      appBar: AppBar(title: const Text('TRACE Scanner')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState:
                    _showDetails
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(), // Empty widget when hidden
                secondChild: Column(
                  spacing: 10,
                  children: [
                    const Text('Server IP Address:'),
                    Text(
                      widget._viewModel.ipAddress ?? 'No IP address',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetails = !_showDetails; // Toggle visibility
                  });
                },
                child: Text(
                  widget._viewModel.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color:
                        widget._viewModel.isConnected
                            ? Colors.green
                            : Colors.red,
                    fontSize: 18,
                  ),
                ),
              ),

              Column(
                spacing: 10,
                children: [
                  Text(
                    'Persons Inside: ${widget._viewModel.nPersonsInside} of ${widget._viewModel.nPersons}',
                  ),
                  Text(
                    'Items Inside: ${widget._viewModel.nItemsInside} of ${widget._viewModel.nItems}',
                  ),
                  Text(
                    'Vehicles Inside: ${widget._viewModel.nVehiclesInside} of ${widget._viewModel.nVehicles}',
                  ),
                ],
              ),

              if (widget._viewModel.error != null) ...[
                Text(
                  widget._viewModel.error!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                ElevatedButton(
                  onPressed: widget._viewModel.clearError,
                  child: const Text("Dismiss"),
                ),
              ],

              Scanner(
                onDetect: (code) async {
                  try {
                    if (isUetsQrFormat(code)) {
                      widget._viewModel.handleEntityId(entityIdFromCode(code));
                    } else {
                      widget._viewModel.handleCode(code);
                    }
                    widget._viewModel.clearError();
                  } on Exception catch (e) {
                    player.play(AssetSource('detected-error.mp3'));
                    widget._viewModel.setError(e.toString());
                    return false;
                  }

                  player.play(AssetSource('detected-success.mp3'));

                  return true;
                },
              ),

              if (widget._viewModel.scannedEntityDisplay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    spacing: 5,
                    children: [
                      const Text('Last Scanned Entity ID:'),
                      SelectableText(
                        widget._viewModel.scannedEntityDisplay!,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              if (widget._viewModel.isAskingForPossessor) ...[
                if (widget._viewModel.scannedPossessorDisplay != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Column(
                          children: [
                            const Text('Scanned Possessor:'),
                            SelectableText(
                              widget._viewModel.scannedPossessorDisplay!,
                              style: const TextStyle(fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.backspace, size: 18),
                          onPressed: () {
                            widget._viewModel.clearScannedPossessor();
                          },
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Please scan a possessor tag.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                if (widget._viewModel.isAskingForPossessor)
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          widget._viewModel.confirmAskingForPossessor();
                          player.play(AssetSource('detected-success.mp3'));
                        },
                        child: Text(
                          widget._viewModel.scannedPossessorDisplay == null
                              ? 'Confirm without Possessor'
                              : 'Confirm Possessor',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          widget._viewModel.cancelAskingForPossessor();
                        },
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String entityIdFromCode(String code) {
  if (!code.startsWith("UETS:")) {
    throw Exception("Invalid UETS QR code format or prefix");
  }

  return code.substring(5);
}

bool isUetsQrFormat(String code) {
  try {
    entityIdFromCode(code);
    return true;
  } catch (e) {
    return false;
  }
}
