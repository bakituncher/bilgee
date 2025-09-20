import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified ?? false) {
        timer.cancel();
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider.notifier);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta Doğrulama'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hesabınızı doğrulamak için ${user?.email} adresine bir doğrulama e-postası gönderdik.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await user?.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Doğrulama e-postası tekrar gönderildi.'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: ${e.toString()}'),
                      ),
                    );
                  }
                },
                child: const Text('E-postayı Tekrar Gönder'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user?.emailVerified ?? false) {
                    _timer?.cancel();
                    context.go(AppRoutes.home);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('E-posta hala doğrulanmamış.'),
                      ),
                    );
                  }
                },
                child: const Text('Doğruladım, Kontrol Et'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  authController.signOut();
                  context.go(AppRoutes.login);
                },
                child: const Text('Giriş Ekranına Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
