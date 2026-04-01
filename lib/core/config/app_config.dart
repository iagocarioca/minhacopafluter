class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.webAppUrl,
    required this.allowedHosts,
  });

  final String apiBaseUrl;
  final Uri webAppUrl;
  final Set<String> allowedHosts;

  static const String _apiBaseRaw = String.fromEnvironment(
    'APP_API_BASE',
    defaultValue: 'https://api.minhacopa.online',
  );

  static const String _webAppRaw = String.fromEnvironment(
    'APP_WEB_URL',
    defaultValue: 'https://minhacopa.online',
  );

  static const String _allowedHostsRaw = String.fromEnvironment(
    'APP_ALLOWED_HOSTS',
    defaultValue:
        'minhacopa.online,www.minhacopa.online,api.minhacopa.online,localhost,127.0.0.1,10.0.2.2',
  );

  factory AppConfig.fromEnvironment() {
    final webUri = _normalizeUri(_webAppRaw);
    final apiUri = _normalizeUri(_apiBaseRaw);

    final hosts = _allowedHostsRaw
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();

    if (webUri.host.isNotEmpty) {
      hosts.add(webUri.host.toLowerCase());
    }
    if (apiUri.host.isNotEmpty) {
      hosts.add(apiUri.host.toLowerCase());
    }

    return AppConfig(
      apiBaseUrl: _normalizeBaseUrl(_apiBaseRaw),
      webAppUrl: webUri,
      allowedHosts: hosts,
    );
  }

  String? resolveApiImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final raw = value.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final normalizedPath = raw.startsWith('/') ? raw : '/$raw';
    return '$apiBaseUrl$normalizedPath';
  }

  static Uri _normalizeUri(String value) {
    final raw = value.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.parse(raw);
    }
    return Uri.parse('https://$raw');
  }

  static String _normalizeBaseUrl(String value) {
    final uri = _normalizeUri(value);
    var normalized = uri.toString();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
