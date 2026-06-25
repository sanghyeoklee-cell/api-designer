import 'package:flutter/material.dart';
import '../models/form_schema.dart' as schema;

class DynamicForm extends StatefulWidget {
  final schema.FormSchema formSchema;
  final void Function(Map<String, String> values) onSubmit;

  const DynamicForm({
    super.key,
    required this.formSchema,
    required this.onSubmit,
  });

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectValues = {};
  final Map<String, bool> _checkValues = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.formSchema.fields) {
      if (field.fieldType == 'checkbox') {
        _checkValues[field.key] = field.defaultValue == 'true';
      } else if (field.fieldType == 'select') {
        // Deduplicate options and ensure value is valid
        final uniqueOptions = field.options.toSet().toList();
        final defaultVal = field.defaultValue;
        if (defaultVal.isNotEmpty && uniqueOptions.contains(defaultVal)) {
          _selectValues[field.key] = defaultVal;
        } else if (uniqueOptions.isNotEmpty) {
          _selectValues[field.key] = uniqueOptions.first;
        } else {
          _selectValues[field.key] = '';
        }
      } else {
        _controllers[field.key] =
            TextEditingController(text: field.defaultValue);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildField(schema.FormField field) {
    switch (field.fieldType) {
      case 'password':
        return TextFormField(
          controller: _controllers[field.key],
          obscureText: true,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            helperText: field.description.isNotEmpty ? field.description : null,
            border: const OutlineInputBorder(),
          ),
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? '${field.label} is required' : null
              : null,
        );

      case 'textarea':
        return TextFormField(
          controller: _controllers[field.key],
          maxLines: 4,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            helperText: field.description.isNotEmpty ? field.description : null,
            border: const OutlineInputBorder(),
          ),
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? '${field.label} is required' : null
              : null,
        );

      case 'number':
        return TextFormField(
          controller: _controllers[field.key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            helperText: field.description.isNotEmpty ? field.description : null,
            border: const OutlineInputBorder(),
          ),
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? '${field.label} is required' : null
              : null,
        );

      case 'select':
        final uniqueOptions = field.options.toSet().toList();
        final currentValue = _selectValues[field.key];
        return DropdownButtonFormField<String>(
          value: (currentValue != null &&
                  currentValue.isNotEmpty &&
                  uniqueOptions.contains(currentValue))
              ? currentValue
              : (uniqueOptions.isNotEmpty ? uniqueOptions.first : null),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description.isNotEmpty ? field.description : null,
            border: const OutlineInputBorder(),
          ),
          items: uniqueOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _selectValues[field.key] = v ?? ''),
        );

      case 'checkbox':
        return CheckboxListTile(
          title: Text(field.label),
          subtitle:
              field.description.isNotEmpty ? Text(field.description) : null,
          value: _checkValues[field.key] ?? false,
          onChanged: (v) =>
              setState(() => _checkValues[field.key] = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        );

      default: // text
        return TextFormField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            helperText: field.description.isNotEmpty ? field.description : null,
            border: const OutlineInputBorder(),
          ),
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? '${field.label} is required' : null
              : null,
        );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final values = <String, String>{};
    for (final field in widget.formSchema.fields) {
      if (field.fieldType == 'checkbox') {
        values[field.key] = (_checkValues[field.key] ?? false).toString();
      } else if (field.fieldType == 'select') {
        values[field.key] = _selectValues[field.key] ?? '';
      } else {
        values[field.key] = _controllers[field.key]?.text ?? '';
      }
    }
    widget.onSubmit(values);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.formSchema.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.formSchema.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (widget.formSchema.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.formSchema.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
          ...widget.formSchema.fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildField(f),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
