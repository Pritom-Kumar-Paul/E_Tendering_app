import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'sign_up_page.dart';
import 'verify_email_page.dart';
import 'tenders_list_page.dart';
import 'services/role_service.dart';
import 'admin/admin_home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  void togglePage() => setState(() => isLogin = !isLogin);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          return isLogin
              ? LoginPage(onPressed: togglePage)
              : SignUp(onPressed: togglePage);
        }

        final isEmailProvider = user.providerData.any(
          (p) => p.providerId == 'password',
        );
        if (isEmailProvider && !(user.emailVerified)) {
          return const VerifyEmailPage();
        }

        // Admin vs normal user
        return StreamBuilder<bool>(
          stream: RoleService.isAdmin(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final isAdmin = s.data == true;
            return isAdmin ? const AdminHomePage() : const TendersListPage();
          },
        );
      },
    );
  }
}
