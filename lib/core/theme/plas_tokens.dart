import 'package:material_ui/material_ui.dart';

abstract final class PlasColors {
  static const bgCanvas = Color(0xFFF8FAFC);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSubtle = Color(0xFFF1F5F9);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF334155);
  static const textMuted = Color(0xFF475569);

  static const borderSubtle = Color(0xFFE2E8F0);
  static const borderDivider = Color(0xFFCBD5E1);
  static const borderInteractive = Color(0xFF64748B);

  static const disabledBg = Color(0xFFE2E8F0);
  static const disabledBorder = Color(0xFFCBD5E1);
  static const disabledText = Color(0xFF475569);

  static const brandPrimary = Color(0xFF1D4ED8);
  static const brandHover = Color(0xFF1E40AF);
  static const brandTint = Color(0xFFEFF6FF);
  static const focusLight = Color(0xFF1D4ED8);
  static const focusDark = Color(0xFF60A5FA);

  static const codeBg = Color(0xFF0F172A);
  static const codeHeader = Color(0xFF1E293B);
  static const codeText = Color(0xFFF8FAFC);
  static const codeKeyword = Color(0xFF93C5FD);
  static const codeType = Color(0xFF5EEAD4);
  static const codeString = Color(0xFF86EFAC);
  static const codeNumber = Color(0xFFFCD34D);
  static const codeComment = Color(0xFF94A3B8);

  static const successText = Color(0xFF166534);
  static const successBg = Color(0xFFF0FDF4);
  static const successBorder = Color(0xFF15803D);

  static const errorText = Color(0xFF991B1B);
  static const errorBg = Color(0xFFFEF2F2);
  static const errorBorder = Color(0xFFDC2626);

  static const warningText = Color(0xFF92400E);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFB45309);

  static const chartPre = Color(0xFF64748B);
  static const chartPost = Color(0xFF1D4ED8);
}

abstract final class PlasSpacing {
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
}

abstract final class PlasRadii {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double full = 9999.0;
}

abstract final class PlasShadows {
  static const List<BoxShadow> none = [];
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x240F172A),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x2E0F172A),
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];
}

abstract final class PlasTypography {
  static const String fontSans = 'Plus Jakarta Sans';
  static const String fontMono = 'JetBrains Mono';

  static const TextStyle display = TextStyle(
    fontFamily: fontSans,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: PlasColors.textPrimary,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: fontSans,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: PlasColors.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontSans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: PlasColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontSans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: PlasColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontSans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: PlasColors.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontSans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: PlasColors.textMuted,
  );
  static const TextStyle code = TextStyle(
    fontFamily: fontMono,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: PlasColors.codeText,
  );
  static const TextStyle codeMeta = TextStyle(
    fontFamily: fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: PlasColors.brandPrimary,
  );
}
