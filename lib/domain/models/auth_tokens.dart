import '../../core/utils/json_parsing.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.trim().isNotEmpty;

  AuthTokens copyWith({String? accessToken, String? refreshToken}) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access =
        parseString(json['token_acesso']) ??
        parseString(json['access_token']) ??
        parseString(json['token']) ??
        '';

    final refresh =
        parseString(json['token_atualizacao']) ??
        parseString(json['refresh_token']);

    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token_acesso': accessToken,
      if (refreshToken != null) 'token_atualizacao': refreshToken,
    };
  }
}
