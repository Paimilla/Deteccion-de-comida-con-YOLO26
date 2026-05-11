class AppRoutes {
  // Fitia Navigation Tabs (Bottom Navigation)
  static const hoy = '/hoy'; // Dashboard - was 'home'
  static const plan = '/plan'; // Meal breakdown - was 'history'
  static const explorar = '/explorar'; // Search & recipes
  static const progreso = '/progreso'; // Statistics
  static const perfil = '/perfil'; // Settings

  // Legacy/Kept for backwards compatibility
  static const home = hoy;
  static const history = plan;
  static const settings = perfil;
  static const statistics = progreso;

  // Food Entry Flows
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const onboarding = '/onboarding';
  static const addFoodHub = '/add-food';
  static const scannerCamera = '/scanner/camera';
  static const scannerBarcode = '/scanner/barcode';
  static const search = '/search';
  static const recipes = '/recipes';
  static const voice = '/voice';
  static const manualEntry = '/manual';

  // Legacy tabs (kept for now, can be deprecated)
  static const achievements = '/achievements';
  static const hydration = '/hydration';
  static const assistant = '/assistant';
}
