enum server {
  dev,
  maps;

  String get value {
    switch (this) {
      case server.dev:
        return 'dev';
      case server.maps:
        return 'maps';
    }
  }
}

class AppConfig {
  static server selectedServer= server.dev;


  /// Whether the Picture-in-Picture (PiP) experience is available to the host
  /// app integrating this SDK. When `false`, navigation always stays
  /// full-screen, no floating mini-window is shown and native PiP is never
  /// requested — the SDK behaves as if PiP does not exist.
  static bool enablePip = false;

  static void setEnablePip(bool? value) {
    if (value != null) enablePip = value;
  }

  static String get baseUrl {
    return 'https://${selectedServer.value}.iwayplus.in';
  }

  static String? _cmsId;


  static set cmsId(String? value) {
    _cmsId = value;
  }

  static String? get cmsId => _cmsId;

  static void setBaseUrl(server server){
    selectedServer = server;
    _apiKey = _defaultApiKey;
  }

  static String get encryptionKey {
    if (baseUrl == 'https://dev.iwayplus.in') {
      return 'rtyHuAxNZPIyx1YMCXQJcx6dX1ev0/svf79IWd1teX0=';
    } else {
      //this api key is for udit soni
      return 'TtcuUZ1JK26FJ7rxqp36OCQflajb1RYIIiv481l764k=';
    }
  }

  static String get Authorization {
    if (baseUrl == 'https://dev.iwayplus.in') {
      return 'd52f6110-c69a-11ef-aa4e-e7aa7912987a';
    } else {
      return '023357e0-cf4f-11ef-8c00-45832f202b2e';
    }
  }

  static String _apiKey = _defaultApiKey;

  static String get _defaultApiKey {
    return baseUrl == 'https://dev.iwayplus.in'
        ? '7cc62870-d67e-11f0-91ed-2f0eb903e7db'
        : '98f13750-c905-11f0-b802-d78f56bdcf4f';
  }

  static String get apiKey => _apiKey;

  static set apiKey(String? value) {
    _apiKey = (value != null && value.isNotEmpty)
        ? value
        : _defaultApiKey;
  }

  static String apiKeyUsingBaseURL(String baseURL){
    if (baseURL == 'https://dev.iwayplus.in') {
      return '7cc62870-d67e-11f0-91ed-2f0eb903e7db';
    } else {
      //this api key is for udit soni
      return '98f13750-c905-11f0-b802-d78f56bdcf4f';
    }
  }

  static String appID = "com.iwayplus.rni";


}