import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/shop_owner/shop_dashboard_screen.dart';
import 'screens/customer/customer_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  final isAuth = await authService.initAuth();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
      ],
      child: MyApp(initialAuth: isAuth),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool initialAuth;
  const MyApp({super.key, required this.initialAuth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hızlı ve Micro Sipariş',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.cardBg,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }
          if (auth.role == 'SHOP_OWNER') {
            return const ShopDashboardScreen();
          }
          if (auth.role == 'CUSTOMER') {
            return const CustomerMenuScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
