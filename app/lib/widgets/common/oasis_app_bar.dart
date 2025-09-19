import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';

/// AppBar unificado y responsivo del sistema Oasis
/// Proporciona consistencia visual y funcional en toda la aplicación
class OasisAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título principal del AppBar
  final String title;

  /// Subtítulo opcional para contexto adicional
  final String? subtitle;

  /// Si mostrar el botón de retroceso
  final bool showBackButton;

  /// Acciones personalizadas en la esquina derecha
  final List<Widget>? actions;

  /// Si mostrar el logo de Oasis
  final bool showLogo;

  /// Color de fondo personalizado
  final Color? backgroundColor;

  /// Gradiente de fondo opcional
  final Gradient? backgroundGradient;

  /// Elevación personalizada
  final double? elevation;

  /// Si el AppBar debe ser transparente
  final bool isTransparent;

  /// Color del texto personalizado
  final Color? textColor;

  /// Callback personalizado para el botón de retroceso
  final VoidCallback? onBackPressed;

  /// Widget personalizado para el leading
  final Widget? leading;

  /// Si centrar el título (responsive)
  final bool? centerTitle;

  /// Tipo de AppBar para diferentes contextos
  final OasisAppBarType type;

  /// Si usar altura extendida en pantallas grandes
  final bool useExtendedHeight;

  const OasisAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.actions,
    this.showLogo = true,
    this.backgroundColor,
    this.backgroundGradient,
    this.elevation,
    this.isTransparent = false,
    this.textColor,
    this.onBackPressed,
    this.leading,
    this.centerTitle,
    this.type = OasisAppBarType.standard,
    this.useExtendedHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < ModernTheme.mobileBreakpoint;
        final isLargeScreen = !isCompact;
        final effectiveBackgroundColor = _getBackgroundColor();
        final effectiveTextColor = _getTextColor();
        final effectiveCenterTitle = _shouldCenterTitle(context);
        final effectiveHeight = _getAppBarHeight(context);

        Widget appBar = AppBar(
          backgroundColor: isTransparent ? Colors.transparent : effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          elevation: elevation ?? (isTransparent ? 0 : _getDefaultElevation()),
          centerTitle: effectiveCenterTitle,
          toolbarHeight: effectiveHeight,
          leading: _buildLeading(context, isCompact),
          title: _buildTitle(context, isCompact),
          actions: _buildActions(context, isCompact),
          flexibleSpace: backgroundGradient != null
              ? Container(
                  decoration: BoxDecoration(gradient: backgroundGradient),
                )
              : null,
          systemOverlayStyle: ModernTheme.getSystemOverlayStyle(
            isLightBackground: _isLightBackground(),
          ),
        );

        // Envolver en SafeArea para pantallas móviles
        if (isCompact) {
          return SafeArea(
            top: false,
            child: appBar,
          );
        }

        return appBar;
      },
    );
  }

  Widget? _buildLeading(BuildContext context, bool isCompact) {
    if (leading != null) {
      return leading;
    }

    if (!showBackButton) {
      return null;
    }

    return IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: _getTextColor(),
        size: ModernTheme.getResponsiveIconSize(
          context,
          smallSize: AppSpacing.iconSizeSmall,
          mediumSize: AppSpacing.iconSizeMedium,
          largeSize: AppSpacing.iconSizeLarge,
        ),
      ),
      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      tooltip: 'Regresar',
      splashRadius: AppSpacing.iconSizeLarge,
    );
  }

  Widget _buildTitle(BuildContext context, bool isCompact) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo && !isCompact) ...[
          _buildLogo(context),
          AppSpacing.horizontalSpaceSM,
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: _shouldCenterTitle(context)
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _getTitleStyle(context),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (subtitle != null) ...[
                AppSpacing.verticalSpaceXS,
                Text(
                  subtitle!,
                  style: _getSubtitleStyle(context),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    final logoSize = _getLogoSize(context);

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusSM,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: AppSpacing.xs,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.xs),
      child: Image.asset(
        'assets/images/logo_oasis_taxi.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.local_taxi,
            color: ModernTheme.oasisGreen,
            size: logoSize * 0.6,
          );
        },
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context, bool isCompact) {
    if (actions == null || actions!.isEmpty) {
      return null;
    }

    // En pantallas pequeñas, limitar número de acciones visibles
    if (isCompact && actions!.length > 2) {
      final visibleActions = actions!.take(1).toList();
      visibleActions.add(
        PopupMenuButton<int>(
          icon: Icon(
            Icons.more_vert,
            color: _getTextColor(),
            size: ModernTheme.getResponsiveIconSize(
              context,
              smallSize: AppSpacing.iconSizeSmall,
              mediumSize: AppSpacing.iconSizeMedium,
              largeSize: AppSpacing.iconSizeLarge,
            ),
          ),
          itemBuilder: (context) => actions!
              .skip(1)
              .map((action) => PopupMenuItem<int>(
                    value: actions!.indexOf(action),
                    child: action,
                  ))
              .toList(),
          tooltip: 'Más opciones',
        ),
      );
      return visibleActions;
    }

    return actions;
  }

  // Métodos helper para estilos responsivos
  Color _getBackgroundColor() {
    switch (type) {
      case OasisAppBarType.standard:
        return backgroundColor ?? ModernTheme.oasisGreen;
      case OasisAppBarType.minimal:
        return backgroundColor ?? Colors.transparent;
      case OasisAppBarType.elevated:
        return backgroundColor ?? ModernTheme.cardBackground;
      case OasisAppBarType.gradient:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    if (textColor != null) return textColor!;

    switch (type) {
      case OasisAppBarType.standard:
      case OasisAppBarType.gradient:
        return Colors.white;
      case OasisAppBarType.minimal:
      case OasisAppBarType.elevated:
        return ModernTheme.textPrimary;
    }
  }

  bool _shouldCenterTitle(BuildContext context) {
    if (centerTitle != null) return centerTitle!;

    // En móviles centrar, en desktop alinear a la izquierda
    return !ModernTheme.isLargeScreen(context);
  }

  double _getAppBarHeight(BuildContext context) {
    // Comment 5: Fix AppBar height - mantener altura fija independientemente del subtitle
    // Usar altura más grande que acomode el subtitle sin cambiar altura total
    return useExtendedHeight && ModernTheme.isLargeScreen(context)
        ? AppSpacing.appBarHeightLarge
        : 72.0; // Altura fija que acomoda título y subtítulo
  }

  double _getLogoSize(BuildContext context) {
    final isLarge = ModernTheme.isLargeScreen(context);
    return isLarge ? AppSpacing.iconSizeXLarge : AppSpacing.iconSizeLarge;
  }

  TextStyle _getTitleStyle(BuildContext context) {
    return TextStyle(
      color: _getTextColor(),
      fontSize: ModernTheme.getResponsiveFontSize(context, 18),
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
  }

  TextStyle _getSubtitleStyle(BuildContext context) {
    return TextStyle(
      color: _getTextColor().withValues(alpha: 0.8),
      fontSize: ModernTheme.getResponsiveFontSize(context, 12),
      fontWeight: FontWeight.w500,
    );
  }

  double _getDefaultElevation() {
    switch (type) {
      case OasisAppBarType.standard:
        return 0;
      case OasisAppBarType.minimal:
        return 0;
      case OasisAppBarType.elevated:
        return AppSpacing.elevationMedium;
      case OasisAppBarType.gradient:
        return 0;
    }
  }

  bool _isLightBackground() {
    final bgColor = _getBackgroundColor();
    return bgColor.computeLuminance() > 0.5;
  }

  @override
  Size get preferredSize {
    // Comment 5: Fix AppBar height - mantener altura fija independientemente del subtitle
    // Misma altura que _getAppBarHeight para consistencia
    return Size.fromHeight(
      useExtendedHeight
        ? AppSpacing.appBarHeightLarge
        : 72.0 // Altura fija que acomoda título y subtítulo
    );
  }
}

/// Tipos de AppBar disponibles
enum OasisAppBarType {
  /// AppBar estándar con color de marca
  standard,

  /// AppBar minimalista sin fondo
  minimal,

  /// AppBar elevado con sombra
  elevated,

  /// AppBar con gradiente
  gradient,
}

/// Factory methods para crear AppBars comunes
extension OasisAppBarFactory on OasisAppBar {
  /// AppBar estándar para pantallas principales
  static OasisAppBar standard({
    Key? key,
    required String title,
    String? subtitle,
    bool showBackButton = true,
    List<Widget>? actions,
    bool showLogo = true,
    VoidCallback? onBackPressed,
  }) {
    return OasisAppBar(
      key: key,
      title: title,
      subtitle: subtitle,
      showBackButton: showBackButton,
      actions: actions,
      showLogo: showLogo,
      onBackPressed: onBackPressed,
      type: OasisAppBarType.standard,
    );
  }

  /// AppBar minimalista para pantallas de contenido
  static OasisAppBar minimal({
    Key? key,
    required String title,
    String? subtitle,
    bool showBackButton = true,
    List<Widget>? actions,
    VoidCallback? onBackPressed,
  }) {
    return OasisAppBar(
      key: key,
      title: title,
      subtitle: subtitle,
      showBackButton: showBackButton,
      actions: actions,
      showLogo: false,
      onBackPressed: onBackPressed,
      type: OasisAppBarType.minimal,
      isTransparent: true,
    );
  }

  /// AppBar con gradiente para pantallas especiales
  static OasisAppBar gradient({
    Key? key,
    required String title,
    String? subtitle,
    bool showBackButton = true,
    List<Widget>? actions,
    bool showLogo = true,
    VoidCallback? onBackPressed,
  }) {
    return OasisAppBar(
      key: key,
      title: title,
      subtitle: subtitle,
      showBackButton: showBackButton,
      actions: actions,
      showLogo: showLogo,
      onBackPressed: onBackPressed,
      type: OasisAppBarType.gradient,
      backgroundGradient: ModernTheme.primaryGradient,
    );
  }

  /// AppBar elevado para formularios y modales
  static OasisAppBar elevated({
    Key? key,
    required String title,
    String? subtitle,
    bool showBackButton = true,
    List<Widget>? actions,
    VoidCallback? onBackPressed,
  }) {
    return OasisAppBar(
      key: key,
      title: title,
      subtitle: subtitle,
      showBackButton: showBackButton,
      actions: actions,
      showLogo: false,
      onBackPressed: onBackPressed,
      type: OasisAppBarType.elevated,
    );
  }
}

class OasisDrawerHeader extends StatelessWidget {
  final String userType;
  final String userName;

  const OasisDrawerHeader({
    super.key,
    required this.userType,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo principal
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/logo_oasis_taxi.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback al ícono si la imagen no carga
                        return Icon(
                          Icons.local_taxi,
                          color: ModernTheme.oasisGreen,
                          size: 30,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OASIS TAXI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Tu viaje, tu precio',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Spacer(),
              // Info del usuario
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Icon(
                      _getUserIcon(userType),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getUserTypeLabel(userType),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getUserIcon(String userType) {
    switch (userType) {
      case 'driver':
        return Icons.directions_car;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'driver':
        return 'Conductor';
      case 'admin':
        return 'Administrador';
      default:
        return 'Pasajero';
    }
  }
}
