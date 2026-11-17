import 'package:flutter/material.dart';

class TermsAgreementTile extends StatelessWidget {
  const TermsAgreementTile({
    super.key,
    required this.value,
    required this.checkboxKey,
    required this.onChanged,
  });

  final bool value;
  final Key checkboxKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: checkboxKey,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      title: const Text(
        '[필수] 서비스 이용약관에 동의합니다.',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
