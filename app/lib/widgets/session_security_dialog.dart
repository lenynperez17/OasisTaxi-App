import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/session_security_service.dart';
import '../utils/app_logger.dart';

/// Diálogo para configuración y verificación de PIN de seguridad
class SessionSecurityDialog extends StatefulWidget {
  final SessionSecurityMode mode;
  final Function()? onSuccess;
  final Function()? onCancel;

  const SessionSecurityDialog({
    Key? key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
  }) : super(key: key);

  @override
  State<SessionSecurityDialog> createState() => _SessionSecurityDialogState();
}

class _SessionSecurityDialogState extends State<SessionSecurityDialog> {
  final SessionSecurityService _securityService = SessionSecurityService();
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  String? _errorMessage;
  int _attemptsRemaining = 3;
  bool _isLoading = false;

  // Para modo de configuración
  String? _confirmPin;
  bool _isConfirmingPin = false;

  @override
  void initState() {
    super.initState();
    // Focus en el primer campo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentPin {
    return _pinControllers.map((c) => c.text).join();
  }

  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handlePinSubmit() async {
    final pin = _currentPin;

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'El PIN debe tener 6 dígitos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (widget.mode) {
        case SessionSecurityMode.setup:
          await _handleSetupPin(pin);
          break;
        case SessionSecurityMode.verify:
          await _handleVerifyPin(pin);
          break;
        case SessionSecurityMode.change:
          await _handleChangePin(pin);
          break;
      }
    } catch (e) {
      AppLogger.error('Error en operación de PIN', e);
      setState(() {
        _errorMessage = 'Error al procesar el PIN';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSetupPin(String pin) async {
    if (!_isConfirmingPin) {
      // Primer ingreso del PIN
      setState(() {
        _confirmPin = pin;
        _isConfirmingPin = true;
      });
      _clearPin();
      return;
    }

    // Confirmación del PIN
    if (pin != _confirmPin) {
      setState(() {
        _errorMessage = 'Los PINs no coinciden';
        _isConfirmingPin = false;
        _confirmPin = null;
      });
      _clearPin();
      return;
    }

    // Configurar el PIN
    final success = await _securityService.setupPin(pin);

    if (success) {
      AppLogger.info('PIN configurado exitosamente');
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Error al configurar el PIN';
        _isConfirmingPin = false;
        _confirmPin = null;
      });
      _clearPin();
    }
  }

  Future<void> _handleVerifyPin(String pin) async {
    final isValid = await _securityService.verifyPin(pin);

    if (isValid) {
      AppLogger.info('PIN verificado correctamente');
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } else {
      _attemptsRemaining--;

      if (_attemptsRemaining <= 0) {
        // Bloquear sesión por seguridad
        await _securityService.lockSession('Múltiples intentos fallidos de PIN');
        Navigator.of(context).pop(false);
      } else {
        setState(() {
          _errorMessage = 'PIN incorrecto. Intentos restantes: $_attemptsRemaining';
        });
        _clearPin();
      }
    }
  }

  Future<void> _handleChangePin(String pin) async {
    // Similar a setup pero primero verifica el PIN actual
    // Implementación pendiente según flujo específico
    setState(() {
      _errorMessage = 'Cambio de PIN en desarrollo';
    });
  }

  Widget _buildPinInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Container(
          width: 45,
          height: 55,
          margin: EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: _pinControllers[index].text.isNotEmpty
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.grey[100],
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                // Mover al siguiente campo
                _focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                // Mover al campo anterior si se borra
                _focusNodes[index - 1].requestFocus();
              }

              // Verificar si todos los campos están llenos
              if (_pinControllers.every((c) => c.text.isNotEmpty)) {
                _handlePinSubmit();
              }

              setState(() {}); // Actualizar color de fondo
            },
          ),
        );
      }),
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeypadButton('', icon: Icons.fingerprint),
              _buildKeypadButton('0'),
              _buildKeypadButton('', icon: Icons.backspace_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String number, {IconData? icon}) {
    final isDisabled = icon == Icons.fingerprint &&
                       !_securityService.isBiometricAvailable;

    return Container(
      width: 80,
      height: 80,
      margin: EdgeInsets.all(5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: isDisabled ? null : () {
            if (icon == Icons.backspace_outlined) {
              _handleBackspace();
            } else if (icon == Icons.fingerprint) {
              _handleBiometric();
            } else if (number.isNotEmpty) {
              _handleNumberInput(number);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDisabled
                  ? Colors.grey[200]
                  : Colors.grey[100],
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 28,
                      color: isDisabled
                          ? Colors.grey[400]
                          : Theme.of(context).primaryColor,
                    )
                  : Text(
                      number,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleNumberInput(String number) {
    // Encontrar el primer campo vacío
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = number;
        if (i < 5) {
          _focusNodes[i + 1].requestFocus();
        }

        // Verificar si todos los campos están llenos
        if (_pinControllers.every((c) => c.text.isNotEmpty)) {
          _handlePinSubmit();
        }
        break;
      }
    }
  }

  void _handleBackspace() {
    // Encontrar el último campo con contenido
    for (int i = 5; i >= 0; i--) {
      if (_pinControllers[i].text.isNotEmpty) {
        _pinControllers[i].clear();
        _focusNodes[i].requestFocus();
        break;
      }
    }
  }

  void _handleBiometric() async {
    if (!_securityService.isBiometricAvailable) return;

    final success = await _securityService.authenticateWithBiometric(
      reason: 'Verificar identidad para continuar',
    );

    if (success) {
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Autenticación biométrica fallida';
      });
    }
  }

  String _getTitle() {
    switch (widget.mode) {
      case SessionSecurityMode.setup:
        return _isConfirmingPin ? 'Confirmar PIN' : 'Configurar PIN';
      case SessionSecurityMode.verify:
        return 'Verificar PIN';
      case SessionSecurityMode.change:
        return 'Cambiar PIN';
    }
  }

  String _getSubtitle() {
    switch (widget.mode) {
      case SessionSecurityMode.setup:
        return _isConfirmingPin
            ? 'Ingrese nuevamente su PIN de 6 dígitos'
            : 'Cree un PIN de 6 dígitos para proteger su sesión';
      case SessionSecurityMode.verify:
        return 'Ingrese su PIN para continuar';
      case SessionSecurityMode.change:
        return 'Ingrese su PIN actual';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con ícono
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 24),

            // Título
            Text(
              _getTitle(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            // Subtítulo
            Text(
              _getSubtitle(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            SizedBox(height: 32),

            // Input de PIN
            _buildPinInput(),

            // Mensaje de error
            if (_errorMessage != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            SizedBox(height: 24),

            // Teclado numérico
            _buildNumericKeypad(),

            SizedBox(height: 24),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                if (widget.mode == SessionSecurityMode.verify)
                  TextButton(
                    onPressed: () {
                      // Opción para recuperar PIN (requiere autenticación adicional)
                      AppLogger.info('Solicitud de recuperación de PIN');
                    },
                    child: Text('¿Olvidó su PIN?'),
                  ),
              ],
            ),

            // Indicador de carga
            if (_isLoading)
              Container(
                margin: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modos de operación del diálogo de seguridad
enum SessionSecurityMode {
  setup,   // Configurar nuevo PIN
  verify,  // Verificar PIN existente
  change,  // Cambiar PIN
}