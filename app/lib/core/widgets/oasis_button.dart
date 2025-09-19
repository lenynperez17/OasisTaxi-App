import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../theme/modern_theme.dart';
import '../constants/app_spacing.dart';

/// Botón unificado y responsivo del sistema Oasis
/// Proporciona consistencia visual y funcional en toda la aplicación
class OasisButton extends StatefulWidget {
  /// Texto del botón
  final String text;

  /// Callback cuando se presiona el botón
  final VoidCallback? onPressed;

  /// Estado de loading
  final bool isLoading;

  /// Icono opcional del botón
  final Widget? icon;

  /// Tipo de botón
  final OasisButtonType type;

  /// Tamaño del botón
  final OasisButtonSize size;

  /// Ancho del botón
  final double? width;

  /// Color personalizado de fondo
  final Color? backgroundColor;

  /// Color personalizado del texto
  final Color? textColor;

  /// Gradiente de fondo opcional
  final Gradient? gradient;

  /// Si el botón debe expandirse al ancho completo
  final bool expandWidth;

  /// Widget personalizado de loading
  final Widget? loadingWidget;

  /// Callback para long press
  final VoidCallback? onLongPress;

  /// Si habilitar efectos de Material
  final bool enableMaterialEffects;

  /// Border radius personalizado
  final BorderRadius? borderRadius;

  /// Semantic label para accesibilidad
  final String? semanticLabel;

  /// Si el botón debe ser compacto en pantallas pequeñas
  final bool compactOnMobile;

  /// Comment 6: Habilitar retroalimentación háptica (opt-in)
  final bool enableHapticFeedback;

  const OasisButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.type = OasisButtonType.primary,
    this.size = OasisButtonSize.medium,
    this.width,
    this.backgroundColor,
    this.textColor,
    this.gradient,
    this.expandWidth = true,
    this.loadingWidget,
    this.onLongPress,
    this.enableMaterialEffects = true,
    this.borderRadius,
    this.semanticLabel,
    this.compactOnMobile = false,
    this.enableHapticFeedback = false, // Opt-in por defecto
  });

  @override
  State<OasisButton> createState() => _OasisButtonState();

  // Factory methods mejorados
  factory OasisButton.primary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    OasisButtonSize size = OasisButtonSize.medium,
    double? width,
    bool expandWidth = true,
    VoidCallback? onLongPress,
    String? semanticLabel,
    bool compactOnMobile = false,
    bool enableHapticFeedback = false,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: OasisButtonType.primary,
      size: size,
      width: width,
      expandWidth: expandWidth,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      compactOnMobile: compactOnMobile,
      enableHapticFeedback: enableHapticFeedback,
    );
  }

  factory OasisButton.secondary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    OasisButtonSize size = OasisButtonSize.medium,
    double? width,
    bool expandWidth = true,
    VoidCallback? onLongPress,
    String? semanticLabel,
    bool compactOnMobile = false,
    bool enableHapticFeedback = false,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: OasisButtonType.secondary,
      size: size,
      width: width,
      expandWidth: expandWidth,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      compactOnMobile: compactOnMobile,
      enableHapticFeedback: enableHapticFeedback,
    );
  }

  factory OasisButton.outlined({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    OasisButtonSize size = OasisButtonSize.medium,
    double? width,
    bool expandWidth = true,
    VoidCallback? onLongPress,
    String? semanticLabel,
    bool compactOnMobile = false,
    bool enableHapticFeedback = false,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: OasisButtonType.outlined,
      size: size,
      width: width,
      expandWidth: expandWidth,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      compactOnMobile: compactOnMobile,
      enableHapticFeedback: enableHapticFeedback,
    );
  }

  factory OasisButton.text({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    OasisButtonSize size = OasisButtonSize.medium,
    double? width,
    bool expandWidth = false,
    VoidCallback? onLongPress,
    String? semanticLabel,
    bool compactOnMobile = false,
    bool enableHapticFeedback = false,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: OasisButtonType.text,
      size: size,
      width: width,
      expandWidth: expandWidth,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      compactOnMobile: compactOnMobile,
      enableHapticFeedback: enableHapticFeedback,
    );
  }

  factory OasisButton.gradient({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    OasisButtonSize size = OasisButtonSize.medium,
    double? width,
    bool expandWidth = true,
    VoidCallback? onLongPress,
    String? semanticLabel,
    bool compactOnMobile = false,
    bool enableHapticFeedback = false,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: OasisButtonType.gradient,
      size: size,
      width: width,
      expandWidth: expandWidth,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      compactOnMobile: compactOnMobile,
      gradient: ModernTheme.primaryGradient,
    );
  }
}

class _OasisButtonState extends State<OasisButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppSpacing.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveSize = _getButtonSize(context, constraints);
        final effectiveBorderRadius = _getBorderRadius();

    return Semantics(
      label: widget.semanticLabel ?? widget.text,
      button: true,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildButtonByType(context, effectiveSize, effectiveBorderRadius),
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildButtonByType(BuildContext context, Size size, BorderRadius borderRadius) {
    final child = _buildButtonContent(context);

    switch (widget.type) {
      case OasisButtonType.primary:
        return _buildPrimaryButton(context, size, borderRadius, child);
      case OasisButtonType.secondary:
        return _buildSecondaryButton(context, size, borderRadius, child);
      case OasisButtonType.outlined:
        return _buildOutlinedButton(context, size, borderRadius, child);
      case OasisButtonType.text:
        return _buildTextButton(context, size, borderRadius, child);
      case OasisButtonType.gradient:
        return _buildGradientButton(context, size, borderRadius, child);
      case OasisButtonType.danger:
        return _buildDangerButton(context, size, borderRadius, child);
    }
  }

  // Comment 4: Helper for uniform haptic feedback across all button types
  VoidCallback? _withHaptics(VoidCallback? original) {
    if (original == null) return null;
    return () {
      if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
      original();
    };
  }

  Widget _buildPrimaryButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : _withHaptics(widget.onPressed),
      onLongPress: _withHaptics(widget.onLongPress),
      style: ElevatedButton.styleFrom(
        minimumSize: size,
        backgroundColor: widget.backgroundColor ?? ModernTheme.oasisGreen,
        foregroundColor: widget.textColor ?? Colors.white,
        disabledBackgroundColor: (widget.backgroundColor ?? ModernTheme.oasisGreen).withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: _getTextStyle(context),
        padding: _getButtonPadding(context),
      ),
      child: child,
    );
  }

  Widget _buildSecondaryButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : _withHaptics(widget.onPressed),
      onLongPress: _withHaptics(widget.onLongPress),
      style: ElevatedButton.styleFrom(
        minimumSize: size,
        backgroundColor: widget.backgroundColor ?? ModernTheme.textSecondary,
        foregroundColor: widget.textColor ?? Colors.white,
        disabledBackgroundColor: (widget.backgroundColor ?? ModernTheme.textSecondary).withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: _getTextStyle(context),
        padding: _getButtonPadding(context),
      ),
      child: child,
    );
  }

  Widget _buildOutlinedButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    final borderColor = widget.backgroundColor ?? ModernTheme.oasisGreen;

    return OutlinedButton(
      onPressed: widget.isLoading ? null : _withHaptics(widget.onPressed),
      onLongPress: _withHaptics(widget.onLongPress),
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        side: BorderSide(color: borderColor, width: 2),
        foregroundColor: widget.textColor ?? borderColor,
        backgroundColor: Colors.transparent,
        disabledForegroundColor: borderColor.withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: _getTextStyle(context),
        padding: _getButtonPadding(context),
      ),
      child: child,
    );
  }

  Widget _buildTextButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    return TextButton(
      onPressed: widget.isLoading ? null : _withHaptics(widget.onPressed),
      onLongPress: _withHaptics(widget.onLongPress),
      style: TextButton.styleFrom(
        minimumSize: size,
        foregroundColor: widget.textColor ?? ModernTheme.oasisGreen,
        backgroundColor: Colors.transparent,
        disabledForegroundColor: (widget.textColor ?? ModernTheme.oasisGreen).withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: _getTextStyle(context).copyWith(fontWeight: FontWeight.w500),
        padding: _getButtonPadding(context),
      ),
      child: child,
    );
  }

  Widget _buildGradientButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    return SizedBox(
      width: widget.expandWidth ? double.infinity : size.width,
      height: size.height,
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: borderRadius,
        ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : _withHaptics(widget.onPressed),
          onLongPress: _withHaptics(widget.onLongPress),
          onTapDown: widget.enableMaterialEffects ? _handleTapDownNoHaptic : null,
          onTapUp: widget.enableMaterialEffects ? _handleTapUp : null,
          onTapCancel: widget.enableMaterialEffects ? _handleTapCancel : null,
          borderRadius: borderRadius,
          child: Container(
            alignment: Alignment.center,
            padding: _getButtonPadding(context),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDangerButton(BuildContext context, Size size, BorderRadius borderRadius, Widget child) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : _withHaptics(widget.onPressed),
      onLongPress: _withHaptics(widget.onLongPress),
      style: ElevatedButton.styleFrom(
        minimumSize: size,
        backgroundColor: widget.backgroundColor ?? ModernTheme.error,
        foregroundColor: widget.textColor ?? Colors.white,
        disabledBackgroundColor: (widget.backgroundColor ?? ModernTheme.error).withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: _getTextStyle(context),
        padding: _getButtonPadding(context),
      ),
      child: child,
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    final iconSize = _getIconSize(context);
    final spacing = _getContentSpacing(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          widget.loadingWidget ?? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLoadingColor(context),
              ),
            ),
          ),
          SizedBox(width: spacing),
        ] else if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(
              size: iconSize,
              color: _getIconColor(context),
            ),
            child: widget.icon!,
          ),
          SizedBox(width: spacing),
        ],
        Flexible(
          child: Text(
            widget.text,
            style: _getTextStyle(context).copyWith(
              color: _getTextColorForContent(context),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // Métodos helper para responsive design
  Size _getButtonSize(BuildContext context, BoxConstraints constraints) {
    final isCompact = widget.compactOnMobile && constraints.maxWidth < ModernTheme.mobileBreakpoint;

    double height;
    switch (widget.size) {
      case OasisButtonSize.small:
        height = isCompact ? AppSpacing.buttonHeightSmall - 4 : AppSpacing.buttonHeightSmall;
        break;
      case OasisButtonSize.medium:
        height = isCompact ? AppSpacing.buttonHeight - 8 : AppSpacing.buttonHeight;
        break;
      case OasisButtonSize.large:
        height = isCompact ? AppSpacing.buttonHeight : AppSpacing.buttonHeightLarge;
        break;
    }

    double width;
    if (widget.width != null) {
      width = widget.width!;
    } else if (widget.expandWidth) {
      width = double.infinity;
    } else {
      width = widget.type == OasisButtonType.text ? 0 : AppSpacing.minButtonWidth;
    }

    // Asegurar altura mínima de touch target (48px)
    final finalHeight = math.max(height, AppSpacing.minTouchTarget);

    return Size(width, finalHeight);
  }

  BorderRadius _getBorderRadius() {
    if (widget.borderRadius != null) {
      return widget.borderRadius!;
    }

    switch (widget.type) {
      case OasisButtonType.text:
        return AppSpacing.borderRadiusSM;
      default:
        return AppSpacing.borderRadiusLG;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    double fontSize;
    switch (widget.size) {
      case OasisButtonSize.small:
        fontSize = ModernTheme.getResponsiveFontSize(context, 14);
        break;
      case OasisButtonSize.medium:
        fontSize = ModernTheme.getResponsiveFontSize(context, 16);
        break;
      case OasisButtonSize.large:
        fontSize = ModernTheme.getResponsiveFontSize(context, 18);
        break;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  EdgeInsets _getButtonPadding(BuildContext context) {
    final isCompact = widget.compactOnMobile && ModernTheme.isCompactScreen(context);

    switch (widget.size) {
      case OasisButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
          vertical: AppSpacing.xs,
        );
      case OasisButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
          vertical: AppSpacing.sm,
        );
      case OasisButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.lg : AppSpacing.xl,
          vertical: AppSpacing.md,
        );
    }
  }

  double _getIconSize(BuildContext context) {
    // Comment 1: Use ModernTheme.getResponsiveIconSize for consistent sizing across breakpoints
    switch (widget.size) {
      case OasisButtonSize.small:
        return ModernTheme.getResponsiveIconSize(
          context,
          smallSize: AppSpacing.iconSizeSmall * 0.9,
          mediumSize: AppSpacing.iconSizeSmall,
          largeSize: AppSpacing.iconSizeSmall * 1.1,
        );
      case OasisButtonSize.medium:
        return ModernTheme.getResponsiveIconSize(
          context,
          smallSize: AppSpacing.iconSizeMedium * 0.9,
          mediumSize: AppSpacing.iconSizeMedium,
          largeSize: AppSpacing.iconSizeMedium * 1.1,
        );
      case OasisButtonSize.large:
        return ModernTheme.getResponsiveIconSize(
          context,
          smallSize: AppSpacing.iconSizeLarge * 0.9,
          mediumSize: AppSpacing.iconSizeLarge,
          largeSize: AppSpacing.iconSizeLarge * 1.1,
        );
    }
  }

  double _getContentSpacing(BuildContext context) {
    switch (widget.size) {
      case OasisButtonSize.small:
        return AppSpacing.xs;
      case OasisButtonSize.medium:
        return AppSpacing.sm;
      case OasisButtonSize.large:
        return AppSpacing.md;
    }
  }

  Color _getLoadingColor(BuildContext context) {
    switch (widget.type) {
      case OasisButtonType.primary:
      case OasisButtonType.secondary:
      case OasisButtonType.gradient:
      case OasisButtonType.danger:
        return Colors.white;
      case OasisButtonType.outlined:
      case OasisButtonType.text:
        return widget.textColor ?? ModernTheme.oasisGreen;
    }
  }

  Color _getIconColor(BuildContext context) {
    return _getTextColorForContent(context);
  }

  Color _getTextColorForContent(BuildContext context) {
    if (widget.textColor != null) return widget.textColor!;

    switch (widget.type) {
      case OasisButtonType.primary:
      case OasisButtonType.secondary:
      case OasisButtonType.gradient:
      case OasisButtonType.danger:
        return Colors.white;
      case OasisButtonType.outlined:
      case OasisButtonType.text:
        return widget.backgroundColor ?? ModernTheme.oasisGreen;
    }
  }

  // Comment 4: Renamed to avoid double-triggering haptics for gradient button
  void _handleTapDownNoHaptic(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();

    // Comment 6: Haptic feedback condicional (opt-in)
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapRelease();
  }

  void _handleTapCancel() {
    _handleTapRelease();
  }

  void _handleTapRelease() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }
}

/// Tipos de botón disponibles
enum OasisButtonType {
  /// Botón principal con color de marca
  primary,

  /// Botón secundario
  secondary,

  /// Botón con outline
  outlined,

  /// Botón de solo texto
  text,

  /// Botón con gradiente
  gradient,

  /// Botón de peligro/error
  danger,
}

/// Tamaños de botón disponibles
enum OasisButtonSize {
  /// Botón pequeño para espacios reducidos
  small,

  /// Botón de tamaño estándar
  medium,

  /// Botón grande para acciones principales
  large,
}
