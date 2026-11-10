/// Configuración de la aplicación.
///
/// La API vive en Render (el mismo backend .NET que ya usa la web y la APK
/// anterior). No se toca ninguna credencial: el login se hace contra
/// /api/auth/login y la base de datos sigue siendo la de Supabase.
///
/// Para apuntar a otro servidor sin tocar el código:
///   flutter run --dart-define=API_BASE=https://mi-servidor
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://sigfv.onrender.com',
  );

  static const String appName = 'SIGFV';
  static const String appVersion = '2.5.0';
}
