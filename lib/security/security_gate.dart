
import 'package:flutter/material.dart';
import 'pin_security.dart';

class SecurityGate extends StatefulWidget {
  const SecurityGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate>
    with WidgetsBindingObserver {
  final security = PinSecurity.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    security.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      security.lock();
    }
  }

  @override
  void dispose() {
    security.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsScreen = security.loading || security.locked;

    return Stack(
      children: [
        if (!security.loading)
          ExcludeFocus(
            excluding: needsScreen,
            child: widget.child,
          )
        else
          const SizedBox.expand(),


        if (needsScreen)
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (settings) {
                  return PageRouteBuilder<void>(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return _PinScreen(security: security);
                    },
                  );
                },
              ),
            ),
          ),

      ],
    );
  }
}

class _PinScreen extends StatefulWidget {
  const _PinScreen({required this.security});

  final PinSecurity security;

  @override
  State<_PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<_PinScreen> {
  final controller = TextEditingController();

  bool verifying = false;
  String? message;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (verifying) return;

    final pin = controller.text;

    setState(() {
      verifying = true;
      message = null;
    });

    try {
      final success = await widget.security.verify(pin);

      if (!mounted) return;

      controller.clear();

      if (success) {
        // SecurityGate получает уведомление от PinSecurity
        // и убирает экран блокировки.
        return;
      }

      final until = widget.security.retryAfter;

      setState(() {
        message = until != null &&
            DateTime.now().isBefore(until)
            ? 'Слишком много попыток. '
            'Повтори позже.'
            : 'Неверный PIN';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        message = 'Не удалось проверить PIN';
      });
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = widget.security;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 56,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Дневник+',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (security.loading)
                    const CircularProgressIndicator()
                  else if (security.initializationError != null)
                    Text(
                      security.initializationError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme.error,
                      ),
                    )
                  else ...[
                      const Text(
                        'Введи PIN, чтобы открыть дневник',
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: controller,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _unlock(),
                      ),

                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: Text(
                            message!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme.error,
                            ),
                          ),
                        ),

                      FilledButton(
                        onPressed: verifying ? null : _unlock,
                        child: Text(
                          verifying
                              ? 'Проверка...'
                              : 'Открыть',
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
