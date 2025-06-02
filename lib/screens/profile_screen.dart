import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/utils/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  String _name = '';
  int _age = 25;
  double _weight = 65.0;
  double _height = 170.0;
  String _gender = '남성';
  int _activityLevel = 2;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user != null) {
      setState(() {
        _name = userProvider.user!.name;
        _age = userProvider.user!.age;
        _weight = userProvider.user!.weight;
        _height = userProvider.user!.height;
        _gender = userProvider.user!.gender;
        _activityLevel = userProvider.user!.activityLevel;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final targetCalories = _calculateTargetCalories();

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.user;

      final user = User(
        id: currentUser?.id,
        name: _name,
        age: _age,
        weight: _weight,
        height: _height,
        gender: _gender,
        activityLevel: _activityLevel,
        targetCalories: targetCalories,
        email: currentUser?.email,
        photoUrl: currentUser?.photoUrl,
        uid: currentUser?.uid,
      );

      try {
        await userProvider.saveUser(user);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('프로필 저장 실패: $e')));
        }
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
      }
    }
  }

  int _calculateTargetCalories() {
    double bmr;

    // 해리스-베네딕트 공식 사용
    if (_gender == '남성') {
      bmr = 88.362 + (13.397 * _weight) + (4.799 * _height) - (5.677 * _age);
    } else {
      bmr = 447.593 + (9.247 * _weight) + (3.098 * _height) - (4.330 * _age);
    }

    // 활동 레벨에 따른 계수
    double activityFactor;
    switch (_activityLevel) {
      case 1:
        activityFactor = 1.2;
        break; // 비활동적
      case 2:
        activityFactor = 1.375;
        break; // 가벼운 활동
      case 3:
        activityFactor = 1.55;
        break; // 중간 활동
      case 4:
        activityFactor = 1.725;
        break; // 활동적
      case 5:
        activityFactor = 1.9;
        break; // 매우 활동적
      default:
        activityFactor = 1.375;
    }

    return (bmr * activityFactor).round();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        centerTitle: true,
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: '로그아웃',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: userProvider.user?.photoUrl != null
                    ? CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(
                          userProvider.user!.photoUrl!,
                        ),
                      )
                    : Image.asset('assets/images/mascot.png', height: 120),
              ),
              if (userProvider.user?.email != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      userProvider.user!.email!,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // 이름
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value?.trim() ?? '';
                },
              ),
              const SizedBox(height: 16),

              // 성별
              const Text('성별', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('남성'),
                      value: '남성',
                      groupValue: _gender,
                      onChanged: (value) {
                        setState(() {
                          _gender = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('여성'),
                      value: '여성',
                      groupValue: _gender,
                      onChanged: (value) {
                        setState(() {
                          _gender = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 나이
              const Text('나이', style: TextStyle(fontSize: 16)),
              Slider(
                value: _age.toDouble(),
                min: 15,
                max: 80,
                divisions: 65,
                label: _age.toString(),
                onChanged: (value) {
                  setState(() {
                    _age = value.round();
                  });
                },
              ),
              Text('$_age세', textAlign: TextAlign.center),
              const SizedBox(height: 16),

              // 키
              const Text('키 (cm)', style: TextStyle(fontSize: 16)),
              Slider(
                value: _height,
                min: 140,
                max: 200,
                divisions: 60,
                label: _height.toString(),
                onChanged: (value) {
                  setState(() {
                    _height = value;
                  });
                },
              ),
              Text(
                '${_height.toStringAsFixed(1)} cm',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 몸무게
              const Text('몸무게 (kg)', style: TextStyle(fontSize: 16)),
              Slider(
                value: _weight,
                min: 40,
                max: 120,
                divisions: 80,
                label: _weight.toString(),
                onChanged: (value) {
                  setState(() {
                    _weight = value;
                  });
                },
              ),
              Text(
                '${_weight.toStringAsFixed(1)} kg',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 활동 수준
              const Text('활동 수준', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              _buildActivityLevelSelector(),
              const SizedBox(height: 24),

              // 예상 칼로리 계산
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('일일 권장 칼로리', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(
                        '${_calculateTargetCalories()} kcal',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('프로필 저장', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLevelSelector() {
    return Column(
      children: [
        _buildActivityLevelTile(
          level: 1,
          title: '비활동적',
          subtitle: '거의 운동을 하지 않음',
        ),
        _buildActivityLevelTile(
          level: 2,
          title: '가벼운 활동',
          subtitle: '주 1-3회 가벼운 운동',
        ),
        _buildActivityLevelTile(
          level: 3,
          title: '중간 활동',
          subtitle: '주 3-5회 중간 강도 운동',
        ),
        _buildActivityLevelTile(
          level: 4,
          title: '활동적',
          subtitle: '주 5-7회 활발한 운동',
        ),
        _buildActivityLevelTile(
          level: 5,
          title: '매우 활동적',
          subtitle: '하루 2회 이상 강도 높은 운동',
        ),
      ],
    );
  }

  Widget _buildActivityLevelTile({
    required int level,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<int>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: level,
      groupValue: _activityLevel,
      onChanged: (value) {
        setState(() {
          _activityLevel = value!;
        });
      },
    );
  }
}
