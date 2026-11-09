import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:hakikisha/core/errors.dart';
import 'package:hakikisha/features/auth/auth_controller.dart';
import 'package:hakikisha/features/auth/auth_repository.dart';
import 'package:hakikisha/models/user.dart';

const testUser = User(
  id: 'user-1',
  email: 'jane@example.com',
  fullName: 'Jane Doe',
  country: 'Rwanda',
  role: 'consumer',
  isVerified: true,
  isAdmin: false,
);

/// Starts signed in as [user] (or signed out when null) without Firebase.
class FakeAuthController extends AuthController {
  FakeAuthController([this.user]);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Records registrations instead of calling Firebase.
class FakeAuthRepository implements AuthRepository {
  final registered = <Map<String, String>>[];

  @override
  fb.User? get currentAccount => null;

  @override
  Stream<fb.User?> accountChanges() => const Stream.empty();

  @override
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String country,
    required String role,
  }) async {
    if (email == 'taken@example.com') {
      throw const AppException('That email is already registered.', code: 'email-already-in-use');
    }
    registered.add({'fullName': fullName, 'email': email, 'password': password, 'country': country, 'role': role});
    return User(
      id: 'user-2',
      email: email,
      fullName: fullName,
      country: country,
      role: role,
      isVerified: false,
      isAdmin: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
