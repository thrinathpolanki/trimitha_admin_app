import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark navy + teal theme, matching the Trimitha admin app mockups.
class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF0B1220); // deepest background
  static const Color surface = Color(0xFF141B2E); // cards
  static const Color surfaceAlt = Color(0xFF1B2438); // slightly raised cards
  static const Color border = Color(0xFF232D45);

  // Brand
  static const Color teal = Color(0xFF2DD4BF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color navy = Color(0xFF0A2540); // matches the website

  // Status
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);
  static const Color purple = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFF472B6);
  static const Color orange = Color(0xFFFB923C);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  /// Rotating palette used for stat-card icon badges / avatars, in the
  /// same spirit as the mockups (teal, blue, purple, orange, pink...).
  static const List<Color> palette = [
    teal,
    info,
    purple,
    orange,
    pink,
    cyan,
    success,
    warning
  ];
}

class AppTheme {
  static ThemeData dark() {
    // Inter for everyday body/UI text, Poppins for headings and titles —
    // gives clear visual hierarchy instead of one uniform system font.
    final bodyFont = GoogleFonts.interTextTheme();
    final headingFont = GoogleFonts.poppinsTextTheme();

    final textTheme = bodyFont
        .copyWith(
          displayLarge: headingFont.displayLarge,
          displayMedium: headingFont.displayMedium,
          displaySmall: headingFont.displaySmall,
          headlineLarge:
              headingFont.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium:
              headingFont.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          headlineSmall:
              headingFont.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          titleLarge:
              headingFont.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium:
              headingFont.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall:
              headingFont.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.teal.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.teal : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
              color: selected ? AppColors.teal : AppColors.textSecondary);
        }),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

/// Small helper for consistent status-pill styling (Unread/Read/Starred/etc).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Colored circular icon badge used throughout (stat cards, avatars, etc).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(
      {super.key, required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
