import 'dart:js' as js;

const String _defaultApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.wheresmoking.kr/api/v1');

String getApiBaseUrl() {
  try {
    // window.API_BASE_URL에서 직접 읽기
    if (js.context.hasProperty('API_BASE_URL')) {
      final value = js.context['API_BASE_URL'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    // window 객체를 통해 접근 시도
    final window = js.context['window'];
    if (window != null && window['API_BASE_URL'] != null) {
      final value = window['API_BASE_URL'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  } catch (e) {
    print('API URL 설정 읽기 실패: $e');
  }

  print('기본 API URL 사용: $_defaultApiBaseUrl');
  return _defaultApiBaseUrl;
}
