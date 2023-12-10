import 'package:shared_preferences/shared_preferences.dart';

class SharedCache {
  static const String _apiKeyKey = "_apiKey";

  static Future<String?> getApiKey() async {
   final preferences = await SharedPreferences.getInstance();
   return preferences.getString(_apiKeyKey);
  }

  static Future<bool> setApiKey(String apiKey) async =>
      SharedPreferences.getInstance().then(
        (value) => value.setString(_apiKeyKey, apiKey),
      );
}
