class RegisterRequest {
  final String fullName, birthDate, email, phone, password;
  const RegisterRequest({
    required this.fullName,
    required this.birthDate,
    required this.email,
    required this.phone,
    required this.password,
  });
  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'birthDate': birthDate,
        'email': email,
        'phone': phone,
        'password': password,
      };
}

class LoginRequest {
  final String email, password;
  const LoginRequest({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class LoginResponse {
  final String token;
  final int expiresIn;
  LoginResponse({required this.token, required this.expiresIn});
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        expiresIn: json['expiresIn'] as int,
      );
}
