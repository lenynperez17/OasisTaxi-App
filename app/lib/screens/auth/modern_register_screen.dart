// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';

class ModernRegisterScreen extends StatefulWidget {
  const ModernRegisterScreen({super.key});

  @override
  State<ModernRegisterScreen> createState() => _ModernRegisterScreenState();
}

class _ModernRegisterScreenState extends State<ModernRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late AnimationController _backgroundController;
  late AnimationController _formController;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _userType = 'passenger';
  bool _acceptTerms = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _formController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Función de registro real con Firebase
  Future<void> _registerUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      setState(() => _isLoading = true);

      // Usar el email ingresado por el usuario
      String email = _emailController.text.trim();

      // Registrar usuario en Firebase
      final success = await authProvider.register(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        userType: _userType,
      );

      // Verificar que el widget siga montado antes de usar context
      if (!mounted) return;

      // Si el registro fue exitoso, navegar a la pantalla de verificación de email
      if (success) {
        Navigator.pushReplacementNamed(
          context,
          '/email-verification',
          arguments: email,
        );
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernTheme.oasisGreen,
                      ModernTheme.oasisBlack,
                      ModernTheme.accentGray,
                    ],
                    transform: GradientRotation(
                      _backgroundController.value * 2 * math.pi
                    ),
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Crear cuenta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Progress indicator
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: List.generate(3, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index <= _currentStep 
                                  ? Colors.white 
                                  : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Form
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 500),
                      child: Container(
                        key: ValueKey<int>(_currentStep),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: ModernTheme.floatingShadow,
                        ),
                        child: Form(
                          key: _formKey,
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildUserTypeStep();
      case 1:
        return _buildPersonalInfoStep();
      case 2:
        return _buildAccountStep();
      default:
        return Container();
    }
  }
  
  Widget _buildUserTypeStep() {
    return Column(
      children: [
        Text(
          '¿Cómo quieres usar Oasis Taxi?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 30),
        
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'passenger';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'passenger' 
            ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
            : null,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: ModernTheme.oasisGreen,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pasajero',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Solicita viajes y negocia precios',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        AnimatedElevatedCard(
          onTap: () {
            setState(() {
              _userType = 'driver';
              _currentStep = 1;
            });
          },
          borderRadius: 16,
          color: _userType == 'driver' 
            ? ModernTheme.oasisBlack.withValues(alpha: 0.1)
            : null,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisBlack.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: ModernTheme.oasisBlack,
                    size: 30,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conductor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Acepta viajes y gana dinero',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        Text(
          'Información personal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24),
        
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu nombre';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            prefixIcon: Icon(Icons.phone, color: ModernTheme.oasisGreen),
            prefixText: '+51 ',
            helperText: '9 dígitos',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu número';
            }
            // Validar formato peruano: 9 dígitos
            final phoneRegex = RegExp(r'^\d{9}$');
            if (!phoneRegex.hasMatch(value)) {
              return 'Debe tener exactamente 9 dígitos';
            }
            // Validar que empiece con 9 (típico de móviles en Perú)
            if (!value.startsWith('9')) {
              return 'Número móvil debe empezar con 9';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined, color: ModernTheme.oasisGreen),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu correo';
            }
            if (!value.contains('@')) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        
        SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep = 0);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Atrás'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AnimatedPulseButton(
                text: 'Continuar',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAccountStep() {
    return Column(
      children: [
        Text(
          'Crea tu contraseña',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24),
        
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa una contraseña';
            }
            if (value.length < 6) {
              return 'Mínimo 6 caracteres';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
        
        SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: _acceptTerms
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _acceptTerms
                ? ModernTheme.oasisGreen.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value!),
            title: Text(
              'Acepto los términos y condiciones',
              style: TextStyle(
                fontSize: 14,
                color: _acceptTerms ? Colors.black87 : Colors.red.shade700,
                fontWeight: _acceptTerms ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            subtitle: !_acceptTerms
              ? Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Debes aceptar los términos para continuar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                )
              : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: ModernTheme.oasisGreen,
          ),
        ),

        SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Atrás'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AnimatedPulseButton(
                text: 'Crear cuenta',
                icon: Icons.check,
                isLoading: _isLoading,
                onPressed: _acceptTerms ? () async {
                  if (_formKey.currentState!.validate()) {
                    await _registerUser();
                  }
                } : () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}