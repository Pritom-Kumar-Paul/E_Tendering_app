import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _sending = false;

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not signed in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This account has no email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // Optional: choose template language
      await FirebaseAuth.instance.setLanguageCode('en'); // or 'bn'

      // Simple send (do NOT pass ActionCodeSettings unless you’ve configured Dynamic Links)
      await user.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification email sent to ${user.email}')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Failed to send verification email';
      switch (e.code) {
        case 'too-many-requests':
          msg = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          msg = 'Network error. Check your internet connection.';
          break;
        default:
          msg = 'Error: ${e.code} ${e.message ?? ''}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshVerification() async {
    await FirebaseAuth.instance.currentUser?.reload();
    // AuthPage listens to userChanges(); once verified, it will navigate automatically
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We sent a verification link to: $email',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _sending ? null : _resend,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend email'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshVerification,
                child: const Text('I have verified'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async => FirebaseAuth.instance.signOut(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
