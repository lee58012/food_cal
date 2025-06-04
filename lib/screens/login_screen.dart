import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/utils/auth_service.dart';
import 'package:hoseo/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('[LoginScreen] initState');
    _checkLoggedInUser();
  }

  // 자동 로그인 확인
  Future<void> _checkLoggedInUser() async {
    print('[LoginScreen] 자동 로그인 확인 중...');
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      print('[LoginScreen] 자동 로그인: ${currentUser.uid}');
      // 이미 로그인된 사용자가 있으면 홈 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      print('[LoginScreen] 로그인된 사용자 없음');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고 또는 마스코트 이미지
              Image.asset('assets/images/mascot.png', height: 150),
              const SizedBox(height: 24),
              const Text(
                'Hoseo Food',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '건강한 식단 관리를 시작하세요',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    print('[LoginScreen] 로그인 버튼 클릭됨');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginFormScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('로그인', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    print('[LoginScreen] 회원가입 버튼 클릭됨');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpFormScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('회원가입', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 로그인 폼 화면
class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    print('[LoginFormScreen] initState');
  }

  @override
  void dispose() {
    print('[LoginFormScreen] dispose');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    print('[LoginFormScreen] 로그인 시도: ${_emailController.text}');
    if (!_formKey.currentState!.validate()) {
      print('[LoginFormScreen] 폼 유효성 검사 실패');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 로그인
      print('[LoginFormScreen] 로그인 요청 중...');
      final user = await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        print('[LoginFormScreen] 로그인 성공: ${user.uid}');
        await userProvider.loadUser();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        print('[LoginFormScreen] 로그인 실패: 사용자 정보 없음');
      }
    } catch (e) {
      print('[LoginFormScreen] 로그인 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 이메일 입력
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!value.contains('@')) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('로그인', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),

              // 회원가입 이동 버튼
              TextButton(
                onPressed: () {
                  print('[LoginFormScreen] 회원가입 화면으로 이동');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const SignUpFormScreen(),
                    ),
                  );
                },
                child: const Text('계정이 없으신가요? 회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 회원가입 폼 화면
class SignUpFormScreen extends StatefulWidget {
  const SignUpFormScreen({super.key});

  @override
  State<SignUpFormScreen> createState() => _SignUpFormScreenState();
}

class _SignUpFormScreenState extends State<SignUpFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    print('[SignUpFormScreen] initState');
  }

  @override
  void dispose() {
    print('[SignUpFormScreen] dispose');
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    print('[SignUpFormScreen] 회원가입 시도: ${_emailController.text}');
    if (!_formKey.currentState!.validate()) {
      print('[SignUpFormScreen] 폼 유효성 검사 실패');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print('[SignUpFormScreen] 회원가입 요청 중...');
      // 회원가입 - 이메일과 비밀번호만 사용
      final user = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        print('[SignUpFormScreen] 회원가입 성공: ${user.uid}');
        await userProvider.saveUser(user);
        // 회원가입 후 프로필 탭으로 바로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(goToProfile: true),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 정보를 입력해주세요'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        print('[SignUpFormScreen] 회원가입 실패: 사용자 정보 없음');
      }
    } catch (e) {
      print('[SignUpFormScreen] 회원가입 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 이메일 입력
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!value.contains('@')) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인 입력
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: !_showPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 다시 입력해주세요';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 회원가입 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('회원가입', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),

              // 로그인 이동 버튼
              TextButton(
                onPressed: () {
                  print('[SignUpFormScreen] 로그인 화면으로 이동');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginFormScreen(),
                    ),
                  );
                },
                child: const Text('이미 계정이 있으신가요? 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
