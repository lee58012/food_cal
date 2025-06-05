import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/utils/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:hoseo/models/nutrition_recommendation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = '남성';
  int _activityLevel = 2;
  String _medicalCondition = '정상';
  File? _imageFile;
  String? _currentPhotoUrl;
  bool _isLoading = false;
  NutritionRecommendation? _nutritionRec;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser();

      final user = userProvider.user;
      if (user != null) {
        setState(() {
          _nameController.text = user.name!;
          _ageController.text = user.age.toString();
          _weightController.text = user.weight.toString();
          _heightController.text = user.height.toString();
          _gender = user.gender;
          _activityLevel = user.activityLevel;
          _medicalCondition = user.medicalCondition;
          _currentPhotoUrl = user.photoUrl;
          _user = user;

          // 영양소 권장량 계산
          _nutritionRec = NutritionRecommendation.fromUser(user);
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 선택 오류: $e')));
    }
  }

  Future<String?> _processImage() async {
    if (_imageFile == null) return _currentPhotoUrl;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();

      if (bytes.length > 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 크기가 너무 큽니다. 더 작은 이미지를 선택해주세요.')),
        );
        setState(() {
          _isLoading = false;
        });
        return _currentPhotoUrl;
      }

      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      setState(() {
        _isLoading = false;
      });

      return dataUrl;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 처리 실패: $e')));
      return _currentPhotoUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final photoUrl = await _processImage();

      if (!mounted) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateUser(
        name: _nameController.text,
        age: int.tryParse(_ageController.text) ?? 30,
        weight: double.tryParse(_weightController.text) ?? 65.0,
        height: double.tryParse(_heightController.text) ?? 170.0,
        gender: _gender,
        activityLevel: _activityLevel,
        photoUrl: photoUrl,
        medicalCondition: _medicalCondition,
        targetCalories: _calculateTargetCalories().toDouble(),
      );

      if (!mounted) return;

      // 저장 성공 후 상태 업데이트
      setState(() {
        _currentPhotoUrl = photoUrl;
        _imageFile = null; // 선택된 파일 초기화

        // _user 객체도 업데이트
        if (_user != null) {
          _user = _user!.copyWith(photoUrl: photoUrl);
        }

        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
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

    double weight = double.tryParse(_weightController.text) ?? 65.0;
    double height = double.tryParse(_heightController.text) ?? 170.0;
    int age = int.tryParse(_ageController.text) ?? 30;

    if (_gender == '남성') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    double activityFactor;
    switch (_activityLevel) {
      case 1:
        activityFactor = 1.2;
        break;
      case 2:
        activityFactor = 1.375;
        break;
      case 3:
        activityFactor = 1.55;
        break;
      case 4:
        activityFactor = 1.725;
        break;
      case 5:
        activityFactor = 1.9;
        break;
      default:
        activityFactor = 1.375;
    }

    double medicalFactor = 1.0;
    if (_medicalCondition == '당뇨') {
      medicalFactor = 0.9;
    } else if (_medicalCondition == '고혈압') {
      medicalFactor = 0.95;
    } else if (_medicalCondition == '고지혈증') {
      medicalFactor = 0.9;
    }

    return (bmr * activityFactor * medicalFactor).round();
  }

  void _updateNutritionRecommendation() {
    double weight = double.tryParse(_weightController.text) ?? 65.0;
    double height = double.tryParse(_heightController.text) ?? 170.0;
    int age = int.tryParse(_ageController.text) ?? 30;

    final tempUser = User(
      name: _nameController.text,
      age: age,
      weight: weight,
      height: height,
      gender: _gender,
      activityLevel: _activityLevel,
      targetCalories: _calculateTargetCalories().toDouble(),
      medicalCondition: _medicalCondition,
    );

    setState(() {
      _nutritionRec = NutritionRecommendation.fromUser(tempUser);
    });
  }

  ImageProvider? _getProfileImage() {
    // 새로 선택한 이미지가 있으면 우선 표시
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }

    // 기존 프로필 이미지가 있으면 표시
    if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      // base64 데이터인지 확인
      if (_currentPhotoUrl!.startsWith('data:image/')) {
        // base64 데이터는 타임스탬프 없이 그대로 사용
        try {
          // data:image/jpeg;base64, 부분 제거
          final base64String = _currentPhotoUrl!.split(',')[1];
          final bytes = base64Decode(base64String);
          return MemoryImage(bytes);
        } catch (e) {
          return null;
        }
      } else {
        // 일반 URL인 경우에만 타임스탬프 추가
        final imageUrl =
            '$_currentPhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        return NetworkImage(imageUrl);
      }
    }

    // _user의 photoUrl도 확인
    if (_user?.photoUrl != null && _user!.photoUrl!.isNotEmpty) {
      if (_user!.photoUrl!.startsWith('data:image/')) {
        // base64 데이터는 타임스탬프 없이 그대로 사용
        try {
          final base64String = _user!.photoUrl!.split(',')[1];
          final bytes = base64Decode(base64String);
          return MemoryImage(bytes);
        } catch (e) {
          return null;
        }
      } else {
        // 일반 URL인 경우에만 타임스탬프 추가
        final imageUrl =
            '${_user!.photoUrl!}?t=${DateTime.now().millisecondsSinceEpoch}';
        return NetworkImage(imageUrl);
      }
    }

    return null;
  }

  Widget _buildNutrientCard(
    String title,
    double value,
    String unit,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프로필 사진 (ImageHelper 사용으로 수정)
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _getProfileImage(),
                            child: _getProfileImage() == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),

                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 20,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 이름
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '이름을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 나이
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: '나이',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '나이를 입력해주세요';
                        }
                        if (int.tryParse(value) == null) {
                          return '올바른 숫자를 입력해주세요';
                        }
                        return null;
                      },
                      onChanged: (_) => _updateNutritionRecommendation(),
                    ),
                    const SizedBox(height: 16),

                    // 체중
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: '체중 (kg)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '체중을 입력해주세요';
                        }
                        if (double.tryParse(value) == null) {
                          return '올바른 숫자를 입력해주세요';
                        }
                        return null;
                      },
                      onChanged: (_) => _updateNutritionRecommendation(),
                    ),
                    const SizedBox(height: 16),

                    // 신장
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: '신장 (cm)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '신장을 입력해주세요';
                        }
                        if (double.tryParse(value) == null) {
                          return '올바른 숫자를 입력해주세요';
                        }
                        return null;
                      },
                      onChanged: (_) => _updateNutritionRecommendation(),
                    ),
                    const SizedBox(height: 24),

                    // 성별
                    const Text(
                      '성별',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                                _updateNutritionRecommendation();
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
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 건강 상태
                    const Text(
                      '건강 상태',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('정상'),
                            value: '정상',
                            groupValue: _medicalCondition,
                            onChanged: (value) {
                              setState(() {
                                _medicalCondition = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('당뇨'),
                            value: '당뇨',
                            groupValue: _medicalCondition,
                            onChanged: (value) {
                              setState(() {
                                _medicalCondition = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('고혈압'),
                            value: '고혈압',
                            groupValue: _medicalCondition,
                            onChanged: (value) {
                              setState(() {
                                _medicalCondition = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('고지혈증'),
                            value: '고지혈증',
                            groupValue: _medicalCondition,
                            onChanged: (value) {
                              setState(() {
                                _medicalCondition = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 활동 수준
                    const Text(
                      '활동 수준',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          RadioListTile<int>(
                            title: const Text('비활동적'),
                            subtitle: const Text('거의 운동을 하지 않음'),
                            value: 1,
                            groupValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('가벼운 활동'),
                            subtitle: const Text('주 1-3회 가벼운 운동'),
                            value: 2,
                            groupValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('중간 활동'),
                            subtitle: const Text('주 3-5회 중간 강도 운동'),
                            value: 3,
                            groupValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('활동적'),
                            subtitle: const Text('주 5-7회 활발한 운동'),
                            value: 4,
                            groupValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('매우 활동적'),
                            subtitle: const Text('하루 2회 이상 강도 높은 운동'),
                            value: 5,
                            groupValue: _activityLevel,
                            onChanged: (value) {
                              setState(() {
                                _activityLevel = value!;
                                _updateNutritionRecommendation();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 예상 칼로리 계산
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '일일 권장 칼로리',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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

                    // 권장 영양소 정보 (홈 화면과 동일한 스타일로 개선)
                    if (_nutritionRec != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '권장 영양소',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '권장량 정보',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2x3 그리드 레이아웃으로 변경
                      Column(
                        children: [
                          // 첫 번째 행: 탄수화물, 단백질
                          Row(
                            children: [
                              Expanded(
                                child: _buildNutrientCard(
                                  '탄수화물',
                                  _nutritionRec!.recommendedCarbs,
                                  'g',
                                  Colors.orange.shade100,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildNutrientCard(
                                  '단백질',
                                  _nutritionRec!.recommendedProtein,
                                  'g',
                                  Colors.red.shade100,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 두 번째 행: 지방, 당류
                          Row(
                            children: [
                              Expanded(
                                child: _buildNutrientCard(
                                  '지방',
                                  _nutritionRec!.recommendedFat,
                                  'g',
                                  Colors.blue.shade100,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildNutrientCard(
                                  '당류',
                                  _nutritionRec!.recommendedSugar,
                                  'g',
                                  Colors.purple.shade100,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 세 번째 행: 나트륨, 콜레스테롤
                          Row(
                            children: [
                              Expanded(
                                child: _buildNutrientCard(
                                  '나트륨',
                                  _nutritionRec!.recommendedSodium,
                                  'mg',
                                  Colors.green.shade100,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildNutrientCard(
                                  '콜레스테롤',
                                  _nutritionRec!.recommendedCholesterol,
                                  'mg',
                                  Colors.teal.shade100,
                                  Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          '프로필 저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
