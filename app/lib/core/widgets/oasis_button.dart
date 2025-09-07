import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OasisButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final ButtonType type;
  final Size? size;
  
  const OasisButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.type = ButtonType.primary,
    this.size,
  });
  
  factory OasisButton.primary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    Size? size,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: ButtonType.primary,
      size: size,
    );
  }
  
  factory OasisButton.secondary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    Size? size,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: ButtonType.secondary,
      size: size,
    );
  }
  
  factory OasisButton.outlined({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    Size? size,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: ButtonType.outlined,
      size: size,
    );
  }
  
  factory OasisButton.text({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
    Size? size,
  }) {
    return OasisButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      type: ButtonType.text,
      size: size,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(text),
      ],
    );
    
    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: size ?? const Size(double.infinity, 56),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.6),
          ),
          child: child,
        );
        
      case ButtonType.secondary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: size ?? const Size(double.infinity, 56),
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.6),
          ),
          child: child,
        );
        
      case ButtonType.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size ?? const Size(double.infinity, 56),
            side: const BorderSide(color: AppTheme.primaryColor, width: 2),
            foregroundColor: AppTheme.primaryColor,
          ),
          child: child,
        );
        
      case ButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: size ?? Size.zero,
            foregroundColor: AppTheme.primaryColor,
          ),
          child: child,
        );
    }
  }
}

enum ButtonType {
  primary,
  secondary,
  outlined,
  text,
}