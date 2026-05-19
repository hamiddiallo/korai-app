class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'KORAI_API_URL',
    defaultValue: 'http://localhost:4000',
  );
}
