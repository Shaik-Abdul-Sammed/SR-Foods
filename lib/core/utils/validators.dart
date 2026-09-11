class Validators {
  Validators._();

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? phone(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    
    final phoneRegExp = RegExp(r'^\+?[0-9]{10,13}$');
    if (!phoneRegExp.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? email(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Email is required' : null;
    }

    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? number(String? value, String fieldName, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$fieldName is required' : null;
    }

    final number = num.tryParse(value.trim());
    if (number == null) {
      return 'Enter a valid number';
    }
    return null;
  }
}
