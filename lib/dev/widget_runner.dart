import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WidgetRunner extends StatefulWidget {
  final Future<void> Function() scenario;
  const WidgetRunner({super.key, required this.scenario});

  @override
  State<WidgetRunner> createState() => _WidgetRunnerState();
}

class _WidgetRunnerState extends State<WidgetRunner> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      await widget.scenario();
    } catch (e, stack) {
      // ignore: avoid_print
      print('ERROR: $e');
      // ignore: avoid_print
      print('STACK: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('WidgetRunner active — see terminal',
              style: TextStyle(color: Colors.green)),
        ),
      ),
    );
  }
}
