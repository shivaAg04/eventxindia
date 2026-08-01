import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The EventXIndia design system — a clean, **light** theme with a confident
/// red brand accent, applied app-wide through [MaterialApp].
///
/// All screens use stock Material widgets (Scaffold, AppBar, FilledButton,
/// Card, InputDecoration, ListTile, Chip, …), so styling them centrally here
/// restyles the whole product without touching individual screens. Keep
/// per-screen styling to a minimum and reach for these tokens instead, so the
/// look stays consistent and is changed in one place.
///
/// The palette is a white/soft-grey canvas with a vivid red primary for
/// actions and highlights, an emerald green for positive/credit states, and a
/// warm amber for pending/warning. Use [AppColors] for raw tokens,
/// [AppTheme.light] for the [ThemeData], and the [AppGradients]/[AppDecorations]
/// helpers for the few surfaces (hero cards, wallet header) that want a filled
/// brand look.
abstract final class AppColors {
  // ---- Backgrounds (canvas → surfaces) ---------------------------------
  /// App canvas — a soft lavender/periwinkle wash behind white cards, giving
  /// the whole app the playful tint from the design.
  static const Color background = Color(0xFFEAE8F7);

  /// Base card / sheet surface — white.
  static const Color surface = Color(0xFFFFFFFF);

  /// Elevated surface (raised cards, menus, dialogs) — also white; depth comes
  /// from soft shadows rather than a lighter fill.
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// A very light neutral fill for input fields and chips.
  static const Color fieldFill = Color(0xFFF1F2F4);

  /// Hairline borders and dividers — a barely-there cool grey.
  static const Color border = Color(0xFFE7E8EC);

  // ---- Accents ---------------------------------------------------------
  /// Primary action colour — the brand orange (CTAs, wallet header, selected
  /// nav). Everything app-wide reads this token, so the brand hue lives here.
  static const Color primary = Color(0xFFF97316);

  /// A deeper orange for gradients and pressed states.
  static const Color primaryDark = Color(0xFFEA580C);

  /// Positive / credit — emerald green (withdraw, "+₹" amounts, success).
  static const Color success = Color(0xFF1EA362);

  /// Playful secondary accent — indigo/violet, used for headers, the title
  /// highlight, promo cards and the primary FAB (pairs with the brand red).
  static const Color accent = Color(0xFF6C5CE7);

  /// A soft lavender wash for header backgrounds and promo cards.
  static const Color accentSoft = Color(0xFFEDEBFB);

  /// Destructive / error — a slightly deeper red so it stays distinct from the
  /// brand red on white.
  static const Color danger = Color(0xFFD92D20);

  /// Warning / pending — amber.
  static const Color amber = Color(0xFFF59E0B);

  // ---- Legacy accent aliases (kept so pre-retheme screens compile) ------
  /// Was the violet accent; now maps to the brand primary on the light theme.
  static const Color violet = primary;

  /// Was the mint accent; now maps to the success green on the light theme.
  static const Color mint = success;

  // ---- Text ------------------------------------------------------------
  /// Primary text — near-black.
  static const Color textPrimary = Color(0xFF17181A);

  /// Secondary / supporting text — medium grey.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Muted text (captions, disabled hints) — light grey.
  static const Color textMuted = Color(0xFF9CA3AF);
}

/// Reusable gradients for hero areas and accent fills.
abstract final class AppGradients {
  /// The signature brand sweep — red → deep red, for hero cards (e.g. the
  /// wallet balance header) and prominent filled surfaces.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.primary, AppColors.primaryDark],
  );

  /// The app canvas — a soft lavender wash painted once behind every screen
  /// (scaffolds are transparent), giving the whole app the design's periwinkle
  /// base. White cards float on top of it.
  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFE9E7F6), Color(0xFFF1F0FA)],
  );
}

/// Ready-made decorations for the handful of surfaces that want more than the
/// base [CardTheme] — soft, floating white cards and the brand-filled hero.
abstract final class AppDecorations {
  /// A soft white card that floats on the canvas with a gentle shadow. Use for
  /// stat tiles and feature cards that should stand off the background.
  static BoxDecoration softCard({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius ?? BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      );

  /// The brand-red hero surface (e.g. the wallet "Total Balance" card).
  static BoxDecoration brandHero({BorderRadius? radius}) => BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: radius ?? BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33F97316),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      );

  /// Backwards-compatible alias for the old dark "glass" card so existing call
  /// sites keep working; on the light theme it renders as a [softCard].
  static BoxDecoration glassCard({BorderRadius? radius}) =>
      softCard(radius: radius);
}

/// The app's [ThemeData]. The product is light by design, so this is wired as
/// both `theme` and `darkTheme` in [MaterialApp].
abstract final class AppTheme {
  static ThemeData get light {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE1DE),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD7F3E4),
      onSecondaryContainer: Color(0xFF0B5133),
      tertiary: AppColors.amber,
      onTertiary: Color(0xFF3A2600),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.fieldFill,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final TextTheme baseText = Typography.material2021().black.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      // Transparent so the app-wide [AppGradients.canvas] painted in
      // MaterialApp.builder shows through every screen.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(baseText),

      // -- App bar: flat, light, centered title ---------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // -- Cards: white, soft-shadowed, rounded ---------------------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14101828),
        elevation: 6,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // -- Buttons --------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.fieldFill,
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
          foregroundColor: Colors.white,
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
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.primary, width: 1.4),
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

      // -- Inputs: filled light grey, rounded, red focus ------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
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
        backgroundColor: AppColors.fieldFill,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        disabledColor: AppColors.fieldFill,
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
        linearTrackColor: AppColors.fieldFill,
        circularTrackColor: AppColors.fieldFill,
      ),

      // -- Snackbars: floating, dark pill, rounded ------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: const Color(0xFFFF9E97),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
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

      // -- Bottom navigation: white bar, red selected, grey unselected ----
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        elevation: 8,
        shadowColor: const Color(0x14101828),
        height: 64,
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
        foregroundColor: Colors.white,
        elevation: 2,
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
