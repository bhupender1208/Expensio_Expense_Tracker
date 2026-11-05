abstract interface class AppAuthService {
  Stream<String?> get userIdChanges;

  Future<void> signInWithGoogle();

  Future<void> signOut();
}
