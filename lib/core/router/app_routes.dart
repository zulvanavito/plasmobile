abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String onboardingIdentity = '/onboarding/identity';
  static const String onboardingClass = '/onboarding/class';

  static const String learn = '/learn';
  static const String history = '/history';
  static const String profile = '/profile';

  static String materialDetail(String materialId) => '/materials/$materialId';
  static String subMaterialRead(String submaterialId) =>
      '/sub-materials/$submaterialId';
  static String exerciseSession(String exerciseId) =>
      '/exercises/$exerciseId/session';
  static String exerciseReview(String attemptId) =>
      '/exercise-attempts/$attemptId/review';
  static String testSession(String testId) => '/tests/$testId/session';
  static String testResult(String attemptId) =>
      '/test-attempts/$attemptId/result';
}
