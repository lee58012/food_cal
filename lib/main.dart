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
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'firebase_options.dart';

// 전역 키 정의
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite 데이터베이스 설정
  // 이 부분이 중요합니다
  databaseFactory = databaseFactory;

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

    // 데이터베이스 초기화 확인
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database; // 이 부분으로 데이터베이스를 미리 초기화합니다
      print('데이터베이스 초기화 성공!');
    } catch (e) {
      print('데이터베이스 초기화 오류: $e');
    }
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

  final List<Widget> _screens = [
    const HomeScreen(),
    const CameraScreen(),
    const ProfileScreen(),
  ];

  // 외부에서 탭 전환을 위한 메서드
  void navigateToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 데이터 새로고침
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    // 사용자 로그인 상태 확인
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 사용자 정보 로드
        await Provider.of<UserProvider>(context, listen: false).loadUser();

        // 음식 데이터 로드
        await Provider.of<FoodProvider>(context, listen: false).loadFoods();
      } catch (e) {
        print('데이터 로드 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
