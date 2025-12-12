import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width; // опціональна ширина
  final double height; // висота
  final double fontSize; // розмір шрифту

  const CustomButton({
    required this.text,
    required this.onPressed,
    this.width, 
    this.height = 50,
    this.fontSize = 16,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity, // якщо width не вказано — full width
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          // 1. Прибираємо всі внутрішні відступи
          padding: EdgeInsets.zero,
          // 2. (Опціонально, але рекомендовано) Робить область натискання
          // рівно по розміру кнопки, а не більшою.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }
}
