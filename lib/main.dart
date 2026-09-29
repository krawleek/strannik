import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'presentation/app/home_runtime.dart';
import 'presentation/app/strannik_app.dart';
import 'presentation/components/strannik_button.dart';
import 'presentation/foundation/app_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<HomeRuntime> _opening;
  HomeRuntime? _runtime;
  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<HomeRuntime> _open() async {
    final runtime = await HomeRuntime.open();
    if (!mounted) {
      await runtime.close();
      return runtime;
    }
    _runtime = runtime;
    return runtime;
  }

  @override
  void dispose() {
    _runtime?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HomeRuntime>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return StrannikApp(controller: snapshot.data!.controller);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Странник',
        theme: ThemeData(fontFamily: AppTypography.family),
        home: Scaffold(
          backgroundColor: AppColors.yellow,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.hasError
                          ? 'Не получилось открыть дом'
                          : 'Открываем дом…',
                      style: AppTypography.heading,
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 24),
                      StrannikButton(
                        label: 'Попробовать снова',
                        onPressed: () => setState(() => _opening = _open()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
