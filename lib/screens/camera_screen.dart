import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/models/food.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/main.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  bool _isAnalyzing = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isAnalyzing = true;
      });

      try {
        // 이미지 분석 요청
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        final result = await foodProvider.analyzeFoodImage(_imageFile!);

        // 분석 결과로 폼 채우기
        setState(() {
          _nameController.text = result['name'] ?? '';
          _caloriesController.text = (result['calories'] ?? 0).toString();
          _carbsController.text = (result['carbs'] ?? 0).toString();
          _proteinController.text = (result['protein'] ?? 0).toString();
          _fatController.text = (result['fat'] ?? 0).toString();
          _isAnalyzing = false;
        });
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음식 분석 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isAnalyzing = true;
      });

      try {
        // 이미지 분석 요청
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        final result = await foodProvider.analyzeFoodImage(_imageFile!);

        // 분석 결과로 폼 채우기
        setState(() {
          _nameController.text = result['name'] ?? '';
          _caloriesController.text = (result['calories'] ?? 0).toString();
          _carbsController.text = (result['carbs'] ?? 0).toString();
          _proteinController.text = (result['protein'] ?? 0).toString();
          _fatController.text = (result['fat'] ?? 0).toString();
          _isAnalyzing = false;
        });
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음식 분석 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _saveFood() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력하고 이미지를 첨부해주세요')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      // 이미지 업로드
      final imageUrl = await foodProvider.uploadFoodImage(_imageFile!);

      // 음식 데이터 생성
      final food = Food(
        name: _nameController.text,
        calories: int.parse(_caloriesController.text),
        carbs: double.parse(_carbsController.text),
        protein: double.parse(_proteinController.text),
        fat: double.parse(_fatController.text),
        imageUrl: imageUrl,
        dateTime: DateTime.now(),
      );

      // 음식 추가
      await foodProvider.addFood(food);

      // 홈 화면으로 이동하여 결과 표시
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('식단이 성공적으로 저장되었습니다')));

        // 홈 화면으로 이동 및 데이터 갱신
        await foodProvider.loadFoods(); // 식단 데이터 새로고침
        await foodProvider.getDailyCalorieIntake(DateTime.now()); // 칼로리 정보 업데이트

        // 홈 화면으로 이동
        mainScreenKey.currentState?.navigateToTab(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('식단 저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('식단 촬영'), centerTitle: true),
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
                                    image: FileImage(_imageFile!),
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
                          onPressed: _pickFromGallery,
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

                    // 탄수화물, 단백질, 지방 (한 줄에 3개)
                    Row(
                      children: [
                        // 탄수화물
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: const InputDecoration(
                              labelText: '탄수화물 (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '입력하세요';
                              }
                              if (double.tryParse(value) == null) {
                                return '유효한 값';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 단백질
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: const InputDecoration(
                              labelText: '단백질 (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '입력하세요';
                              }
                              if (double.tryParse(value) == null) {
                                return '유효한 값';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 지방
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: const InputDecoration(
                              labelText: '지방 (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '입력하세요';
                              }
                              if (double.tryParse(value) == null) {
                                return '유효한 값';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _saveFood,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isUploading
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
