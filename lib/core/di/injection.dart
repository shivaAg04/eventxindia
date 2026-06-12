import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The global service locator (composition root).
///
/// This is the only place in the app that wires concrete implementations to
/// the abstract repository/service interfaces defined in the domain layer.
/// Swapping the backend (e.g. Firebase -> REST) means changing the bindings
/// registered here and re-running code generation; the domain and
/// presentation layers stay untouched.
final GetIt getIt = GetIt.instance;

/// Initializes dependency injection for the application.
///
/// Call this once during app bootstrap (see `main.dart`) before running the
/// widget tree. The generated [initInjection] wires every `@injectable`,
/// `@singleton`, and `@module` registration discovered by the
/// `injectable_generator` build pipeline.
@InjectableInit(
  initializerName: 'initInjection',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async => getIt.initInjection();
