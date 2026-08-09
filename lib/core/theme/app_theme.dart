import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// LearnHub premium design system.
///
/// Design language: clean, airy, rounded, with a single confident brand
/// gradient (indigo → violet) used sparingly for emphasis. Typography is
/// Plus Jakarta Sans for a modern, premium feel.
class AppTheme {
  AppTheme._();

  // --- Brand palette (LearnHub Academy: navy / gold / teal) ---
  static const Color brand = Color(0xFF163A5C); // academy navy
  static const Color brand2 = Color(0xFF1F4E7A); // lighter navy (gradient depth)
  static const Color accent = Color(0xFF2AA398); // teal
  static const Color gold = Color(0xFFDBA525); // tassel gold — sparing use
  static const Color success = Color(0xFF16C784);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF43F5E);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brand2],
  );

  // --- Radii & spacing tokens ---
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 28;

  static const SystemUiOverlayStyle overlayLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static ThemeData light() {
    const surface = Color(0xFFF7F7FB);
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      secondary: accent,
      surface: surface,
      brightness: Brightness.light,
    );
    return _base(scheme, const Color(0xFF14132A));
  }

  static ThemeData dark() {
    const surface = Color(0xFF0E0E16);
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      primary: const Color(0xFF9B8CFF),
      secondary: accent,
      surface: surface,
      brightness: Brightness.dark,
    );
    return _base(scheme, Colors.white);
  }

  static ThemeData _base(ColorScheme scheme, Color onBg) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: scheme.brightness).textTheme,
    ).apply(bodyColor: onBg, displayColor: onBg);

    final cardColor = isDark ? const Color(0xFF17172A) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: onBg,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: onBg,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF17172A) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        prefixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rMd),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rMd),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: cardColor,
        indicatorColor: scheme.primary.withOpacity(0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.5),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
      ),
      extensions: [AppColors(card: cardColor, onBg: onBg)],
    );
  }
}

/// Theme extension so widgets can read the premium card color in any brightness.
class AppColors extends ThemeExtension<AppColors> {
  final Color card;
  final Color onBg;
  const AppColors({required this.card, required this.onBg});

  @override
  AppColors copyWith({Color? card, Color? onBg}) =>
      AppColors(card: card ?? this.card, onBg: onBg ?? this.onBg);

  @override
  AppColors lerp(AppColors? other, double t) => AppColors(
        card: Color.lerp(card, other?.card, t) ?? card,
        onBg: Color.lerp(onBg, other?.onBg, t) ?? onBg,
      );
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
