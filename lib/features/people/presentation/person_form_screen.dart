import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'people_providers.dart';

/// Add (personId == null) or edit a person.
class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({super.key, this.personId});
  final int? personId;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = ref.read(ledgerRepositoryProvider);
    if (widget.personId == null) {
      final id = await repo.createPerson(name: _name.text, phone: _phone.text, email: _email.text, notes: _notes.text);
      if (mounted) context.pushReplacement('/people/$id');
    } else {
      await repo.updatePerson(widget.personId!, name: _name.text, phone: _phone.text, email: _email.text, notes: _notes.text);
      if (mounted) context.pop();
    }
  }

  Future<void> _delete() async {
    final ok = await ref.read(ledgerRepositoryProvider).deletePerson(widget.personId!);
    if (!mounted) return;
    if (ok) {
      context.go('/people');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('people.deleteBlocked'.tr(context: context))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.personId != null && !_loaded) {
      final p = ref.watch(personProvider(widget.personId!)).value;
      if (p != null) {
        _name.text = p.name;
        _phone.text = p.phone ?? '';
        _email.text = p.email ?? '';
        _notes.text = p.notes ?? '';
        _loaded = true;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.personId == null ? 'people.add' : 'people.edit').tr(context: context)),
        actions: [
          if (widget.personId != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'people.delete'.tr(context: context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, autofocus: widget.personId == null, decoration: InputDecoration(labelText: 'people.name'.tr(context: context))),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: '${'people.phone'.tr(context: context)} (${'common.optional'.tr(context: context)})'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '${'people.email'.tr(context: context)} (${'common.optional'.tr(context: context)})',
              helperText: 'people.emailHint'.tr(context: context),
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(labelText: '${'people.notes'.tr(context: context)} (${'common.optional'.tr(context: context)})'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _saving ? null : _save, child: Text('common.save'.tr(context: context))),
        ],
      ),
    );
  }
}
