import 'package:flutter/material.dart';
import '../theme/modern_theme.dart';
import '../constants/app_spacing.dart';

/// Sistema de layout responsivo unificado para la aplicación Oasis
/// Proporciona utilidades para crear interfaces que se adapten a diferentes tamaños de pantalla
class OasisLayout {
  OasisLayout._();

  /// Tipos de layout responsivo disponibles
  static const List<OasisBreakpoint> _breakpoints = [
    OasisBreakpoint.mobile,
    OasisBreakpoint.tablet,
    OasisBreakpoint.desktop,
  ];

  /// Obtiene el breakpoint actual basado en el ancho de pantalla
  /// Comment 3: Make constraint-driven helper that accepts BoxConstraints instead
  static OasisBreakpoint getCurrentBreakpoint(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ModernTheme.mobileBreakpoint) {
      return OasisBreakpoint.mobile;
    } else if (width < ModernTheme.tabletBreakpoint) {
      return OasisBreakpoint.tablet;
    } else {
      return OasisBreakpoint.desktop;
    }
  }

  /// Comment 3: Constraint-driven breakpoint helper
  static OasisBreakpoint getBreakpointFromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;

    if (width < ModernTheme.mobileBreakpoint) {
      return OasisBreakpoint.mobile;
    } else if (width < ModernTheme.tabletBreakpoint) {
      return OasisBreakpoint.tablet;
    } else {
      return OasisBreakpoint.desktop;
    }
  }

  /// Builder responsivo que adapta el contenido según el breakpoint
  /// Comment 3: Make LayoutBuilder-friendly by wrapping in LayoutBuilder internally
  static Widget responsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpointFromConstraints(constraints);

        switch (breakpoint) {
          case OasisBreakpoint.mobile:
            return mobile;
          case OasisBreakpoint.tablet:
            return tablet ?? mobile;
          case OasisBreakpoint.desktop:
            return desktop ?? tablet ?? mobile;
        }
      },
    );
  }

  /// Builder avanzado con callbacks para cada breakpoint
  static Widget responsiveBuilder({
    required BuildContext context,
    required Widget Function(BuildContext context, OasisBreakpoint breakpoint) builder,
  }) {
    final breakpoint = getCurrentBreakpoint(context);
    return builder(context, breakpoint);
  }

  /// Contenedor con padding responsivo
  /// Comment 3: Make LayoutBuilder-friendly
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    double? mobilePadding,
    double? tabletPadding,
    double? desktopPadding,
    bool useMaxWidth = true,
    double? maxWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpointFromConstraints(constraints);

        double padding;
        switch (breakpoint) {
          case OasisBreakpoint.mobile:
            padding = mobilePadding ?? AppSpacing.screenPadding;
            break;
          case OasisBreakpoint.tablet:
            padding = tabletPadding ?? AppSpacing.containerPaddingLarge;
            break;
          case OasisBreakpoint.desktop:
            padding = desktopPadding ?? AppSpacing.sectionPadding;
            break;
        }

        Widget container = Container(
          padding: EdgeInsets.all(padding),
          child: child,
        );

        if (useMaxWidth) {
          final effectiveMaxWidth = maxWidth ?? _getMaxWidthForBreakpoint(breakpoint);
          container = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
              child: container,
            ),
          );
        }

        return container;
      },
    );
  }

  /// Grid responsivo que adapta el número de columnas
  /// Comment 3: Make LayoutBuilder-friendly
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    int mobileColumns = 1,
    int tabletColumns = 2,
    int desktopColumns = 3,
    double spacing = AppSpacing.md,
    double runSpacing = AppSpacing.md,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpointFromConstraints(constraints);

    int columns;
    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        columns = mobileColumns;
        break;
      case OasisBreakpoint.tablet:
        columns = tabletColumns;
        break;
      case OasisBreakpoint.desktop:
        columns = desktopColumns;
        break;
    }

    if (columns == 1) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: runSpacing),
                  child: child,
                ))
            .toList(),
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final rowChildren = children
          .skip(i)
          .take(columns)
          .map((child) => Expanded(child: child))
          .toList();

      // Rellenar con espacios vacíos si es necesario
      while (rowChildren.length < columns) {
        rowChildren.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: runSpacing),
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: rowChildren
                .expand((child) => [
                      child,
                      if (rowChildren.indexOf(child) < rowChildren.length - 1)
                        SizedBox(width: spacing),
                    ])
                .take(rowChildren.length * 2 - 1)
                .toList(),
          ),
        ),
      );
    }

        return Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: rows,
        );
      },
    );
  }

  /// Lista responsiva que cambia entre List y Grid
  /// Comment 3: Make LayoutBuilder-friendly
  static Widget responsiveList({
    required BuildContext context,
    required List<Widget> children,
    bool useGridOnTablet = true,
    bool useGridOnDesktop = true,
    int tabletColumns = 2,
    int desktopColumns = 3,
    double spacing = AppSpacing.md,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpointFromConstraints(constraints);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return ListView.separated(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: children.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) => children[index],
        );

      case OasisBreakpoint.tablet:
        if (useGridOnTablet) {
          return responsiveGrid(
            context: context,
            children: children,
            mobileColumns: 1,
            tabletColumns: tabletColumns,
            desktopColumns: tabletColumns,
            spacing: spacing,
            runSpacing: spacing,
          );
        }
        return ListView.separated(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: children.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) => children[index],
        );

      case OasisBreakpoint.desktop:
        if (useGridOnDesktop) {
          return responsiveGrid(
            context: context,
            children: children,
            mobileColumns: 1,
            tabletColumns: tabletColumns,
            desktopColumns: desktopColumns,
            spacing: spacing,
            runSpacing: spacing,
          );
        }
        return ListView.separated(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: children.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) => children[index],
        );
        }
      },
    );
  }

  /// AppBar responsivo con diferentes configuraciones
  static PreferredSizeWidget responsiveAppBar({
    required BuildContext context,
    required String title,
    String? subtitle,
    List<Widget>? actions,
    Widget? leading,
    bool centerTitle = true,
    Color? backgroundColor,
    bool showBackButton = true,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return AppBar(
          title: Text(title),
          backgroundColor: backgroundColor,
          centerTitle: centerTitle,
          leading: leading,
          automaticallyImplyLeading: showBackButton,
          actions: actions?.take(2).toList(), // Limitar acciones en móvil
        );

      case OasisBreakpoint.tablet:
      case OasisBreakpoint.desktop:
        return AppBar(
          title: subtitle != null
              ? Column(
                  crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                )
              : Text(title),
          backgroundColor: backgroundColor,
          centerTitle: centerTitle,
          leading: leading,
          automaticallyImplyLeading: showBackButton,
          actions: actions,
          toolbarHeight: subtitle != null ? 80 : null,
        );
    }
  }

  /// Drawer/Navigation responsivo
  static Widget responsiveNavigation({
    required BuildContext context,
    required List<OasisNavigationItem> items,
    required Function(int) onItemTapped,
    int currentIndex = 0,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: items
              .take(5) // Máximo 5 items en BottomNav
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ))
              .toList(),
        );

      case OasisBreakpoint.tablet:
        return NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onItemTapped,
          labelType: NavigationRailLabelType.all,
          destinations: items
              .map((item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ))
              .toList(),
        );

      case OasisBreakpoint.desktop:
        return Drawer(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text('Oasis Taxi'),
              ),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: index == currentIndex,
                  onTap: () => onItemTapped(index),
                );
              }),
            ],
          ),
        );
    }
  }

  /// Espaciado responsivo
  static double getResponsiveSpacing(BuildContext context, {
    double mobile = AppSpacing.md,
    double tablet = AppSpacing.lg,
    double desktop = AppSpacing.xl,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return mobile;
      case OasisBreakpoint.tablet:
        return tablet;
      case OasisBreakpoint.desktop:
        return desktop;
    }
  }

  /// Padding responsivo
  static EdgeInsets getResponsivePadding(BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return mobile ?? AppSpacing.all(AppSpacing.md);
      case OasisBreakpoint.tablet:
        return tablet ?? AppSpacing.all(AppSpacing.lg);
      case OasisBreakpoint.desktop:
        return desktop ?? AppSpacing.all(AppSpacing.xl);
    }
  }

  /// Comment 4: Obtener padding de pantalla adaptativo basado en breakpoint
  static EdgeInsets screenPadding(BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return mobile ?? EdgeInsets.all(AppSpacing.screenPadding);
      case OasisBreakpoint.tablet:
        return tablet ?? EdgeInsets.all(AppSpacing.containerPaddingLarge);
      case OasisBreakpoint.desktop:
        return desktop ?? EdgeInsets.all(AppSpacing.sectionPadding);
    }
  }

  /// Comment 4: Obtener espaciado entre secciones basado en breakpoint
  static double sectionSpacing(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return mobile ?? AppSpacing.sectionMargin;
      case OasisBreakpoint.tablet:
        return tablet ?? AppSpacing.sectionMargin * 1.5;
      case OasisBreakpoint.desktop:
        return desktop ?? AppSpacing.sectionMargin * 2;
    }
  }

  /// Comment 4: Obtener GridDelegate optimizado para diferentes breakpoints
  static SliverGridDelegate gridDelegate(BuildContext context, {
    int mobileColumns = 2,
    int tabletColumns = 3,
    int desktopColumns = 4,
    double childAspectRatio = 1.0,
    double mainAxisSpacing = AppSpacing.md,
    double crossAxisSpacing = AppSpacing.md,
  }) {
    final breakpoint = getCurrentBreakpoint(context);

    int crossAxisCount;
    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        crossAxisCount = mobileColumns;
        break;
      case OasisBreakpoint.tablet:
        crossAxisCount = tabletColumns;
        break;
      case OasisBreakpoint.desktop:
        crossAxisCount = desktopColumns;
        break;
    }

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
    );
  }

  /// Helpers privados
  static double _getMaxWidthForBreakpoint(OasisBreakpoint breakpoint) {
    switch (breakpoint) {
      case OasisBreakpoint.mobile:
        return double.infinity;
      case OasisBreakpoint.tablet:
        return 800;
      case OasisBreakpoint.desktop:
        return 1200;
    }
  }
}

/// Breakpoints disponibles para diseño responsivo
enum OasisBreakpoint {
  mobile,
  tablet,
  desktop,
}

/// Item de navegación para uso en componentes responsivos
class OasisNavigationItem {
  final IconData icon;
  final String label;
  final String? route;

  const OasisNavigationItem({
    required this.icon,
    required this.label,
    this.route,
  });
}

/// Extension para facilitar el uso de breakpoints
extension OasisBreakpointExtension on OasisBreakpoint {
  /// Verifica si es móvil
  bool get isMobile => this == OasisBreakpoint.mobile;

  /// Verifica si es tablet
  bool get isTablet => this == OasisBreakpoint.tablet;

  /// Verifica si es desktop
  bool get isDesktop => this == OasisBreakpoint.desktop;

  /// Verifica si es tablet o más grande
  bool get isTabletOrLarger => this == OasisBreakpoint.tablet || this == OasisBreakpoint.desktop;

  /// Verifica si es móvil o tablet
  bool get isMobileOrTablet => this == OasisBreakpoint.mobile || this == OasisBreakpoint.tablet;
}

/// Widget helper para layouts responsivos complejos
class OasisResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, OasisBreakpoint breakpoint) builder;

  const OasisResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return OasisLayout.responsiveBuilder(
      context: context,
      builder: builder,
    );
  }
}

/// Widget para crear layouts de dos columnas responsivas
class OasisTwoColumnLayout extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final double spacing;
  final double primaryFlex;
  final double secondaryFlex;
  final bool stackOnMobile;

  const OasisTwoColumnLayout({
    super.key,
    required this.primary,
    required this.secondary,
    this.spacing = AppSpacing.lg,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.stackOnMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    return OasisResponsiveBuilder(
      builder: (context, breakpoint) {
        if (breakpoint.isMobile && stackOnMobile) {
          return Column(
            children: [
              primary,
              SizedBox(height: spacing),
              secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: primaryFlex.round(),
              child: primary,
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: secondaryFlex.round(),
              child: secondary,
            ),
          ],
        );
      },
    );
  }
}