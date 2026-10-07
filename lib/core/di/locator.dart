import 'package:get_it/get_it.dart';

import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/directory_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/institute_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/theory_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/storage_service.dart';
import '../network/connectivity_service.dart';
import '../network/dio_client.dart';
import '../storage/local_store.dart';
import '../storage/prefs_storage.dart';
import '../storage/secure_storage.dart';

/// Service locator. Thunks and view models fetch dependencies from here,
/// so widgets never construct services themselves.
final locator = GetIt.instance;

Future<void> setupLocator() async {
  // Storage (async init first)
  locator
    ..registerSingleton<PrefsStorage>(await PrefsStorage.create())
    ..registerSingleton<LocalStore>(await LocalStore.create())
    ..registerLazySingleton<SecureStorage>(SecureStorage.new);

  // Network
  locator
    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)
    ..registerLazySingleton<DioClient>(() => DioClient(locator<ConnectivityService>()))
    ..registerLazySingleton<ApiService>(() => ApiService(locator<DioClient>()));

  // Firebase services
  locator
    ..registerLazySingleton<AuthService>(AuthService.new)
    ..registerLazySingleton<StorageService>(StorageService.new)
    ..registerLazySingleton<NotificationService>(
      () => NotificationService(locator<SecureStorage>()),
    );

  // Repositories
  locator
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(locator<AuthService>(), locator<LocalStore>(), locator<ApiService>()),
    )
    ..registerLazySingleton<UserRepository>(UserRepository.new)
    ..registerLazySingleton<InstituteRepository>(InstituteRepository.new)
    ..registerLazySingleton<PaymentRepository>(
      () => PaymentRepository(locator<StorageService>()),
    )
    ..registerLazySingleton<EventRepository>(EventRepository.new)
    ..registerLazySingleton<MediaRepository>(() => MediaRepository(locator<StorageService>()))
    ..registerLazySingleton<AttendanceRepository>(AttendanceRepository.new)
    ..registerLazySingleton<DirectoryRepository>(DirectoryRepository.new)
    ..registerLazySingleton<ChatRepository>(ChatRepository.new)
    ..registerLazySingleton<BatchRepository>(BatchRepository.new)
    ..registerLazySingleton<TheoryRepository>(
      () => TheoryRepository(locator<StorageService>(), locator<LocalStore>()),
    )
    ..registerLazySingleton<AnnouncementRepository>(
      () => AnnouncementRepository(locator<LocalStore>()),
    );
}
