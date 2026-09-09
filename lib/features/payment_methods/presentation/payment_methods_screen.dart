import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('cards.paymentMethods'.tr())),
      body: const Center(child: Text('—')),
    );
  }
}
