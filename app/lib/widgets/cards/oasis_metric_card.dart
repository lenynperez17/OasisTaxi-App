import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import 'oasis_card.dart';

/// Card especializado para mostrar métricas y KPIs con gráficos
/// Reemplaza implementaciones como _buildMetricCard en analytics screens
class OasisMetricCard extends StatelessWidget {
  /// Título principal de la métrica
  final String title;

  /// Valor actual de la métrica
  final String value;

  /// Unidad de medida (ej: "%", "min", "S/")
  final String? unit;

  /// Subtítulo descriptivo
  final String? subtitle;

  /// Porcentaje de cambio
  final double? changePercentage;

  /// Período de comparación (ej: "vs. mes anterior")
  final String? comparisonPeriod;

  /// Widget de gráfico o visualización
  final Widget? chart;

  /// Color principal de la métrica
  final Color? primaryColor;

  /// Icono de la métrica
  final IconData? icon;

  /// Callback para tap
  final VoidCallback? onTap;

  /// Tamaño del card
  final OasisMetricCardSize size;

  /// Si mostrar el indicador de tendencia
  final bool showTrend;

  /// Datos adicionales para mostrar
  final List<OasisMetricData>? additionalData;

  /// Estado de loading
  final bool isLoading;

  /// Color de fondo del header
  final Color? headerBackgroundColor;

  /// Si el card debe expandirse para ocupar el ancho completo
  final bool expandWidth;

  const OasisMetricCard({
    Key? key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.changePercentage,
    this.comparisonPeriod,
    this.chart,
    this.primaryColor,
    this.icon,
    this.onTap,
    this.size = OasisMetricCardSize.medium,
    this.showTrend = true,
    this.additionalData,
    this.isLoading = false,
    this.headerBackgroundColor,
    this.expandWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expandWidth ? double.infinity : null,
      child: OasisCard(
        type: OasisCardType.elevated,
        isTappable: onTap != null,
        onTap: onTap,
        state: isLoading ? OasisCardState.loading : OasisCardState.normal,
        padding: EdgeInsets.zero,
        semanticLabel: '$title: $value${unit ?? ''}',
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        if (chart != null) _buildChart(context),
        if (additionalData != null && additionalData!.isNotEmpty)
          _buildAdditionalData(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
      decoration: headerBackgroundColor != null
          ? BoxDecoration(
              color: headerBackgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusLG),
                topRight: Radius.circular(AppSpacing.radiusLG),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTop(context),
          AppSpacing.verticalSpaceMD,
          _buildMainValue(context),
          if (subtitle != null) ...[
            AppSpacing.verticalSpaceXS,
            _buildSubtitle(context),
          ],
          if (showTrend && changePercentage != null) ...[
            AppSpacing.verticalSpaceSM,
            _buildTrend(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderTop(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: (primaryColor ?? ModernTheme.oasisGreen)
                  .withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Icon(
              icon!,
              size: AppSpacing.iconSizeMedium,
              color: primaryColor ?? ModernTheme.oasisGreen,
            ),
          ),
          AppSpacing.horizontalSpaceSM,
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: ModernTheme.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: ModernTheme.textSecondary,
            ),
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios,
            size: AppSpacing.iconSizeSmall,
            color: ModernTheme.textSecondary,
          ),
      ],
    );
  }

  Widget _buildMainValue(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: _getValueFontSize(context),
            fontWeight: FontWeight.bold,
            color: primaryColor ?? ModernTheme.textPrimary,
          ),
        ),
        if (unit != null) ...[
          AppSpacing.horizontalSpaceXS,
          Text(
            unit!,
            style: TextStyle(
              fontSize: ModernTheme.getResponsiveFontSize(context, 16),
              color: ModernTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
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

  Widget _buildTrend(BuildContext context) {
    final isPositive = changePercentage! >= 0;
    final color = isPositive ? ModernTheme.success : ModernTheme.error;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppSpacing.borderRadiusSM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppSpacing.iconSizeSmall,
                color: color,
              ),
              AppSpacing.horizontalSpaceXS,
              Text(
                '${changePercentage!.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: ModernTheme.getResponsiveFontSize(context, 12),
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (comparisonPeriod != null) ...[
          AppSpacing.horizontalSpaceSM,
          Text(
            comparisonPeriod!,
            style: TextStyle(
              fontSize: ModernTheme.getResponsiveFontSize(context, 11),
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ModernTheme.getResponsivePadding(context),
        vertical: AppSpacing.md,
      ),
      child: chart!,
    );
  }

  Widget _buildAdditionalData(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ModernTheme.borderColor,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: additionalData!
            .map((data) => _buildAdditionalDataItem(context, data))
            .toList(),
      ),
    );
  }

  Widget _buildAdditionalDataItem(BuildContext context, OasisMetricData data) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          if (data.color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: data.color,
                shape: BoxShape.circle,
              ),
            ),
            AppSpacing.horizontalSpaceSM,
          ],
          Expanded(
            child: Text(
              data.label,
              style: TextStyle(
                fontSize: ModernTheme.getResponsiveFontSize(context, 12),
                color: ModernTheme.textSecondary,
              ),
            ),
          ),
          Text(
            data.value,
            style: TextStyle(
              fontSize: ModernTheme.getResponsiveFontSize(context, 12),
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  double _getValueFontSize(BuildContext context) {
    switch (size) {
      case OasisMetricCardSize.small:
        return ModernTheme.getResponsiveFontSize(context, 20);
      case OasisMetricCardSize.medium:
        return ModernTheme.getResponsiveFontSize(context, 28);
      case OasisMetricCardSize.large:
        return ModernTheme.getResponsiveFontSize(context, 36);
    }
  }
}

/// Tamaños disponibles para el metric card
enum OasisMetricCardSize {
  small,
  medium,
  large,
}

/// Datos adicionales para mostrar en el metric card
class OasisMetricData {
  final String label;
  final String value;
  final Color? color;

  const OasisMetricData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Factory methods para crear metric cards comunes
extension OasisMetricCardFactory on OasisMetricCard {
  /// Card de métrica de ingresos
  static Widget revenue({
    Key? key,
    required String amount,
    String? subtitle,
    double? changePercentage,
    String? comparisonPeriod,
    Widget? chart,
    VoidCallback? onTap,
    List<OasisMetricData>? breakdown,
  }) {
    return OasisMetricCard(
      key: key,
      title: 'Ingresos',
      value: amount,
      unit: 'S/',
      subtitle: subtitle,
      changePercentage: changePercentage,
      comparisonPeriod: comparisonPeriod,
      chart: chart,
      icon: Icons.trending_up,
      primaryColor: ModernTheme.success,
      onTap: onTap,
      additionalData: breakdown,
    );
  }

  /// Card de métrica de usuarios activos
  static Widget activeUsers({
    Key? key,
    required String count,
    String? subtitle,
    double? changePercentage,
    String? comparisonPeriod,
    Widget? chart,
    VoidCallback? onTap,
  }) {
    return OasisMetricCard(
      key: key,
      title: 'Usuarios Activos',
      value: count,
      subtitle: subtitle,
      changePercentage: changePercentage,
      comparisonPeriod: comparisonPeriod,
      chart: chart,
      icon: Icons.people_outline,
      primaryColor: ModernTheme.primaryBlue,
      onTap: onTap,
    );
  }

  /// Card de métrica de tiempo promedio
  static Widget averageTime({
    Key? key,
    required String duration,
    String? subtitle,
    double? changePercentage,
    String? comparisonPeriod,
    Widget? chart,
    VoidCallback? onTap,
  }) {
    return OasisMetricCard(
      key: key,
      title: 'Tiempo Promedio',
      value: duration,
      unit: 'min',
      subtitle: subtitle,
      changePercentage: changePercentage,
      comparisonPeriod: comparisonPeriod,
      chart: chart,
      icon: Icons.access_time,
      primaryColor: ModernTheme.accentYellow,
      onTap: onTap,
    );
  }

  /// Card de métrica de eficiencia
  static Widget efficiency({
    Key? key,
    required String percentage,
    String? subtitle,
    double? changePercentage,
    String? comparisonPeriod,
    Widget? chart,
    VoidCallback? onTap,
  }) {
    return OasisMetricCard(
      key: key,
      title: 'Eficiencia',
      value: percentage,
      unit: '%',
      subtitle: subtitle,
      changePercentage: changePercentage,
      comparisonPeriod: comparisonPeriod,
      chart: chart,
      icon: Icons.speed,
      primaryColor: ModernTheme.oasisGreen,
      onTap: onTap,
    );
  }
}