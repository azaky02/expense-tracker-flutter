import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TransactionsListScreen extends StatelessWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: const Center(child: Text('—')),
    );
  }
}
