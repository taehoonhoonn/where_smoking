import 'dart:js' as js;

const String _defaultApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');

String getApiBaseUrl() {
  const candidates = ['API_BASE_URL', '_base_Url'];

  for (final key in candidates) {
    try {
      if (!js.context.hasProperty(key)) {
        continue;
      }
      final value = js.context[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    } catch (_) {
      // ignore and fall back to default value
    }
  }

  return _defaultApiBaseUrl;
}
