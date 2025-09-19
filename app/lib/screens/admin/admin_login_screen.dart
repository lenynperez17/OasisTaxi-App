import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart' as oasis_auth;
import '../../services/security_integration_service.dart';
import '../../core/config/environment_config.dart';
import '../../services/firestore_database_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => AdminLoginScreenState();
}

class AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _iconController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showTwoFactor = false;
  // String? _verificationId; // No usado actualmente
  FirestoreDatabaseService? _firestoreService;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('AdminLoginScreen', 'initState');

    // Inicializar Firestore service
    _firestoreService = FirestoreDatabaseService();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _iconController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authProvider =
            Provider.of<oasis_auth.AuthProvider>(context, listen: false);

        // Verificar que es un admin autorizado (usando configuración segura)
        if (!(await _isAuthorizedAdmin(_emailController.text.toLowerCase()))) {
          _showSnackBar('Solo administradores autorizados pueden acceder',
              ModernTheme.error);
          setState(() => _isLoading = false);
          return;
        }

        // Intentar login con Firebase Auth (con soporte 2FA)
        final success = await authProvider.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (success) {
          // Login exitoso sin 2FA o con 2FA auto-resuelto
          // Verificar que el usuario es admin
          if (authProvider.currentUser?.userType == 'admin') {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          } else {
            _showSnackBar(
                'Usuario no autorizado como administrador', ModernTheme.error);
            await authProvider.logout();
            setState(() => _isLoading = false);
          }
        } else if (authProvider.errorMessage == '2FA_REQUIRED') {
          // El usuario tiene 2FA habilitado, mostrar pantalla de código
          setState(() {
            _showTwoFactor = true;
            _isLoading = false;
          });
        } else {
          // Error de credenciales u otro error
          _showSnackBar(authProvider.errorMessage ?? 'Credenciales inválidas',
              ModernTheme.error);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        AppLogger.debug('Error en login admin: $e');
        _showSnackBar(
            'Error de autenticación: ${e.toString()}', ModernTheme.error);
        setState(() => _isLoading = false);
      }
    }
  }

  /// Verificación 2FA real con Firebase MFA
  Future<void> _verify2FA() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length != 6) {
      _showSnackBar('Ingrese el código de 6 dígitos', ModernTheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider =
          Provider.of<oasis_auth.AuthProvider>(context, listen: false);

      // Verificar segundo factor usando Firebase MFA
      final success = await authProvider.verifySecondFactor(code);

      if (success) {
        // Verificación 2FA exitosa
        // Verificar que el usuario autenticado es admin
        if (authProvider.currentUser?.userType == 'admin') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        } else {
          _showSnackBar(
              'Usuario no autorizado como administrador', ModernTheme.error);
          await authProvider.logout();
        }
      } else {
        _showSnackBar(
            authProvider.errorMessage ?? 'Código de verificación inválido',
            ModernTheme.error);
      }
    } catch (e) {
      AppLogger.debug('Error verificando 2FA: $e');
      _showSnackBar(
          'Error de verificación: ${e.toString()}', ModernTheme.error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Método removido - no se necesitan custom claims para esta implementación

  /// Verificar si es un administrador autorizado usando Firestore
  Future<bool> _isAuthorizedAdmin(String email) async {
    try {
      if (_firestoreService == null) {
        AppLogger.error('Firestore service no inicializado');
        return false;
      }

      // Consultar la colección de administradores autorizados
      final adminDoc = await _firestoreService!.getDocument(
        collection: EnvironmentConfig.adminFirestoreCollection,
        documentId: email.toLowerCase(),
      );

      if (adminDoc.exists) {
        final adminData = adminDoc.data() as Map<String, dynamic>?;

        // Verificar que el admin esté activo
        final isActive = adminData?['isActive'] ?? false;
        final role = adminData?['role'] ?? '';

        if (isActive && (role == 'admin' || role == 'super_admin')) {
          AppLogger.info('Admin autorizado encontrado: $email');
          return true;
        } else {
          AppLogger.warning('Admin inactivo o sin permisos: $email');
          return false;
        }
      } else {
        AppLogger.warning('Admin no encontrado en Firestore: $email');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando admin en Firestore', e, stackTrace);
      return false;
    }
  }

  /// Estructura de documento de admin para referencia:
  /// {
  ///   "email": "admin@oasistaxiperu.com",
  ///   "role": "admin", // admin, super_admin
  ///   "isActive": true,
  ///   "createdAt": Timestamp,
  ///   "lastLogin": Timestamp,
  ///   "permissions": [
  ///     "dashboard_access",
  ///     "user_management",
  ///     "financial_reports",
  ///     "driver_management"
  ///   ],
  ///   "createdBy": "system",
  ///   "department": "operations"
  /// }
  void _logAdminDocumentStructure() {
    AppLogger.info('Estructura de documento admin requerida en Firestore');
  }

  // /// Validar formato de email
  // bool _isValidEmail(String email) {
  //   return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
  //       .hasMatch(email);
  // }

  /// Helper para mostrar SnackBar
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.oasisBlack,
      body: Stack(
        children: [
          // Fondo animado oscuro
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernTheme.oasisBlack,
                      ModernTheme.accentGray,
                      ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    ],
                    transform: GradientRotation(
                      _backgroundController.value * 2 * math.pi,
                    ),
                  ),
                ),
              );
            },
          ),

          // Patrón de seguridad
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                final progress =
                    (_backgroundController.value + index * 0.33) % 1;
                return Positioned(
                  left: MediaQuery.of(context).size.width * progress,
                  top: MediaQuery.of(context).size.height * 0.2 * (index + 1),
                  child: Transform.rotate(
                    angle: progress * 2 * math.pi,
                    child: Icon(
                      Icons.security,
                      size: 30,
                      color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _formController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _formController.value,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  ModernTheme.oasisGreen.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _showTwoFactor
                            ? _build2FAForm()
                            : _buildLoginForm(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono de admin con animación
          AnimatedBuilder(
            animation: _iconController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ModernTheme.oasisGreen,
                      ModernTheme.oasisGreen.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ModernTheme.oasisGreen.withValues(alpha: 0.5),
                      blurRadius: 20 + (_iconController.value * 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 50,
                  color: Colors.white,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            'ADMIN PANEL',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ModernTheme.oasisBlack,
              letterSpacing: 2,
            ),
          ),

          const Text(
            'Acceso Restringido',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // Campo de email
          SecurityIntegrationService.buildSecureTextField(
            context: context,
            controller: _emailController,
            label: 'Correo Administrativo',
            fieldType: 'email',
            hintText: 'admin@oasistaxiperu.com',
            prefixIcon: const Icon(Icons.email, color: ModernTheme.oasisGreen),
          ),

          const SizedBox(height: 16),

          // Campo de contraseña
          SecurityIntegrationService.buildSecureTextField(
            context: context,
            controller: _passwordController,
            label: 'Contraseña',
            fieldType: 'password',
            obscureText: _obscurePassword,
            prefixIcon: const Icon(Icons.lock, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: ModernTheme.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const SizedBox(height: 24),

          // Botón de login
          AnimatedPulseButton(
            text: 'ACCEDER AL PANEL',
            icon: Icons.security,
            isLoading: _isLoading,
            onPressed: _login,
            color: ModernTheme.oasisGreen,
          ),

          const SizedBox(height: 16),

          // Información de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este acceso es solo para administradores autorizados',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Volver al login normal
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text(
              'Volver al Login Normal',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build2FAForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.verified_user,
          size: 60,
          color: ModernTheme.oasisGreen,
        ),

        const SizedBox(height: 24),

        const Text(
          'Verificación de 2 Factores',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ModernTheme.oasisBlack,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Ingresa el código de 6 dígitos',
          style: TextStyle(
            color: ModernTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Campo de código
        SecurityIntegrationService.buildSecureTextField(
          context: context,
          controller: _codeController,
          label: '',
          fieldType: 'otpcode',
          hintText: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),

        const SizedBox(height: 24),

        AnimatedPulseButton(
          text: 'VERIFICAR',
          icon: Icons.check,
          isLoading: _isLoading,
          onPressed: _verify2FA,
          color: ModernTheme.oasisGreen,
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            setState(() {
              _showTwoFactor = false;
              _codeController.clear();
            });
          },
          child: const Text(
            'Cancelar',
            style: TextStyle(color: ModernTheme.textSecondary),
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'Se enviará un código de verificación por SMS a tu teléfono registrado.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
