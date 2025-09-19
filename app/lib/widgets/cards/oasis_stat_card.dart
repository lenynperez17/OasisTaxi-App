import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import 'oasis_card.dart';

/// Card especializado para mostrar estadísticas y métricas
/// Reemplaza implementaciones como _buildStatCard en dashboard screens
class OasisStatCard extends StatelessWidget {
  /// Valor principal de la estadística
  final String value;

  /// Etiqueta descriptiva
  final String label;

  /// Icono opcional
  final IconData? icon;

  /// Color del icono
  final Color? iconColor;

  /// Color de fondo del icono
  final Color? iconBackgroundColor;

  /// Subtítulo opcional
  final String? subtitle;

  /// Indicador de cambio (ej: "+5.2%")
  final String? changeIndicator;

  /// Si el cambio es positivo (verde) o negativo (rojo)
  final bool? isChangePositive;

  /// Callback para tap
  final VoidCallback? onTap;

  /// Tipo de card base
  final OasisCardType cardType;

  /// Tamaño del card
  final OasisStatCardSize size;

  /// Gradiente de fondo opcional
  final Gradient? gradient;

  /// Color personalizado del valor
  final Color? valueColor;

  /// Color personalizado del label
  final Color? labelColor;

  /// Si debe mostrar un indicador de loading
  final bool isLoading;

  /// Si debe mostrar un badge
  final Widget? badge;

  const OasisStatCard({
    Key? key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.subtitle,
    this.changeIndicator,
    this.isChangePositive,
    this.onTap,
    this.cardType = OasisCardType.elevated,
    this.size = OasisStatCardSize.medium,
    this.gradient,
    this.valueColor,
    this.labelColor,
    this.isLoading = false,
    this.badge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OasisCard(
      type: cardType,
      isTappable: onTap != null,
      onTap: onTap,
      gradient: gradient,
      state: isLoading ? OasisCardState.loading : OasisCardState.normal,
      semanticLabel: '$label: $value',
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (size) {
      case OasisStatCardSize.small:
        return _buildSmallContent(context);
      case OasisStatCardSize.medium:
        return _buildMediumContent(context);
      case OasisStatCardSize.large:
        return _buildLargeContent(context);
    }
  }

  Widget _buildSmallContent(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          _buildIcon(context, AppSpacing.iconSizeMedium),
          AppSpacing.horizontalSpaceSM,
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildValue(context, 18),
              _buildLabel(context, 12),
            ],
          ),
        ),
        if (badge != null) badge!,
      ],
    );
  }

  Widget _buildMediumContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              _buildIcon(context, AppSpacing.iconSizeLarge),
              AppSpacing.horizontalSpaceMD,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildValue(context, 24),
                  _buildLabel(context, 14),
                ],
              ),
            ),
            if (badge != null) badge!,
          ],
        ),
        if (subtitle != null || changeIndicator != null) ...[
          AppSpacing.verticalSpaceSM,
          _buildBottomContent(context),
        ],
      ],
    );
  }

  Widget _buildLargeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          _buildIcon(context, AppSpacing.iconSizeXLarge),
          AppSpacing.verticalSpaceMD,
        ],
        _buildValue(context, 32),
        AppSpacing.verticalSpaceXS,
        _buildLabel(context, 16),
        if (subtitle != null) ...[
          AppSpacing.verticalSpaceXS,
          _buildSubtitle(context),
        ],
        if (changeIndicator != null) ...[
          AppSpacing.verticalSpaceSM,
          _buildChangeIndicator(context),
        ],
        if (badge != null) ...[
          AppSpacing.verticalSpaceSM,
          badge!,
        ],
      ],
    );
  }

  Widget _buildIcon(BuildContext context, double size) {
    final effectiveIconColor = iconColor ?? ModernTheme.oasisGreen;

    if (iconBackgroundColor != null) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        child: Icon(
          icon!,
          size: size,
          color: effectiveIconColor,
        ),
      );
    }

    return Icon(
      icon!,
      size: size,
      color: effectiveIconColor,
    );
  }

  Widget _buildValue(BuildContext context, double baseFontSize) {
    return Text(
      value,
      style: TextStyle(
        fontSize: ModernTheme.getResponsiveFontSize(context, baseFontSize),
        fontWeight: FontWeight.bold,
        color: valueColor ?? ModernTheme.textPrimary,
      ),
    );
  }

  Widget _buildLabel(BuildContext context, double baseFontSize) {
    return Text(
      label,
      style: TextStyle(
        fontSize: ModernTheme.getResponsiveFontSize(context, baseFontSize),
        color: labelColor ?? ModernTheme.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Text(
      subtitle!,
      style: TextStyle(
        fontSize: ModernTheme.getResponsiveFontSize(context, 12),
        color: ModernTheme.textSecondary,
      ),
    );
  }

  Widget _buildChangeIndicator(BuildContext context) {
    final isPositive = isChangePositive ?? true;
    final color = isPositive ? ModernTheme.success : ModernTheme.error;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppSpacing.iconSizeSmall,
          color: color,
        ),
        AppSpacing.horizontalSpaceXS,
        Text(
          changeIndicator!,
          style: TextStyle(
            fontSize: ModernTheme.getResponsiveFontSize(context, 12),
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomContent(BuildContext context) {
    return Row(
      children: [
        if (subtitle != null) ...[
          Expanded(child: _buildSubtitle(context)),
        ],
        if (changeIndicator != null) ...[
          _buildChangeIndicator(context),
        ],
      ],
    );
  }
}

/// Tamaños disponibles para el stat card
enum OasisStatCardSize {
  small,
  medium,
  large,
}

/// Factory methods para crear stat cards comunes
extension OasisStatCardFactory on OasisStatCard {
  /// Card de estadística de viajes
  static Widget trips({
    Key? key,
    required String count,
    String? subtitle,
    String? changeIndicator,
    bool? isChangePositive,
    VoidCallback? onTap,
    OasisStatCardSize size = OasisStatCardSize.medium,
  }) {
    return OasisStatCard(
      key: key,
      value: count,
      label: 'Viajes',
      icon: Icons.local_taxi,
      iconColor: ModernTheme.oasisGreen,
      iconBackgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.1),
      subtitle: subtitle,
      changeIndicator: changeIndicator,
      isChangePositive: isChangePositive,
      onTap: onTap,
      size: size,
    );
  }

  /// Card de estadística de ganancias
  static Widget earnings({
    Key? key,
    required String amount,
    String? subtitle,
    String? changeIndicator,
    bool? isChangePositive,
    VoidCallback? onTap,
    OasisStatCardSize size = OasisStatCardSize.medium,
  }) {
    return OasisStatCard(
      key: key,
      value: amount,
      label: 'Ganancias',
      icon: Icons.attach_money,
      iconColor: ModernTheme.success,
      iconBackgroundColor: ModernTheme.success.withValues(alpha: 0.1),
      subtitle: subtitle,
      changeIndicator: changeIndicator,
      isChangePositive: isChangePositive,
      onTap: onTap,
      size: size,
    );
  }

  /// Card de estadística de rating
  static Widget rating({
    Key? key,
    required String rating,
    String? subtitle,
    VoidCallback? onTap,
    OasisStatCardSize size = OasisStatCardSize.medium,
  }) {
    return OasisStatCard(
      key: key,
      value: rating,
      label: 'Calificación',
      icon: Icons.star,
      iconColor: ModernTheme.accentYellow,
      iconBackgroundColor: ModernTheme.accentYellow.withValues(alpha: 0.1),
      subtitle: subtitle,
      onTap: onTap,
      size: size,
    );
  }

  /// Card de estadística de usuarios
  static Widget users({
    Key? key,
    required String count,
    String? subtitle,
    String? changeIndicator,
    bool? isChangePositive,
    VoidCallback? onTap,
    OasisStatCardSize size = OasisStatCardSize.medium,
  }) {
    return OasisStatCard(
      key: key,
      value: count,
      label: 'Usuarios',
      icon: Icons.people,
      iconColor: ModernTheme.primaryBlue,
      iconBackgroundColor: ModernTheme.primaryBlue.withValues(alpha: 0.1),
      subtitle: subtitle,
      changeIndicator: changeIndicator,
      isChangePositive: isChangePositive,
      onTap: onTap,
      size: size,
    );
  }

  /// Card de estadística de tiempo
  static Widget time({
    Key? key,
    required String duration,
    String? subtitle,
    VoidCallback? onTap,
    OasisStatCardSize size = OasisStatCardSize.medium,
  }) {
    return OasisStatCard(
      key: key,
      value: duration,
      label: 'Tiempo',
      icon: Icons.access_time,
      iconColor: ModernTheme.textSecondary,
      iconBackgroundColor: ModernTheme.textSecondary.withValues(alpha: 0.1),
      subtitle: subtitle,
      onTap: onTap,
      size: size,
    );
  }
}