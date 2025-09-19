import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../utils/app_logger.dart';

class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  ModernSplashScreenState createState() => ModernSplashScreenState();
}

class ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _rippleController;
  late AnimationController _carController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernSplashScreen', 'initState');

    _logoController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _carController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    _carAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    AppLogger.info('Iniciando animaciones del Splash Screen');
    await Future.delayed(Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(Duration(milliseconds: 800));
    _textController.forward();
    _rippleController.repeat();
    _carController.repeat();

    AppLogger.info('Esperando 3 segundos antes de navegar...');
    await Future.delayed(Duration(seconds: 3));
    _navigateToLogin();
  }

  void _navigateToLogin() {
    AppLogger.navigation('ModernSplashScreen', '/login');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _rippleController.dispose();
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ModernTheme.primaryOrange,
              ModernTheme.primaryBlue,
              ModernTheme.darkBlue,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Patrón de fondo animado
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final delay = index * 0.3;
                  final animValue =
                      (_rippleAnimation.value - delay).clamp(0.0, 1.0);
                  return Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 2 * animValue,
                      height: MediaQuery.of(context).size.width * 2 * animValue,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: 0.2 * (1 - animValue)),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            // Carros animados en el fondo
            AnimatedBuilder(
              animation: _carAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 50,
                  left: MediaQuery.of(context).size.width * _carAnimation.value,
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(
                      Icons.directions_car,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            AnimatedBuilder(
              animation: _carAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 100,
                  right:
                      MediaQuery.of(context).size.width * _carAnimation.value,
                  child: Opacity(
                    opacity: 0.3,
                    child: Transform.flip(
                      flipX: true,
                      child: Icon(
                        Icons.directions_car,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Contenido principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animado
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_logoScaleAnimation, _logoRotateAnimation]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotateAnimation.value,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Logo real de Oasis Taxi
                                Container(
                                  padding: EdgeInsets.all(20),
                                  child: Image.asset(
                                    'assets/images/logo_oasis_taxi.png',
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback al ícono si la imagen no carga
                                      return Icon(
                                        Icons.local_taxi,
                                        size: 80,
                                        color: ModernTheme.primaryOrange,
                                      );
                                    },
                                  ),
                                ),
                                // Efecto de brillo
                                Positioned(
                                  top: 30,
                                  right: 30,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 10,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Texto animado
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_textFadeAnimation, _textSlideAnimation]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              Text(
                                'OASIS TAXI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      offset: Offset(2, 2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Tu viaje, tu precio',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 80),

                  // Indicador de carga
                  AnimatedBuilder(
                    animation: _textFadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Preparando tu experiencia...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Versión en la parte inferior
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textFadeAnimation.value,
                    child: Text(
                      'Versión 2.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
