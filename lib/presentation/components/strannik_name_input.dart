import 'package:flutter/material.dart';

import '../foundation/app_tokens.dart';

class StrannikNameInput extends StatelessWidget {
  const StrannikNameInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final String label, hint;
  final ValueChanged<String> onChanged, onSubmitted;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    keyboardType: TextInputType.name,
    textCapitalization: TextCapitalization.words,
    textInputAction: TextInputAction.done,
    style: AppTypography.button.copyWith(color: AppColors.black),
    cursorColor: AppColors.blue,
    decoration: InputDecoration(
      semanticCounterText: label,
      hintText: hint,
      hintStyle: AppTypography.button.copyWith(color: AppColors.gray),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.black, width: 3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.black, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 3),
      ),
    ),
  );
}
