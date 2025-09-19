import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';

/// Tipos de card disponibles en el sistema Oasis
enum OasisCardType {
  elevated,
  outlined,
  filled,
}

/// Estados del card
enum OasisCardState {
  normal,
  loading,
  error,
  disabled,
}

/// Componente base OasisCard - Sistema unificado de tarjetas
/// Reemplaza todas las implementaciones custom de cards en la app
class OasisCard extends StatefulWidget {
  /// Contenido principal del card
  final Widget child;

  /// Tipo de card (elevado, outlined, etc.)
  final OasisCardType type;

  /// Estado actual del card
  final OasisCardState state;

  /// Padding interno del card
  final EdgeInsets? padding;

  /// Margin externo del card
  final EdgeInsets? margin;

  /// Altura específica del card
  final double? height;

  /// Ancho específico del card
  final double? width;

  /// Color de fondo personalizado
  final Color? backgroundColor;

  /// Border radius personalizado
  final BorderRadius? borderRadius;

  /// Elevación personalizada
  final double? elevation;

  /// Callback para tap
  final VoidCallback? onTap;

  /// Callback para long press
  final VoidCallback? onLongPress;

  /// Si el card es tappeable (añade efectos visuales)
  final bool isTappable;

  /// Widget a mostrar en estado de loading
  final Widget? loadingWidget;

  /// Widget a mostrar en estado de error
  final Widget? errorWidget;

  /// Mensaje de error
  final String? errorMessage;

  /// Si debe usar efectos de Material (splash, etc.)
  final bool useMaterialEffects;

  /// Gradiente de fondo
  final Gradient? gradient;

  /// Border personalizado
  final Border? border;

  /// Clip behavior
  final Clip clipBehavior;

  /// Semantic label para accesibilidad
  final String? semanticLabel;

  const OasisCard({
    Key? key,
    required this.child,
    this.type = OasisCardType.elevated,
    this.state = OasisCardState.normal,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.backgroundColor,
    this.borderRadius,
    this.elevation,
    this.onTap,
    this.onLongPress,
    this.isTappable = false,
    this.loadingWidget,
    this.errorWidget,
    this.errorMessage,
    this.useMaterialEffects = true,
    this.gradient,
    this.border,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
  }) : super(key: key);

  @override
  State<OasisCard> createState() => _OasisCardState();
}

class _OasisCardState extends State<OasisCard>
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
      end: 0.98,
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
        final isCompact = constraints.maxWidth < ModernTheme.mobileBreakpoint;

        return Semantics(
          label: widget.semanticLabel,
          button: widget.isTappable,
          child: Container(
            margin: widget.margin ?? AppSpacing.cardMarginAll,
            height: widget.height,
            width: widget.width,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildCard(context, isCompact),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, bool isCompact) {
    final cardChild = _buildCardContent(context, isCompact);

    if (widget.isTappable && widget.useMaterialEffects) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: widget.onLongPress,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          borderRadius: _getBorderRadius(context, isCompact),
          child: cardChild,
        ),
      );
    } else if (widget.isTappable) {
      return GestureDetector(
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: cardChild,
      );
    }

    return cardChild;
  }

  Widget _buildCardContent(BuildContext context, bool isCompact) {
    return Container(
      decoration: _getCardDecoration(context, isCompact),
      clipBehavior: widget.clipBehavior,
      child: _buildContentByState(context, isCompact),
    );
  }

  Widget _buildContentByState(BuildContext context, bool isCompact) {
    switch (widget.state) {
      case OasisCardState.loading:
        return _buildLoadingState(context, isCompact);
      case OasisCardState.error:
        return _buildErrorState(context, isCompact);
      case OasisCardState.disabled:
        return _buildDisabledState(context, isCompact);
      case OasisCardState.normal:
      default:
        return _buildNormalState(context, isCompact);
    }
  }

  Widget _buildNormalState(BuildContext context, bool isCompact) {
    return Padding(
      padding: _getPadding(context, isCompact),
      child: widget.child,
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isCompact) {
    return Padding(
      padding: _getPadding(context, isCompact),
      child: widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
            ),
          ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isCompact) {
    return Padding(
      padding: _getPadding(context, isCompact),
      child: widget.errorWidget ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: ModernTheme.error,
                size: AppSpacing.iconSizeLarge,
              ),
              if (widget.errorMessage != null) ...[
                AppSpacing.verticalSpaceSM,
                Text(
                  widget.errorMessage!,
                  style: TextStyle(
                    color: ModernTheme.error,
                    fontSize: ModernTheme.getResponsiveFontSize(context, 14),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildDisabledState(BuildContext context, bool isCompact) {
    return Padding(
      padding: _getPadding(context, isCompact),
      child: Opacity(
        opacity: 0.5,
        child: widget.child,
      ),
    );
  }

  BoxDecoration _getCardDecoration(BuildContext context, bool isCompact) {
    switch (widget.type) {
      case OasisCardType.elevated:
        return _getElevatedCardDecoration(context, isCompact);
      case OasisCardType.outlined:
        return _getOutlinedCardDecoration(context, isCompact);
      case OasisCardType.filled:
        return _getFilledCardDecoration(context, isCompact);
    }
  }

  BoxDecoration _getElevatedCardDecoration(BuildContext context, bool isCompact) {
    // Comment 1: Use ModernTheme.getCardShadows(context) for elevated shadows
    List<BoxShadow>? shadows;

    if (widget.state != OasisCardState.disabled) {
      if (widget.elevation != null) {
        // Custom elevation provided - compute compatible shadow
        final computedElevation = ModernTheme.getAdaptiveElevation(
          context,
          mobileElevation: widget.elevation!,
          tabletElevation: widget.elevation! + 2,
          desktopElevation: widget.elevation! + 6,
        );
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: computedElevation * 2.5,
            offset: Offset(0, computedElevation),
            spreadRadius: 0,
          ),
        ];
      } else {
        // Use default responsive shadows from ModernTheme
        shadows = ModernTheme.getCardShadows(context);
      }
    }

    return BoxDecoration(
      color: widget.backgroundColor ?? ModernTheme.cardBackground,
      borderRadius: _getBorderRadius(context, isCompact),
      border: widget.border,
      gradient: widget.gradient,
      boxShadow: shadows,
    );
  }

  BoxDecoration _getOutlinedCardDecoration(BuildContext context, bool isCompact) {
    return BoxDecoration(
      color: widget.backgroundColor ?? Colors.transparent,
      borderRadius: _getBorderRadius(context, isCompact),
      border: widget.border ??
          Border.all(
            color: ModernTheme.borderColor,
            width: 1.0,
          ),
      gradient: widget.gradient,
    );
  }

  BoxDecoration _getFilledCardDecoration(BuildContext context, bool isCompact) {
    return BoxDecoration(
      color: widget.backgroundColor ?? ModernTheme.lightGray,
      borderRadius: _getBorderRadius(context, isCompact),
      border: widget.border,
      gradient: widget.gradient,
    );
  }

  BorderRadius _getBorderRadius(BuildContext context, bool isCompact) {
    // Use smaller border radius for compact screens
    return widget.borderRadius ?? (isCompact ? AppSpacing.borderRadiusMD : AppSpacing.borderRadiusLG);
  }

  EdgeInsets _getPadding(BuildContext context, bool isCompact) {
    // Use 16px padding for compact screens, 24px for large
    return widget.padding ??
        EdgeInsets.all(isCompact ? 16 : 24);
  }

  void _handleTap() {
    if (widget.state != OasisCardState.disabled && widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.state != OasisCardState.disabled) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
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
      setState(() {
        _isPressed = false;
      });
      _animationController.reverse();
    }
  }
}

/// Factory methods para crear cards comunes
extension OasisCardFactory on OasisCard {
  /// Card elevado estándar
  static Widget elevated({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? height,
    double? width,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return OasisCard(
      key: key,
      type: OasisCardType.elevated,
      isTappable: onTap != null,
      onTap: onTap,
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// Card con outline
  static Widget outlined({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? height,
    double? width,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return OasisCard(
      key: key,
      type: OasisCardType.outlined,
      isTappable: onTap != null,
      onTap: onTap,
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// Card relleno
  static Widget filled({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? height,
    double? width,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return OasisCard(
      key: key,
      type: OasisCardType.filled,
      isTappable: onTap != null,
      onTap: onTap,
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}