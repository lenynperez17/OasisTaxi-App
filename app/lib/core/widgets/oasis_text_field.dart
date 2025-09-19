import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/modern_theme.dart';
import '../constants/app_spacing.dart';
import '../../utils/validation_patterns.dart';

/// Campo de texto unificado y responsivo del sistema Oasis
/// Proporciona consistencia visual y funcional en toda la aplicación
class OasisTextField extends StatefulWidget {
  /// Etiqueta del campo
  final String label;

  /// Texto de ayuda
  final String? hintText;

  /// Texto de ayuda adicional debajo del campo
  final String? helperText;

  /// Icono al inicio del campo
  final IconData? prefixIcon;

  /// Widget al inicio del campo (tiene prioridad sobre prefixIcon)
  final Widget? prefixWidget;

  /// Icono al final del campo
  final Widget? suffixIcon;

  /// Tipo de teclado
  final TextInputType? keyboardType;

  /// Si el texto debe estar oculto
  final bool obscureText;

  /// Número máximo de líneas
  final int? maxLines;

  /// Número mínimo de líneas
  final int? minLines;

  /// Longitud máxima del texto
  final int? maxLength;

  /// Si el campo está habilitado
  final bool enabled;

  /// Si el campo es de solo lectura
  final bool readOnly;

  /// Función de validación
  final String? Function(String?)? validator;

  /// Formateadores de entrada
  final List<TextInputFormatter>? inputFormatters;

  /// Callback cuando cambia el texto
  final ValueChanged<String>? onChanged;

  /// Callback cuando se toca el campo
  final VoidCallback? onTap;

  /// Callback cuando se envía el formulario
  final ValueChanged<String>? onSubmitted;

  /// Valor inicial
  final String? initialValue;

  /// Controlador del campo
  final TextEditingController? controller;

  /// Nodo de foco
  final FocusNode? focusNode;

  /// Capitalización del texto
  final TextCapitalization textCapitalization;

  /// Acción del teclado
  final TextInputAction? textInputAction;

  /// Tipo de campo para estilos específicos
  final OasisTextFieldType type;

  /// Tamaño del campo
  final OasisTextFieldSize size;

  /// Color personalizado del borde
  final Color? borderColor;

  /// Color personalizado de fondo
  final Color? fillColor;

  /// Si debe mostrar contador de caracteres
  final bool showCounter;

  /// Si debe expandirse automáticamente (para texto largo)
  final bool autoExpand;

  /// Border radius personalizado
  final BorderRadius? borderRadius;

  /// Padding personalizado
  final EdgeInsets? contentPadding;

  /// Si el campo es obligatorio (muestra asterisco)
  final bool isRequired;

  /// Mensaje de error personalizado
  final String? errorText;

  /// Si debe usar diseño compacto en móviles
  final bool compactOnMobile;

  /// Semantic label para accesibilidad
  final String? semanticLabel;

  /// Si debe auto-completar
  final bool autocorrect;

  /// Sugerencias de auto-completado
  final Iterable<String>? autofillHints;

  const OasisTextField({
    super.key,
    required this.label,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.initialValue,
    this.controller,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.type = OasisTextFieldType.standard,
    this.size = OasisTextFieldSize.medium,
    this.borderColor,
    this.fillColor,
    this.showCounter = false,
    this.autoExpand = false,
    this.borderRadius,
    this.contentPadding,
    this.isRequired = false,
    this.errorText,
    this.compactOnMobile = false,
    this.semanticLabel,
    this.autocorrect = true,
    this.autofillHints,
  });

  @override
  State<OasisTextField> createState() => _OasisTextFieldState();

  // Factory methods para tipos comunes
  factory OasisTextField.email({
    Key? key,
    required String label,
    String? hintText,
    String? helperText,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    String? initialValue,
    bool enabled = true,
    bool readOnly = false,
    bool isRequired = false,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    bool compactOnMobile = false,
  }) {
    return OasisTextField(
      key: key,
      label: label,
      hintText: hintText ?? 'ejemplo@correo.com',
      helperText: helperText,
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      controller: controller,
      focusNode: focusNode,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidEmail(value)) {
          return ValidationPatterns.getEmailError();
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      isRequired: isRequired,
      size: size,
      compactOnMobile: compactOnMobile,
    );
  }

  factory OasisTextField.password({
    Key? key,
    required String label,
    String? hintText,
    String? helperText,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    String? initialValue,
    bool enabled = true,
    bool readOnly = false,
    bool isRequired = false,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    bool compactOnMobile = false,
  }) {
    return OasisTextField(
      key: key,
      label: label,
      hintText: hintText ?? 'Ingresa tu contraseña',
      helperText: helperText,
      prefixIcon: Icons.lock_outline,
      obscureText: true,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      autofillHints: const [AutofillHints.password],
      controller: controller,
      focusNode: focusNode,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidPassword(value)) {
          return ValidationPatterns.getPasswordError();
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      isRequired: isRequired,
      size: size,
      compactOnMobile: compactOnMobile,
    );
  }

  factory OasisTextField.phone({
    Key? key,
    required String label,
    String? hintText,
    String? helperText,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    String? initialValue,
    bool enabled = true,
    bool readOnly = false,
    bool isRequired = false,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    bool compactOnMobile = false,
  }) {
    return OasisTextField(
      key: key,
      label: label,
      hintText: hintText ?? '+51 999 999 999',
      helperText: helperText,
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      controller: controller,
      focusNode: focusNode,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidPeruMobile(value)) {
          return ValidationPatterns.getPhoneError();
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      isRequired: isRequired,
      size: size,
      compactOnMobile: compactOnMobile,
    );
  }

  factory OasisTextField.search({
    Key? key,
    required String label,
    String? hintText,
    String? helperText,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onTap,
    String? initialValue,
    bool enabled = true,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    bool compactOnMobile = false,
  }) {
    return OasisTextField(
      key: key,
      label: label,
      hintText: hintText ?? 'Buscar...',
      helperText: helperText,
      prefixIcon: Icons.search_outlined,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      type: OasisTextFieldType.search,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      initialValue: initialValue,
      enabled: enabled,
      size: size,
      compactOnMobile: compactOnMobile,
    );
  }

  factory OasisTextField.multiline({
    Key? key,
    required String label,
    String? hintText,
    String? helperText,
    int maxLines = 4,
    int? minLines,
    int? maxLength,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    String? initialValue,
    bool enabled = true,
    bool readOnly = false,
    bool isRequired = false,
    bool autoExpand = true,
    bool showCounter = false,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    bool compactOnMobile = false,
  }) {
    return OasisTextField(
      key: key,
      label: label,
      hintText: hintText,
      helperText: helperText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textInputAction: TextInputAction.newline,
      autoExpand: autoExpand,
      showCounter: showCounter,
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      isRequired: isRequired,
      size: size,
      compactOnMobile: compactOnMobile,
    );
  }
}

class _OasisTextFieldState extends State<OasisTextField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _obscureText = false;
  bool _isFocused = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscureText = widget.obscureText;

    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleValidationChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }

    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleValidationChange);
    }

    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _handleValidationChange() {
    if (mounted && widget.validator != null) {
      final currentText = _controller.text;
      final validationResult = widget.validator!(currentText);

      if (_validationMessage != validationResult) {
        setState(() {
          _validationMessage = validationResult;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < ModernTheme.mobileBreakpoint;

        return Semantics(
          label: widget.semanticLabel ?? widget.label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.helperText != null) ...[
                _buildHelperText(context),
                AppSpacing.verticalSpaceXS,
              ],
              _buildTextField(context, isCompact, constraints),
              _buildValidationMessage(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelperText(BuildContext context) {
    return Text(
      widget.helperText!,
      style: TextStyle(
        fontSize: ModernTheme.getResponsiveFontSize(context, 12),
        color: ModernTheme.textSecondary,
      ),
    );
  }

  Widget _buildTextField(BuildContext context, bool isCompact, BoxConstraints constraints) {
    final effectiveBorderRadius = _getBorderRadius();
    final effectiveContentPadding = _getContentPadding(context, isCompact);

    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscureText,
      maxLines: widget.autoExpand ? null : (widget.obscureText ? 1 : widget.maxLines),
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      autocorrect: widget.autocorrect,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.errorText != null ? (_) => widget.errorText : null,
      style: _getTextStyle(context),
      decoration: InputDecoration(
        labelText: _buildLabelText(),
        hintText: widget.hintText,
        prefixIcon: _buildPrefixIcon(context),
        suffixIcon: _buildSuffixIcon(context),
        counterText: widget.showCounter ? null : '',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: _getFillColor(),
        contentPadding: effectiveContentPadding,
        labelStyle: _getLabelStyle(context),
        hintStyle: _getHintStyle(context),
        errorStyle: _getErrorStyle(context),
        counterStyle: _getCounterStyle(context),
        border: _buildBorder(effectiveBorderRadius, Colors.transparent),
        enabledBorder: _buildBorder(effectiveBorderRadius, _getEnabledBorderColor()),
        focusedBorder: _buildBorder(effectiveBorderRadius, _getFocusedBorderColor()),
        errorBorder: _buildBorder(effectiveBorderRadius, ModernTheme.error),
        focusedErrorBorder: _buildBorder(effectiveBorderRadius, ModernTheme.error),
        disabledBorder: _buildBorder(effectiveBorderRadius, _getDisabledBorderColor()),
      ),
    );
  }

  Widget _buildValidationMessage(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _validationMessage != null
          ? Container(
              key: const ValueKey('validation_error'),
              width: double.infinity,
              margin: EdgeInsets.only(top: AppSpacing.xs),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: ModernTheme.error.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusSM,
                border: Border.all(
                  color: ModernTheme.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppSpacing.iconSizeSmall,
                    color: ModernTheme.error,
                  ),
                  AppSpacing.horizontalSpaceXS,
                  Expanded(
                    child: Text(
                      _validationMessage!,
                      style: TextStyle(
                        fontSize: ModernTheme.getResponsiveFontSize(context, 12),
                        color: ModernTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              key: const ValueKey('validation_empty'),
              height: 0,
            ),
    );
  }

  String _buildLabelText() {
    if (widget.isRequired) {
      return '${widget.label} *';
    }
    return widget.label;
  }

  Widget? _buildPrefixIcon(BuildContext context) {
    if (widget.prefixWidget != null) {
      return widget.prefixWidget;
    }

    if (widget.prefixIcon != null) {
      return Icon(
        widget.prefixIcon,
        color: _getPrefixIconColor(),
        size: _getIconSize(context),
      );
    }

    return null;
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: _getSuffixIconColor(),
          size: _getIconSize(context),
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
        tooltip: _obscureText ? 'Mostrar contraseña' : 'Ocultar contraseña',
      );
    }

    return widget.suffixIcon;
  }

  // Métodos helper para estilos responsivos
  BorderRadius _getBorderRadius() {
    if (widget.borderRadius != null) {
      return widget.borderRadius!;
    }

    switch (widget.type) {
      case OasisTextFieldType.standard:
        return AppSpacing.borderRadiusLG;
      case OasisTextFieldType.outlined:
        return AppSpacing.borderRadiusMD;
      case OasisTextFieldType.search:
        return AppSpacing.borderRadiusXXL;
    }
  }

  EdgeInsets _getContentPadding(BuildContext context, bool isCompact) {
    if (widget.contentPadding != null) {
      return widget.contentPadding!;
    }

    // Use passed isCompact value from LayoutBuilder instead of MediaQuery
    final effectiveCompact = widget.compactOnMobile && isCompact;

    switch (widget.size) {
      case OasisTextFieldSize.small:
        return EdgeInsets.symmetric(
          horizontal: effectiveCompact ? AppSpacing.md : AppSpacing.lg,
          vertical: effectiveCompact ? AppSpacing.sm : AppSpacing.md,
        );
      case OasisTextFieldSize.medium:
        return EdgeInsets.symmetric(
          horizontal: effectiveCompact ? AppSpacing.lg : AppSpacing.xl,
          vertical: effectiveCompact ? AppSpacing.md : AppSpacing.lg,
        );
      case OasisTextFieldSize.large:
        return EdgeInsets.symmetric(
          horizontal: effectiveCompact ? AppSpacing.xl : AppSpacing.xxl,
          vertical: effectiveCompact ? AppSpacing.lg : AppSpacing.xl,
        );
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    double fontSize;
    switch (widget.size) {
      case OasisTextFieldSize.small:
        fontSize = ModernTheme.getResponsiveFontSize(context, 14);
        break;
      case OasisTextFieldSize.medium:
        fontSize = ModernTheme.getResponsiveFontSize(context, 16);
        break;
      case OasisTextFieldSize.large:
        fontSize = ModernTheme.getResponsiveFontSize(context, 18);
        break;
    }

    return TextStyle(
      fontSize: fontSize,
      color: ModernTheme.textPrimary,
      fontWeight: FontWeight.w400,
    );
  }

  TextStyle _getLabelStyle(BuildContext context) {
    return TextStyle(
      color: _isFocused ? _getFocusedBorderColor() : ModernTheme.textSecondary,
      fontSize: ModernTheme.getResponsiveFontSize(context, 14),
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _getHintStyle(BuildContext context) {
    return TextStyle(
      color: ModernTheme.textSecondary,
      fontSize: ModernTheme.getResponsiveFontSize(context, 14),
      fontWeight: FontWeight.w400,
    );
  }

  TextStyle _getErrorStyle(BuildContext context) {
    return TextStyle(
      color: ModernTheme.error,
      fontSize: ModernTheme.getResponsiveFontSize(context, 12),
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _getCounterStyle(BuildContext context) {
    return TextStyle(
      color: ModernTheme.textSecondary,
      fontSize: ModernTheme.getResponsiveFontSize(context, 12),
      fontWeight: FontWeight.w400,
    );
  }

  Color _getFillColor() {
    if (widget.fillColor != null) {
      return widget.fillColor!;
    }

    if (!widget.enabled) {
      return ModernTheme.lightGray.withValues(alpha: 0.5);
    }

    if (widget.readOnly) {
      return ModernTheme.lightGray.withValues(alpha: 0.3);
    }

    switch (widget.type) {
      case OasisTextFieldType.standard:
        return ModernTheme.lightGray.withValues(alpha: 0.1);
      case OasisTextFieldType.outlined:
        return Colors.transparent;
      case OasisTextFieldType.search:
        return ModernTheme.lightGray.withValues(alpha: 0.2);
    }
  }

  Color _getEnabledBorderColor() {
    if (widget.borderColor != null) {
      return widget.borderColor!;
    }

    switch (widget.type) {
      case OasisTextFieldType.standard:
        return ModernTheme.borderColor;
      case OasisTextFieldType.outlined:
        return ModernTheme.borderColor;
      case OasisTextFieldType.search:
        return Colors.transparent;
    }
  }

  Color _getFocusedBorderColor() {
    return widget.borderColor ?? ModernTheme.oasisGreen;
  }

  Color _getDisabledBorderColor() {
    return ModernTheme.borderColor.withValues(alpha: 0.5);
  }

  Color _getPrefixIconColor() {
    if (_isFocused) {
      return _getFocusedBorderColor();
    }
    return ModernTheme.textSecondary;
  }

  Color _getSuffixIconColor() {
    return ModernTheme.textSecondary;
  }

  double _getIconSize(BuildContext context) {
    switch (widget.size) {
      case OasisTextFieldSize.small:
        return AppSpacing.iconSizeSmall;
      case OasisTextFieldSize.medium:
        return AppSpacing.iconSizeMedium;
      case OasisTextFieldSize.large:
        return AppSpacing.iconSizeLarge;
    }
  }

  OutlineInputBorder _buildBorder(BorderRadius borderRadius, Color color) {
    return OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: color,
        width: color == Colors.transparent ? 0 : (_isFocused ? 2 : 1),
      ),
    );
  }
}

/// Tipos de campo de texto disponibles
enum OasisTextFieldType {
  /// Campo estándar con fondo
  standard,

  /// Campo solo con outline
  outlined,

  /// Campo de búsqueda con estilo especial
  search,
}

/// Tamaños de campo de texto disponibles
enum OasisTextFieldSize {
  /// Campo pequeño para espacios reducidos
  small,

  /// Campo de tamaño estándar
  medium,

  /// Campo grande para formularios principales
  large,
}

/// Factory methods para crear campos de texto comunes con validación integrada
extension OasisTextFieldFactory on OasisTextField {
  /// Campo de email con validación incorporada
  static Widget email({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool enabled = true,
    bool readOnly = false,
    FocusNode? focusNode,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    OasisTextFieldType type = OasisTextFieldType.standard,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      label: label ?? 'Correo electrónico',
      hintText: hint ?? 'correo@ejemplo.com',
      helperText: helperText,
      prefixIcon: Icons.email_outlined,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidEmail(value)) {
          return ValidationPatterns.getEmailError();
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      size: size,
      type: type,
      autocorrect: false,
    );
  }

  /// Campo de contraseña con validación incorporada
  static Widget password({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool enabled = true,
    bool readOnly = false,
    FocusNode? focusNode,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    OasisTextFieldType type = OasisTextFieldType.standard,
    bool showStrengthIndicator = false,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      label: label ?? 'Contraseña',
      hintText: hint ?? '••••••••',
      helperText: helperText,
      prefixIcon: Icons.lock_outline,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidPassword(value)) {
          return ValidationPatterns.getPasswordError();
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      size: size,
      type: type,
      autocorrect: false,
    );
  }

  /// Campo de teléfono con validación para Perú
  static Widget phone({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool enabled = true,
    bool readOnly = false,
    FocusNode? focusNode,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    OasisTextFieldType type = OasisTextFieldType.standard,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      label: label ?? 'Número de teléfono',
      hintText: hint ?? '987 654 321',
      helperText: helperText,
      prefixIcon: Icons.phone_outlined,
      prefixWidget: Text('+51 ', style: TextStyle(fontSize: 16)),
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty && !ValidationPatterns.isValidPeruMobile(value)) {
          return ValidationPatterns.getPhoneError();
        }
        return null;
      },
      maxLength: 9,
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      size: size,
      type: type,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
    );
  }

  /// Campo de búsqueda
  static Widget search({
    Key? key,
    required TextEditingController controller,
    String? hint,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onClear,
    bool enabled = true,
    FocusNode? focusNode,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      label: 'Buscar',
      hintText: hint ?? 'Buscar...',
      prefixIcon: Icons.search,
      suffixIcon: controller.text.isNotEmpty && onClear != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            )
          : null,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      focusNode: focusNode,
      size: size,
      type: OasisTextFieldType.search,
    );
  }

  /// Campo numérico
  static Widget number({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool enabled = true,
    bool readOnly = false,
    FocusNode? focusNode,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    OasisTextFieldType type = OasisTextFieldType.standard,
    int? maxDigits,
    bool allowDecimals = false,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
      textInputAction: TextInputAction.next,
      label: label ?? 'Número',
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icons.numbers_outlined,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (value != null && value.isNotEmpty) {
          final number = num.tryParse(value);
          if (number == null) {
            return 'Ingresa un número válido';
          }
        }
        return null;
      },
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      size: size,
      type: type,
      inputFormatters: [
        allowDecimals
            ? FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            : FilteringTextInputFormatter.digitsOnly,
        if (maxDigits != null) LengthLimitingTextInputFormatter(maxDigits),
      ],
    );
  }

  /// Campo de texto multilínea
  static Widget multiline({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool enabled = true,
    bool readOnly = false,
    FocusNode? focusNode,
    int maxLines = 5,
    int minLines = 3,
    int? maxLength,
    OasisTextFieldSize size = OasisTextFieldSize.medium,
    OasisTextFieldType type = OasisTextFieldType.outlined,
  }) {
    return OasisTextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      label: label ?? 'Texto',
      hintText: hint,
      helperText: helperText,
      validator: validator ?? (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        return null;
      },
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      size: size,
      type: type,
    );
  }
}
