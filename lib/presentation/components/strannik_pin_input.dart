import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/app_tokens.dart';

/// One native numeric input, four visual cells. PIN never enters app/domain state.
class StrannikPinInput extends StatelessWidget {
  const StrannikPinInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.enabled,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Stack(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => ExcludeSemantics(
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 60,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.black, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          offset: Offset(0, 4),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      '•',
                      style: AppTypography.button.copyWith(
                        color: index < value.text.length
                            ? AppColors.black
                            : AppColors.gray,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: TextField(
            key: const ValueKey('pin-input'),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: true,
            obscuringCharacter: '•',
            showCursor: false,
            style: const TextStyle(color: Colors.transparent),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            enableIMEPersonalizedLearning: false,
            enableInteractiveSelection: false,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              border: InputBorder.none,
              labelText: 'PIN, четыре цифры',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: TextStyle(color: Colors.transparent),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}
