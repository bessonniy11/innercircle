import 'package:flutter/material.dart';

/// Виджет логотипа "Звонилка"
/// 
/// Отображает фирменный логотип приложения с настраиваемым размером.
/// Поддерживает как SVG, так и PNG формат для разных случаев использования.
/// 
/// @since 1.0.0
/// @author ИИ-Ассистент + Bessonniy
class AppLogo extends StatelessWidget {
  /// Размер логотипа
  final double size;
  
  /// Показывать ли название под логотипом
  final bool showTitle;
  
  /// Цвет логотипа (если не задан, использует оригинальный)
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showTitle = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Логотип
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.2),
            child: _buildLogoImage(),
          ),
        ),
        
        // Название (опционально)
        if (showTitle) ...[
          const SizedBox(height: 16),
          Text(
            'Звонилка',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Семейный мессенджер',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  /// Создает изображение логотипа
  Widget _buildLogoImage() {
    // Временно используем иконку до получения настоящего логотипа
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.phone_in_talk,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Компактная версия логотипа для AppBar
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 32),
        const SizedBox(width: 8),
        Text(
          'Звонилка',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
