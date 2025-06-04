import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/utils/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

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
  bool _isProfileComplete = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _ageController.text = user.age.toString();
        _weightController.text = user.weight.toString();
        _heightController.text = user.height.toString();
        _gender = user.gender;
        _activityLevel = user.activityLevel;
        _medicalCondition = user.medicalCondition;
        _currentPhotoUrl = user.photoUrl;

        // 프로필이 기본값인지 확인
        _isProfileComplete =
            !(user.name == '사용자' &&
                user.age == 30 &&
                user.weight == 65.0 &&
                user.height == 170.0);
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, // 이미지 크기 제한 (Firestore 문서 크기 제한 때문)
        maxHeight: 400,
        imageQuality: 70, // 이미지 품질 조정
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
      // 이미지 파일을 바이트로 읽기
      final bytes = await _imageFile!.readAsBytes();

      // 이미지 크기 확인 (1MB 제한)
      if (bytes.length > 1024 * 1024) {
        // 이미지가 너무 크면 경고 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 크기가 너무 큽니다. 더 작은 이미지를 선택해주세요.')),
        );
        setState(() {
          _isLoading = false;
        });
        return _currentPhotoUrl;
      }

      // 바이트를 Base64 문자열로 인코딩
      final base64String = base64Encode(bytes);

      // Base64 문자열 앞에 데이터 형식 추가
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      print('이미지 인코딩 완료: ${dataUrl.length} 문자');

      setState(() {
        _isLoading = false;
      });

      return dataUrl;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('이미지 처리 오류: $e');
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
      );

      if (!mounted) return;

      setState(() {
        _isProfileComplete = true;
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

    // 입력값이 없거나 유효하지 않은 경우 기본값 사용
    double weight = double.tryParse(_weightController.text) ?? 65.0;
    double height = double.tryParse(_heightController.text) ?? 170.0;
    int age = int.tryParse(_ageController.text) ?? 30;

    // 해리스-베네딕트 공식 사용
    if (_gender == '남성') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
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

    // 건강 상태에 따른 조정
    double medicalFactor = 1.0;
    if (_medicalCondition == '당뇨') {
      medicalFactor = 0.9; // 당뇨 환자는 일반적으로 10% 정도 칼로리 제한
    } else if (_medicalCondition == '고혈압') {
      medicalFactor = 0.95; // 고혈압 환자는 5% 정도 칼로리 제한
    } else if (_medicalCondition == '고지혈증') {
      medicalFactor = 0.9; // 고지혈증 환자는 10% 정도 칼로리 제한
    }

    return (bmr * activityFactor * medicalFactor).round();
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
                    if (!_isProfileComplete) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '프로필 정보를 입력해주세요',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '정확한 식단 관리를 위해 아래 정보를 입력해주세요.',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 프로필 사진
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_currentPhotoUrl != null &&
                                      _currentPhotoUrl!.startsWith(
                                        'data:image',
                                      ))
                                ? MemoryImage(
                                    base64Decode(
                                      _currentPhotoUrl!.split(',')[1],
                                    ),
                                  )
                                : (_currentPhotoUrl != null)
                                ? NetworkImage(_currentPhotoUrl!)
                                : null as ImageProvider?,
                            child:
                                (_imageFile == null && _currentPhotoUrl == null)
                                ? const Icon(Icons.person, size: 60)
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

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: !_isProfileComplete
                              ? Colors.blue
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          !_isProfileComplete ? '프로필 완성하기' : '프로필 저장',
                          style: const TextStyle(
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
