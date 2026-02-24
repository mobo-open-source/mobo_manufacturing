import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_manufacturing_app/LoginPage/bloc/login/login_bloc.dart';
import 'package:mobo_manufacturing_app/LoginPage/bloc/login/login_event.dart';
import 'package:mobo_manufacturing_app/LoginPage/bloc/login/login_state.dart';
import 'package:mobo_manufacturing_app/LoginPage/models/session_model.dart';
import 'package:mobo_manufacturing_app/LoginPage/services/auth_service.dart';
import 'package:mobo_manufacturing_app/LoginPage/services/network_service.dart';
import 'package:mobo_manufacturing_app/LoginPage/services/storage_service.dart';
import 'package:mobo_manufacturing_app/core/company/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNetworkService extends Mock implements NetworkService {}
class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}
class MockSessionService extends Mock implements SessionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNetworkService mockNetwork;
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;
  late MockSessionService mockSessionService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockNetwork = MockNetworkService();
    mockAuth = MockAuthService();
    mockStorage = MockStorageService();
    mockSessionService = MockSessionService();
  });

  blocTest<LoginBloc, LoginState>(
    'emits [loading, LoginSuccess] when login submitted succeeds',
    build: () {
      when(() => mockSessionService.login(
        serverUrl: any(named: 'serverUrl'),
        database: any(named: 'database'),
        userLogin: any(named: 'userLogin'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => true);

      when(() => mockSessionService.getSession())
          .thenAnswer((_) async => SessionModel(
        userName: 'Test',
        userLogin: '1',
        userId: 1,
        sessionId: 'sid',
        serverVersion: '16.0',
        userLang: 'en',
        partnerId: 1,
        userTimezone: 'UTC',
        companyId: 1,
        companyName: 'TestCo',
        isSystem: false,
      ));

      when(
            () => mockStorage.saveAccount(any()),
      ).thenAnswer((_) async => {});
      return LoginBloc(mockNetwork, mockAuth, mockStorage, mockSessionService);
    },
    act: (bloc) => bloc.add(LoginSubmitted(
      url: '192.168.220.7:8017',
      protocol: 'http://',
      database: 'jan19',
      username: '1',
      password: '1',
    )),
    expect: () => [
      const LoginState(loading: true),
      isA<LoginSuccess>().having(
            (s) => s.session.userLogin,
        'userLogin',
        '1',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'emits [loading, error] when Authentication fails',
    build: () {
      when(() => mockSessionService.login(
        serverUrl: any(named: 'serverUrl'),
        database: any(named: 'database'),
        userLogin: any(named: 'userLogin'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => false);

      return LoginBloc(mockNetwork, mockAuth, mockStorage, mockSessionService);
    },
    act: (bloc) => bloc.add(LoginSubmitted(
      url: '192.168.220.7:8017',
      protocol: 'http://',
      database: 'jan19',
      username: '1',
      password: '1',
    )),
    expect: () => [
      const LoginState(loading: true),
      isA<LoginState>().having(
            (s) => s.error,
        'error',
        'Authentication failed.',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'emits [loading, error] when session is null',
    build: () {
      when(() => mockSessionService.login(
        serverUrl: any(named: 'serverUrl'),
        database: any(named: 'database'),
        userLogin: any(named: 'userLogin'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => true);

      when(() => mockSessionService.getSession())
          .thenAnswer((_) async => null);

      return LoginBloc(mockNetwork, mockAuth, mockStorage, mockSessionService);
    },
    act: (bloc) => bloc.add(LoginSubmitted(
      url: '192.168.220.7:8017',
      protocol: 'http://',
      database: 'jan19',
      username: '1',
      password: '1',
    )),
    expect: () => [
      const LoginState(loading: true),
      isA<LoginState>().having(
            (s) => s.error,
        'error',
        'Invalid username or password',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'emits [loading, error] when LoginSubmitted throws exception',
    build: () {
      when(() => mockSessionService.login(
        serverUrl: any(named: 'serverUrl'),
        database: any(named: 'database'),
        userLogin: any(named: 'userLogin'),
        password: any(named: 'password'),
      )).thenThrow(Exception("Network Error"));

      return LoginBloc(mockNetwork, mockAuth, mockStorage, mockSessionService);
    },
    act: (bloc) => bloc.add(LoginSubmitted(
      url: '192.168.220.7:8017',
      protocol: 'http://',
      database: 'jan19',
      username: '1',
      password: '1',
    )),
    expect: () => [
      const LoginState(loading: true),
      isA<LoginState>().having(
            (s) => s.error,
        'error',
        'Network connection failed. Please check your internet connection.',
      ),
    ],
  );
}
