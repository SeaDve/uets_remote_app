import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              widget._viewModel.isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color:
                    widget._viewModel.isConnected ? Colors.green : Colors.red,
                fontSize: 18,
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
              const Text(
                'Please scan a possessor tag.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              if (widget._viewModel.scannedPossessorDisplay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Text('Scanned Possessor:'),
                      SelectableText(
                        widget._viewModel.scannedPossessorDisplay!,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (widget._viewModel.canClearAndBroadcastPossessor)
                ElevatedButton(
                  onPressed: () {
                    widget._viewModel.clearAndBroadcastEntityWithPossessor();
                    player.play(AssetSource('detected-success.mp3'));
                  },
                  child: const Text("Confirm Possessor"),
                ),
            ],

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showDetails = !_showDetails; // Toggle visibility
                });
              },
              child: Text(_showDetails ? 'Hide Details' : 'Show Details'),
            ),

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
          ],
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
