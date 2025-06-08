// ignore_for_file: use_build_context_synchronously, unused_import, unused_field

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/models/food.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/main.dart';
import 'package:hoseo/utils/auth_service.dart';
import 'package:image/image.dart' as img;
import 'package:hoseo/services/api_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _formKey = GlobalKey<FormState>();
  XFile? _imageFile;
  bool _isAnalyzing = false;
  bool _isUploading = false;
  bool _isAddingManually = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();

  String _foodName = '';
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _loadingMessage = '';

  // 필요한 서비스 인스턴스
  late final ApiService _apiService = ApiService();
  late final FoodProvider _foodProvider;

  @override
  void initState() {
    super.initState();
    _foodProvider = Provider.of<FoodProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    _sugarController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    setState(() {
      _isAnalyzing = true;
    });

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      setState(() {
        _imageFile = pickedFile;
      });

      try {
        // 이미지 분석 요청
        _processImage(pickedFile);
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('이미지 분석 실패: ${e.toString()}')));
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카메라 오류: ${e.toString()}')));
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isAnalyzing = true;
    });

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      setState(() {
        _imageFile = pickedFile;
      });

      try {
        // 이미지 분석 요청
        _processImage(pickedFile);
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('이미지 분석 실패: ${e.toString()}')));
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('갤러리 오류: ${e.toString()}')));
      }
    }
  }

  void _processImage(XFile imageFile) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = '이미지 분석 중...';
      _isAnalyzing = true; // 분석 상태 추가
    });

    try {
      // 이미지 분석 및 저장 로직
      final bytes = await imageFile.readAsBytes();

      // 이미지 리사이징 (성능 개선)
      final resizedImage = await _resizeImage(bytes);

      // 로딩 메시지 업데이트
      setState(() {
        _loadingMessage = '음식 분석 중...';
      });

      // 음식 분석 API 호출
      final result = await _foodProvider.analyzeFoodImage(imageFile);

      if (result != null) {
        // 이미지 저장 (Firebase Storage)
        setState(() {
          _loadingMessage = '이미지 저장 중...';
        });

        final imageUrl = await _foodProvider.uploadFoodImage(imageFile);

        // 음식 데이터 생성
        final food = Food(
          id: '', // 빈 ID (Firestore에서 자동 생성)
          name: result['name'] ?? '알 수 없는 음식',
          calories: result['calories'] ?? 0,
          carbs: result['carbs'] ?? 0,
          protein: result['protein'] ?? 0,
          fat: result['fat'] ?? 0,
          sodium: result['sodium'] ?? 0,
          cholesterol: result['cholesterol'] ?? 0,
          sugar: result['sugar'] ?? 0,
          imageUrl: imageUrl ?? '',
          dateTime: DateTime.now(),
        );

        // 데이터 저장 (병렬 처리로 성능 개선)
        setState(() {
          _loadingMessage = '데이터 저장 중...';
        });

        await _foodProvider.addFood(food);

        // 성공 메시지 표시
        setState(() {
          _isLoading = false;
          _isAnalyzing = false;
        });

        // 성공 알림 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('식단이 성공적으로 추가되었습니다'),
            backgroundColor: Colors.green,
          ),
        );

        // 홈 화면으로 이동 전에 데이터 갱신 강제화
        _foodProvider.refreshData();

        // 홈 화면으로 이동
        Navigator.pop(context, true);
      } else {
        // 분석 실패
        setState(() {
          _isLoading = false;
          _isAnalyzing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('음식 분석에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('이미지 처리 오류: $e');
      setState(() {
        _isLoading = false;
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 이미지 리사이징 (성능 개선)
  Future<Uint8List> _resizeImage(Uint8List imageBytes) async {
    try {
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return imageBytes;

      // 원본 이미지가 너무 크면 리사이징
      if (originalImage.width > 1000 || originalImage.height > 1000) {
        final img.Image resizedImage = img.copyResize(
          originalImage,
          width: 1000,
          height: (1000 * originalImage.height / originalImage.width).round(),
        );

        // 이미지 품질 조정 (80%)
        return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 80));
      }

      return imageBytes;
    } catch (e) {
      print('이미지 리사이징 오류: $e');
      return imageBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('식단 촬영'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
                );
              }
            },
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: _isAnalyzing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('음식을 분석하고 있습니다...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지 선택 영역
                    Center(
                      child: GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(File(_imageFile!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _imageFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('사진을 촬영하세요'),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 이미지 선택 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('카메라'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('갤러리'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 음식 정보 입력 폼
                    const Text(
                      '음식 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 음식 이름
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '음식 이름',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '음식 이름을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 칼로리
                    TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: '칼로리 (kcal)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_fire_department),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '칼로리를 입력하세요';
                        }
                        if (int.tryParse(value) == null) {
                          return '유효한 숫자를 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 영양소 입력 필드
                    TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: '탄수화물 (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '탄수화물을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(
                        labelText: '단백질 (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '단백질을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: '지방 (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '지방을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _sugarController,
                      decoration: const InputDecoration(
                        labelText: '총당류 (g)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _sodiumController,
                      decoration: const InputDecoration(
                        labelText: '나트륨 (mg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cholesterolController,
                      decoration: const InputDecoration(
                        labelText: '콜레스테롤 (mg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _processImage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                '식단 저장하기',
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
