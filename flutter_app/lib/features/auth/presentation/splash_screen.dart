import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../shared/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbitCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _glowCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeCtrl.forward();
      _scaleCtrl.forward();
    });

    // Navigate after splash
    Future.delayed(const Duration(milliseconds: 2800), _navigate);
  }

  Future<void> _navigate() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    if (!mounted) return;
    context.go(token != null ? '/lottery' : '/login');
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF1A1050), LuxoraColors.background],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated logo
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: LuxoraColors.primary
                                      .withValues(alpha: _glowAnim.value * 0.5),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Orbiting numbers
                        AnimatedBuilder(
                          animation: _orbitCtrl,
                          builder: (_, __) {
                            return SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: List.generate(6, (i) {
                                  final angle = (i / 6) * 2 * math.pi +
                                      _orbitCtrl.value * 2 * math.pi;
                                  const radius = 58.0;
                                  final x = math.cos(angle) * radius;
                                  final y = math.sin(angle) * radius;
                                  final nums = [7, 14, 21, 28, 35, 3];
                                  return Transform.translate(
                                    offset: Offset(x, y),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            LuxoraColors.primaryLight,
                                            LuxoraColors.primary,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: LuxoraColors.primary
                                                .withValues(alpha: 0.7),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${nums[i]}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                        // Center sphere
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  LuxoraColors.primaryLight,
                                  LuxoraColors.primary,
                                  const Color(0xFF5A2800),
                                ],
                                center: const Alignment(-0.3, -0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: LuxoraColors.primary
                                      .withValues(alpha: _glowAnim.value * 0.8),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Brand name
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        LuxoraColors.accent,
                        Colors.white,
                        LuxoraColors.accent
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'LUXORA BETIX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu suerte, inteligente',
                    style: TextStyle(
                      color: LuxoraColors.textSecondary,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Loading indicator
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: LuxoraColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          LuxoraColors.primary),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
