// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/screens/home_screen.dart';
import 'package:hoseo/screens/camera_screen.dart';
import 'package:hoseo/screens/food_detail_screen.dart';
import 'package:hoseo/screens/profile_screen.dart';
import 'package:hoseo/screens/login_screen.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';

// 전역 키 정의
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite 데이터베이스 설정 - 플랫폼 확인 추가
  try {
    // 웹 환경이 아닐 때만 SQLite 초기화
    if (!kIsWeb) {
      databaseFactory = databaseFactory;

      // 데이터베이스 초기화 확인
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.database; // 이 부분으로 데이터베이스를 미리 초기화합니다
        print('데이터베이스 초기화 성공!');
      } catch (e) {
        print('데이터베이스 초기화 오류: $e');
      }
    } else {
      print('웹 환경에서는 SQLite를 사용하지 않습니다.');
    }
  } catch (e) {
    print('데이터베이스 설정 오류: $e');
  }

  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
    print('Firebase 초기화 성공');
  } catch (e) {
    print('Firebase 초기화 실패: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => FoodProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 FoodProvider 초기화 - 단 한번만 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 첫 프레임이 그려진 후 비동기 초기화 작업 수행
      Provider.of<FoodProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoseoFood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => MainScreen(key: mainScreenKey),
        '/food_detail': (context) => const FoodDetailScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final bool goToProfile;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.goToProfile = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _dataInitialized = false;
  bool _isDisposed = false; // dispose 상태 추적

  final List<Widget> _screens = [
    const HomeScreen(),
    const CameraScreen(),
    const ProfileScreen(),
  ];

  // 외부에서 탭 전환을 위한 메서드
  void navigateToTab(int index) {
    if (_isDisposed || index < 0 || index >= _screens.length) return;

    if (mounted && !_isDisposed) {
      setState(() {
        _currentIndex = index;
      });

      // 홈 탭으로 이동할 때만 데이터 갱신
      if (index == 0) {
        _refreshHomeData();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.goToProfile ? 2 : widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);

    // 앱 시작 시 사용자 및 음식 데이터 로드
    _loadUserData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDisposed) {
      // 앱이 포그라운드로 돌아왔을 때 데이터 새로고침 (캐시 우선 사용)
      _loadUserData(forceRefresh: false);

      // 현재 홈 화면이면 데이터 갱신
      if (_currentIndex == 0 && !_isDisposed) {
        _refreshHomeData();
      }
    }
  }

  // 홈 화면 데이터 갱신 메서드 (캐시 우선 사용)
  Future<void> _refreshHomeData() async {
    if (_isDisposed) return;

    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      // 이미 캐시된 데이터가 있으면 불필요한 로드 방지
      if (foodProvider.foodsForSelectedDate.isEmpty) {
        await foodProvider.loadFoodsByDate(foodProvider.selectedDate);
      }
    } catch (e) {
      print('홈 데이터 갱신 오류: $e');
    }
  }

  Future<void> _loadUserData({bool forceRefresh = true}) async {
    if (_isDisposed) return;

    // 사용자 로그인 상태 확인
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_isDisposed) {
      try {
        // 사용자 정보 로드 (변경이 있을 때만)
        await Provider.of<UserProvider>(context, listen: false).loadUser();

        if (_isDisposed) return;

        // 최초 1회만 전체 데이터 로드, 이후에는 필요한 데이터만 로드
        if (!_dataInitialized || forceRefresh) {
          final foodProvider = Provider.of<FoodProvider>(
            context,
            listen: false,
          );
          await foodProvider.loadFoods();
          if (!_isDisposed) {
            _dataInitialized = true;
          }
        } else {
          // 현재 선택된 날짜의 데이터만 갱신 (캐시 우선 사용)
          if (_currentIndex == 0 && !_isDisposed) {
            _refreshHomeData();
          }
        }
      } catch (e) {
        print('데이터 로드 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_isDisposed) return;

          if (mounted && !_isDisposed) {
            setState(() {
              _currentIndex = index;
            });

            // 홈 탭으로 이동하면 데이터 갱신 (캐시 우선 사용)
            if (index == 0 && !_isDisposed) {
              _refreshHomeData();
            }
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: '식단 촬영'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}
