import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('transactions.addTitle'.tr())),
      body: const Center(child: Text('—')),
    );
  }
}
