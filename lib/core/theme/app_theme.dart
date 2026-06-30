import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The EventXIndia design system — a single, dark, "AI-era" theme applied
/// app-wide through [MaterialApp].
///
/// All screens use stock Material widgets (Scaffold, AppBar, FilledButton,
/// Card, InputDecoration, ListTile, Chip, …), so styling them centrally here
/// restyles the whole product without touching individual screens. Keep
/// per-screen styling to a minimum and reach for these tokens instead, so the
/// look stays consistent and is changed in one place.
///
/// The palette is a deep, blue-tinted near-black with an electric
/// periwinkle/violet/mint accent triad — a restrained, futuristic register
/// rather than a neon one. Use [AppColors] for raw tokens, [AppTheme.dark] for
/// the [ThemeData], and the [AppGradients]/[AppDecorations] helpers for the few
/// surfaces (hero headers, glass cards) that want more than the base theme.
abstract final class AppColors {
  // ---- Backgrounds (darkest → lightest surface) -------------------------
  /// App canvas — the darkest layer, behind everything.
  static const Color background = Color(0xFF07080F);

  /// Base card / sheet surface, one step above the canvas.
  static const Color surface = Color(0xFF10131F);

  /// Elevated surface (raised cards, menus, dialogs).
  static const Color surfaceElevated = Color(0xFF161A2A);

  /// Hairline borders and dividers — a low-contrast cool grey.
  static const Color border = Color(0xFF252A3D);

  // ---- Accent triad -----------------------------------------------------
  /// Primary action colour — electric periwinkle blue.
  static const Color primary = Color(0xFF7C9CFF);

  /// Secondary accent — violet, for highlights and gradients.
  static const Color violet = Color(0xFFC58BFF);

  /// Tertiary accent — mint/cyan glow, for success and "live" states.
  static const Color mint = Color(0xFF4FE3C1);

  /// Destructive / error — a warm coral that stays legible on dark.
  static const Color danger = Color(0xFFFF6B85);

  /// Warning / pending — amber.
  static const Color amber = Color(0xFFFFC24B);

  // ---- Text ------------------------------------------------------------
  /// Primary text — near-white with a faint cool tint.
  static const Color textPrimary = Color(0xFFEEF1FB);

  /// Secondary / supporting text.
  static const Color textSecondary = Color(0xFF9BA3C2);

  /// Muted text (captions, disabled hints).
  static const Color textMuted = Color(0xFF646C8C);
}

/// Reusable gradients for hero areas and accent fills.
abstract final class AppGradients {
  /// The signature brand sweep — periwinkle → violet, for primary CTAs and
  /// hero headers.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF7C9CFF), Color(0xFFC58BFF)],
  );

  /// The opaque app canvas — a subtle violet/blue glow in the top-left corner
  /// fading into the near-black background. Painted once behind every screen
  /// (scaffolds are transparent), giving the whole app shared depth.
  static const RadialGradient canvas = RadialGradient(
    center: Alignment(-0.8, -1.0),
    radius: 1.6,
    colors: <Color>[Color(0xFF161C38), AppColors.background],
    stops: <double>[0.0, 0.75],
  );
}

/// Ready-made decorations for the handful of surfaces that want a glassy,
/// bordered look on top of the base [CardTheme].
abstract final class AppDecorations {
  /// A glassmorphic card: translucent elevated surface, hairline border, soft
  /// shadow. Use for stat tiles and feature cards that should "float".
  static BoxDecoration glassCard({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: radius ?? BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      );
}

/// The app's [ThemeData]. The product is dark-only by design, so this is wired
/// as both `theme` and `darkTheme` in [MaterialApp].
abstract final class AppTheme {
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Color(0xFF071029),
      primaryContainer: Color(0xFF24305A),
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.violet,
      onSecondary: Color(0xFF230A3A),
      secondaryContainer: Color(0xFF3A2657),
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.mint,
      onTertiary: Color(0xFF00271F),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Color(0xFF2B0710),
    );

    final TextTheme baseText = Typography.material2021()
        .white
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      // Transparent so the app-wide [AppGradients.canvas] painted in
      // MaterialApp.builder shows through every screen.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(baseText),

      // -- App bar: flat, transparent, part of the canvas -----------------
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),

      // -- Cards: rounded, hairline-bordered, no Material tint ------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // -- Buttons --------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF071029),
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF071029),
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -- Inputs: filled, rounded, glowing focus ------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),

      // -- Chips ----------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        disabledColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(color: AppColors.primary),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // -- List tiles -----------------------------------------------------
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceElevated,
        circularTrackColor: AppColors.surfaceElevated,
      ),

      // -- Snackbars: floating, dark, rounded ----------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        actionTextColor: AppColors.primary,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.textSecondary),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Color(0xFF071029),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      dividerColor: AppColors.border,
    );
  }

  /// Applies tighter, more "designed" typography (negative tracking on
  /// headings, comfortable body) on top of the Material 2021 base.
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
}
