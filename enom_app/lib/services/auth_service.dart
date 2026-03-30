import 'dart:io' show Platform;
import 'dart:typed_data';
import 'api_service.dart';
import 'notification_service.dart';

class AuthService {
  /// Register a new user. Sends OTP to email.
  static Future<({bool success, String message, int statusCode})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await ApiService.post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    return (
      success: statusCode == 201,
      message: message,
      statusCode: statusCode,
    );
  }

  /// Verify OTP after registration. Returns token on success.
  static Future<({bool success, String message, String? token, Map<String, dynamic>? user})> verifyOtp({
    required String otp,
  }) async {
    final result = await ApiService.post('/api/auth/verify-otp', {
      'otp': otp,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    if (statusCode == 200) {
      final token = body['token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;

      if (token != null) {
        await ApiService.saveToken(token);
      }
      if (user != null) {
        await ApiService.saveUser(user);
      }

      return (
        success: true,
        message: message,
        token: token,
        user: user,
      );
    }

    return (
      success: false,
      message: message,
      token: null as String?,
      user: null as Map<String, dynamic>?,
    );
  }

  /// Resend OTP to email.
  static Future<({bool success, String message})> resendOtp({
    required String email,
  }) async {
    final result = await ApiService.post('/api/auth/resend-otp', {
      'email': email,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    return (
      success: statusCode == 200,
      message: message,
    );
  }

  /// Login with email and password.
  static Future<({bool success, String message, int statusCode, String? token, Map<String, dynamic>? user})> login({
    required String email,
    required String password,
  }) async {
    // Get FCM token and platform for push notifications
    final deviceToken = await NotificationService.getToken();
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web';

    final result = await ApiService.post('/api/auth/login', {
      'email': email,
      'password': password,
      if (deviceToken != null) 'device_token': deviceToken,
      'platform': platform,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    if (statusCode == 200) {
      final token = body['token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;

      if (token != null) {
        await ApiService.saveToken(token);
      }
      if (user != null) {
        await ApiService.saveUser(user);
      }

      return (
        success: true,
        message: message,
        statusCode: statusCode,
        token: token,
        user: user,
      );
    }

    return (
      success: false,
      message: message,
      statusCode: statusCode,
      token: null as String?,
      user: null as Map<String, dynamic>?,
    );
  }

  /// Forgot password — sends OTP to email.
  static Future<({bool success, String message})> forgotPassword({
    required String email,
  }) async {
    final result = await ApiService.post('/api/auth/forgot-password', {
      'email': email,
    });

    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'If an account exists, an OTP has been sent.';

    return (
      success: true,
      message: message,
    );
  }

  /// Step 2: Verify password reset OTP. Returns reset_token on success.
  static Future<({bool success, String message, String? resetToken})> verifyResetOtp({
    required String otp,
  }) async {
    final result = await ApiService.post('/api/auth/verify-reset-otp', {
      'otp': otp,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    if (statusCode == 200) {
      final resetToken = body['reset_token'] as String?;
      return (
        success: true,
        message: message,
        resetToken: resetToken,
      );
    }

    return (
      success: false,
      message: message,
      resetToken: null as String?,
    );
  }

  /// Step 3: Reset password with reset_token.
  static Future<({bool success, String message, String? token})> resetPassword({
    required String resetToken,
    required String password,
  }) async {
    final result = await ApiService.post('/api/auth/reset-password', {
      'reset_token': resetToken,
      'password': password,
    });

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    if (statusCode == 200) {
      final token = body['token'] as String?;
      if (token != null) {
        await ApiService.saveToken(token);
      }
      return (
        success: true,
        message: message,
        token: token,
      );
    }

    return (
      success: false,
      message: message,
      token: null as String?,
    );
  }

  /// Logout — revokes the token and unregisters device.
  static Future<({bool success, String message})> logout() async {
    try {
      final deviceToken = await NotificationService.getToken();
      await ApiService.post('/api/auth/logout', {
        if (deviceToken != null) 'device_token': deviceToken,
      }, auth: true);
    } catch (_) {
      // Even if API call fails, clear local data
    }
    await ApiService.removeToken();
    return (success: true, message: 'Logged out');
  }

  /// Update user profile (multipart for image upload).
  static Future<({bool success, String message, Map<String, dynamic>? user})> updateProfile({
    String? name,
    String? username,
    String? gender,
    String? dob,
    String? bio,
    String? location,
    String? profession,
    String? country,
    String? city,
    String? region,
    String? contentPreferences,
    String? socialPersonality,
    String? languages,
    String? privacySetting,
    String? interestIds,
    String? imagePath,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;
    if (username != null) fields['username'] = username;
    if (gender != null) fields['gender'] = gender;
    if (dob != null) fields['dob'] = dob;
    if (bio != null) fields['bio'] = bio;
    if (location != null) fields['location'] = location;
    if (profession != null) fields['profession'] = profession;
    if (country != null) fields['country'] = country;
    if (city != null) fields['city'] = city;
    if (region != null) fields['region'] = region;
    if (contentPreferences != null) fields['content_preferences'] = contentPreferences;
    if (socialPersonality != null) fields['social_personality'] = socialPersonality;
    if (languages != null) fields['languages'] = languages;
    if (privacySetting != null) fields['privacy_setting'] = privacySetting;
    if (interestIds != null) fields['interest_ids'] = interestIds;

    final hasImage = imageBytes != null || imagePath != null;

    final result = await ApiService.postMultipart(
      '/api/user/profile',
      fields: fields,
      filePath: imagePath,
      fileField: hasImage ? 'profile_image' : null,
      fileBytes: imageBytes,
      fileName: imageFileName,
      auth: true,
    );

    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;
    final message = (body['message'] as String?) ?? 'Something went wrong';

    if (statusCode == 200) {
      final user = body['user'] as Map<String, dynamic>?;
      if (user != null) {
        await ApiService.saveUser(user);
      }
      return (success: true, message: message, user: user);
    }

    return (success: false, message: message, user: null as Map<String, dynamic>?);
  }

  /// Get user profile.
  static Future<({bool success, Map<String, dynamic>? user})> getProfile() async {
    final result = await ApiService.get('/api/user/profile', auth: true);
    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;

    if (statusCode == 200) {
      final user = body['user'] as Map<String, dynamic>?;
      if (user != null) {
        await ApiService.saveUser(user);
      }
      return (success: true, user: user);
    }

    return (success: false, user: null as Map<String, dynamic>?);
  }

  /// Get all available interests.
  static Future<({bool success, List<Map<String, dynamic>> interests})> getInterests() async {
    final result = await ApiService.get('/api/interests');
    final statusCode = result['statusCode'] as int;
    final body = result['body'] as Map<String, dynamic>;

    if (statusCode == 200) {
      final raw = body['interests'] as List<dynamic>? ?? [];
      final interests = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return (success: true, interests: interests);
    }

    return (success: false, interests: <Map<String, dynamic>>[]);
  }
}
