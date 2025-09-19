import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_logger.dart';

/// Diálogo de solicitud de PIN seguro
/// Usado para re-autenticación y verificación de identidad
class SecurePinPrompt extends StatefulWidget {
  final String? customMessage;
  final Function(String pin) onPinSubmitted;
  final VoidCallback? onCancel;

  const SecurePinPrompt({
    Key? key,
    this.customMessage,
    required this.onPinSubmitted,
    this.onCancel,
  }) : super(key: key);

  static Future<String?> show({
    required BuildContext context,
    String? customMessage,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SecurePinPrompt(
        customMessage: customMessage,
        onPinSubmitted: (pin) {
          Navigator.of(context).pop(pin);
        },
        onCancel: () {
          Navigator.of(context).pop(null);
        },
      ),
    );
  }

  @override
  State<SecurePinPrompt> createState() => _SecurePinPromptState();
}

class _SecurePinPromptState extends State<SecurePinPrompt> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isObscured = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-focus primer campo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentPin {
    return _controllers.map((c) => c.text).join();
  }

  void _handleSubmit() {
    final pin = _currentPin;

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'El PIN debe tener exactamente 6 dígitos';
      });
      return;
    }

    AppLogger.debug('PIN ingresado para verificación');
    widget.onPinSubmitted(pin);
  }

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _errorMessage = null;
    });
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 45,
      height: 55,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: _isObscured,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
              width: 2,
            ),
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
          fillColor: _controllers[index].text.isNotEmpty
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[50],
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

          // Auto-submit cuando todos los campos están llenos
          if (_controllers.every((c) => c.text.isNotEmpty)) {
            _handleSubmit();
          }

          setState(() {
            _errorMessage = null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        padding: EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: 400,
          minHeight: 320,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de seguridad
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),

            SizedBox(height: 20),

            // Título
            Text(
              'Verificación de Seguridad',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            // Mensaje personalizado o predeterminado
            Text(
              widget.customMessage ?? 'Ingrese su PIN para continuar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            SizedBox(height: 24),

            // Campos de PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) => _buildPinField(index)),
            ),

            // Mensaje de error
            if (_errorMessage != null) ...[
              SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],

            SizedBox(height: 24),

            // Toggle visibilidad
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                ),
                Text(
                  _isObscured ? 'Mostrar PIN' : 'Ocultar PIN',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel?.call();
                  },
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                TextButton(
                  onPressed: _clearPin,
                  child: Text('Limpiar'),
                ),

                ElevatedButton(
                  onPressed: _currentPin.length == 6 ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Verificar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}