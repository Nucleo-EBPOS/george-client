// GEORGE: tema dark/light mapeado de design-system/tokens.css.
// `MyTheme.lightTheme`/`darkTheme` (common.dart) passam pelo `GeorgeTheme`
// para que todas as janelas (home, remoto, configurações) herdem o visual.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart' show TabbarTheme;

/// Tokens (fonte: /srv/george/design-system/tokens.css).
class GeorgeTokens {
  GeorgeTokens._();

  // marca
  static const Color gold = Color(0xFFE8B23A);
  static const Color gold2 = Color(0xFFF7D56B);
  static const Color goldDeep = Color(0xFFB8831A);
  static const Color ink = Color(0xFF0B0B0D);
  static const Color ink2 = Color(0xFF121214);
  static const Color ink3 = Color(0xFF17171A);
  static const Color paper = Color(0xFFF6F4EF);

  // raios
  static const double radius = 14;
  static const double radiusSm = 10;
  static const double radiusLg = 20;

  // dark
  static const Color darkForeground = Color(0xFFECEAE4);
  static const Color darkMuted = Color(0xFF1D1D21);
  static const Color darkMutedForeground = Color(0xFF9B998F);
  static const Color darkCard = Color(0xFF17171A);
  static const Color darkBorder = Color(0x14FFFFFF); // .08
  static const Color darkInput = Color(0x1AFFFFFF); // .10
  static const Color darkSecondary = Color(0xFF222227);
  static const Color darkAccent = Color(0x24E8B23A); // .14
  static const Color darkDestructive = Color(0xFFF0544F);
  static const Color darkSuccess = Color(0xFF3FB950);
  static const Color darkWarning = Color(0xFFD29922);
  static const Color darkOnPrimary = Color(0xFF1A1304);

  // light
  static const Color lightForeground = Color(0xFF17171A);
  static const Color lightMuted = Color(0xFFECE9E1);
  static const Color lightMutedForeground = Color(0xFF6B6860);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x14000000);
  static const Color lightInput = Color(0x1A000000);
  static const Color lightSecondary = Color(0xFFE9E6DE);
  static const Color lightAccent = Color(0x1FB8831A); // .12
  static const Color lightDestructive = Color(0xFFD5382F);
  static const Color lightSuccess = Color(0xFF2E9B45);
  static const Color lightWarning = Color(0xFFB7791F);

  static const Duration durFast = Duration(milliseconds: 140);
  static const Duration durBase = Duration(milliseconds: 220);
  static const Duration durSlow = Duration(milliseconds: 420);
  static const Curve easeOut = Cubic(.16, 1, .3, 1);
}

class GeorgeTheme {
  GeorgeTheme._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color foreground(BuildContext context) => isDark(context)
      ? GeorgeTokens.darkForeground
      : GeorgeTokens.lightForeground;
  static Color mutedForeground(BuildContext context) => isDark(context)
      ? GeorgeTokens.darkMutedForeground
      : GeorgeTokens.lightMutedForeground;
  static Color border(BuildContext context) =>
      isDark(context) ? GeorgeTokens.darkBorder : GeorgeTokens.lightBorder;
  static Color card(BuildContext context) =>
      isDark(context) ? GeorgeTokens.darkCard : GeorgeTokens.lightCard;
  static Color primary(BuildContext context) =>
      isDark(context) ? GeorgeTokens.gold : GeorgeTokens.goldDeep;
  static Color success(BuildContext context) =>
      isDark(context) ? GeorgeTokens.darkSuccess : GeorgeTokens.lightSuccess;
  static Color warning(BuildContext context) =>
      isDark(context) ? GeorgeTokens.darkWarning : GeorgeTokens.lightWarning;
  static Color destructive(BuildContext context) => isDark(context)
      ? GeorgeTokens.darkDestructive
      : GeorgeTokens.lightDestructive;

  /// Superfície "vidro" (card) com borda sutil e raio 20.
  static BoxDecoration glass(BuildContext context, {double? radius}) {
    final dark = isDark(context);
    return BoxDecoration(
      color: card(context).withOpacity(dark ? 0.72 : 0.80),
      borderRadius: BorderRadius.circular(radius ?? GeorgeTokens.radiusLg),
      border: Border.all(
          color: dark ? const Color(0x1AFFFFFF) : const Color(0xA6FFFFFF)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.25 : 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.45 : 0.18),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8)),
      ],
    );
  }

  static RoundedRectangleBorder _shape(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  static ThemeData light(ThemeData base) {
    const fg = GeorgeTokens.lightForeground;
    return base.copyWith(
      scaffoldBackgroundColor: GeorgeTokens.paper,
      canvasColor: GeorgeTokens.paper,
      dialogBackgroundColor: GeorgeTokens.lightCard,
      cardColor: GeorgeTokens.lightCard,
      hoverColor: GeorgeTokens.lightMuted,
      dividerColor: GeorgeTokens.lightBorder,
      hintColor: GeorgeTokens.lightMutedForeground,
      colorScheme: base.colorScheme.copyWith(
        primary: GeorgeTokens.goldDeep,
        onPrimary: Colors.white,
        secondary: GeorgeTokens.gold,
        onSecondary: GeorgeTokens.darkOnPrimary,
        background: GeorgeTokens.paper,
        onBackground: fg,
        surface: GeorgeTokens.lightCard,
        onSurface: fg,
        error: GeorgeTokens.lightDestructive,
      ),
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: GeorgeTokens.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusLg),
          side: const BorderSide(color: GeorgeTokens.lightBorder),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: GeorgeTokens.lightMuted,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
          borderSide: const BorderSide(color: GeorgeTokens.goldDeep, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GeorgeTokens.goldDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: fg,
          side: const BorderSide(color: Color(0x33000000)),
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GeorgeTokens.goldDeep,
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      switchTheme: _switchTheme(GeorgeTokens.goldDeep, GeorgeTokens.lightMutedForeground),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? GeorgeTokens.goldDeep : null),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? GeorgeTokens.goldDeep : null),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: fg,
        unselectedLabelColor: GeorgeTokens.lightMutedForeground,
        indicatorColor: GeorgeTokens.goldDeep,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GeorgeTokens.lightCard,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: GeorgeTokens.lightBorder),
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
        ),
      ),
      menuBarTheme: const MenuBarThemeData(
        style: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(GeorgeTokens.paper)),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: GeorgeTokens.paper,
        foregroundColor: fg,
        elevation: 0,
      ),
      extensions: <ThemeExtension<dynamic>>[
        ColorThemeExtension.light.copyWith(
          border: const Color(0xFFDDD9CF),
          border2: const Color(0xFFCFCAC0),
          highlight: GeorgeTokens.lightMuted,
          divider: const Color(0x1F000000),
        ),
        TabbarTheme.light,
      ],
    );
  }

  static ThemeData dark(ThemeData base) {
    const fg = GeorgeTokens.darkForeground;
    return base.copyWith(
      scaffoldBackgroundColor: GeorgeTokens.ink,
      canvasColor: GeorgeTokens.ink,
      dialogBackgroundColor: GeorgeTokens.ink3,
      cardColor: GeorgeTokens.ink3,
      hoverColor: GeorgeTokens.darkMuted,
      dividerColor: GeorgeTokens.darkBorder,
      hintColor: GeorgeTokens.darkMutedForeground,
      colorScheme: base.colorScheme.copyWith(
        primary: GeorgeTokens.gold,
        onPrimary: GeorgeTokens.darkOnPrimary,
        secondary: GeorgeTokens.gold2,
        onSecondary: GeorgeTokens.darkOnPrimary,
        background: GeorgeTokens.ink2,
        onBackground: fg,
        surface: GeorgeTokens.ink3,
        onSurface: fg,
        error: GeorgeTokens.darkDestructive,
      ),
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: GeorgeTokens.ink3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusLg),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: GeorgeTokens.darkInput,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
          borderSide: const BorderSide(color: GeorgeTokens.gold, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GeorgeTokens.gold,
          foregroundColor: GeorgeTokens.darkOnPrimary,
          elevation: 0,
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: fg,
          side: const BorderSide(color: Color(0x33FFFFFF)),
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GeorgeTokens.gold2,
          shape: _shape(GeorgeTokens.radius),
        ),
      ),
      switchTheme: _switchTheme(GeorgeTokens.gold, GeorgeTokens.darkMutedForeground),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? GeorgeTokens.gold : null),
        checkColor: const MaterialStatePropertyAll(GeorgeTokens.darkOnPrimary),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? GeorgeTokens.gold : null),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: fg,
        unselectedLabelColor: GeorgeTokens.darkMutedForeground,
        indicatorColor: GeorgeTokens.gold,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GeorgeTokens.ink3,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0x1AFFFFFF)),
          borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
        ),
      ),
      menuBarTheme: const MenuBarThemeData(
        style: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(GeorgeTokens.ink2)),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: GeorgeTokens.ink,
        foregroundColor: fg,
        elevation: 0,
      ),
      extensions: <ThemeExtension<dynamic>>[
        ColorThemeExtension.dark.copyWith(
          border: const Color(0x1FFFFFFF),
          border2: const Color(0xFF3A3A40),
          highlight: GeorgeTokens.darkSecondary,
          divider: const Color(0x1FFFFFFF),
        ),
        TabbarTheme.dark,
      ],
    );
  }

  static SwitchThemeData _switchTheme(Color active, Color inactive) {
    return SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? active : Colors.white),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? active.withOpacity(0.5)
              : inactive.withOpacity(0.4)),
    );
  }
}
