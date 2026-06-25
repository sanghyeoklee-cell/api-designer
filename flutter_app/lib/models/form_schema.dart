class FormField {
  final String key;
  final String label;
  final String fieldType;
  final bool required;
  final String placeholder;
  final String defaultValue;
  final List<String> options;
  final String description;

  FormField({
    required this.key,
    required this.label,
    this.fieldType = 'text',
    this.required = true,
    this.placeholder = '',
    this.defaultValue = '',
    this.options = const [],
    this.description = '',
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    return FormField(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      fieldType: json['field_type'] ?? 'text',
      required: json['required'] ?? true,
      placeholder: json['placeholder'] ?? '',
      defaultValue: json['default_value'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      description: json['description'] ?? '',
    );
  }
}

class FormSchema {
  final String title;
  final String description;
  final List<FormField> fields;

  FormSchema({
    required this.title,
    this.description = '',
    this.fields = const [],
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    return FormSchema(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => FormField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
