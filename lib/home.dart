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
      appBar: AppBar(title: const Text('NFC Reader')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            if (widget._viewModel.error != null) ...[
              Text(
                widget._viewModel.error!,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              ElevatedButton(
                onPressed: widget._viewModel.clearError,
                child: Text("Dismiss"),
              ),
            ],

            if (widget._viewModel.nInside != null)
              Text(
                'Inside Count: ${widget._viewModel.nInside}',
                style: const TextStyle(fontSize: 24),
              ),

            Scanner(
              onDetect: (result) async {
                final code = result.barcodes.firstOrNull?.rawValue;

                if (code == null) {
                  player.play(AssetSource('detected-error.mp3'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to scan barcode')),
                    );
                  }
                  return false;
                }

                try {
                  widget._viewModel.setAndBroadcastCode(code);
                } on Exception catch (e) {
                  player.play(AssetSource('detected-error.mp3'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to detect: $e')),
                    );
                  }
                  return false;
                }

                player.play(AssetSource('detected-success.mp3'));

                return true;
              },
            ),

            if (widget._viewModel.scanned != null)
              ListTile(
                title: Text('Last Scanned'),
                subtitle: Text(widget._viewModel.scanned!),
              ),

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
