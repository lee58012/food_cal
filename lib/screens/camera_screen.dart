// ignore_for_file: use_build_context_synchronously, unused_import, unused_field, non_constant_identifier_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/models/food.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/main.dart';
import 'package:hoseo/utils/auth_service.dart';

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
  final _sodiumController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _sugarController = TextEditingController();
  bool _isAnalyzing = false;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _isAddingManually = false;
  String _foodName = '';

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
          _nameController.text = result['name'] ?? '비빔밥';
          _caloriesController.text = (result['calories'] ?? 0).toString();
          _carbsController.text = (result['carbs'] ?? 0).toString();
          _proteinController.text = (result['protein'] ?? 0).toString();
          _fatController.text = (result['fat'] ?? 0).toString();
          _sodiumController.text = (result['sodium'] ?? 0).toString();
          _cholesterolController.text = (result['cholesterol'] ?? 0).toString();
          _sugarController.text = (result['sugar'] ?? 0).toString();
          _foodName = result['name'] ?? '';
          _isAnalyzing = false;
          _isAddingManually = true;
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
          _sodiumController.text = (result['sodium'] ?? 0).toString();
          _cholesterolController.text = (result['cholesterol'] ?? 0).toString();
          _sugarController.text = (result['sugar'] ?? 0).toString();
          _foodName = result['name'] ?? '';
          _isAnalyzing = false;
          _isAddingManually = true;
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
    // 중복 저장 방지
    if (_isSaving) {
      print('이미 저장 중입니다. 중복 호출 방지');
      return;
    }

    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력하고 이미지를 첨부해주세요')));
      return;
    }

    setState(() {
      _isUploading = true;
      _isSaving = true; // 저장 시작
    });

    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      // 이미지 업로드
      final imageUrl = await foodProvider.uploadFoodImage(_imageFile!);
      if (imageUrl == null) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 음식 데이터 생성 및 저장 (한 번만 호출)
      final food = Food(
        food_name: _nameController.text,
        calories: int.tryParse(_caloriesController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        fat: double.tryParse(_fatController.text) ?? 0,
        sodium: double.tryParse(_sodiumController.text) ?? 0,
        cholesterol: double.tryParse(_cholesterolController.text) ?? 0,
        sugar: double.tryParse(_sugarController.text) ?? 0,
        imageUrl: imageUrl,
        dateTime: DateTime.now(),
      );

      await foodProvider.addFood(food);

      if (mounted) {
        _resetForm();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('식단이 성공적으로 저장되었습니다')));
        foodProvider.selectDate(DateTime.now());
        await Future.delayed(const Duration(milliseconds: 300));
        mainScreenKey.currentState?.navigateToTab(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('식단 저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSaving = false; // 저장 완료
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _imageFile = null;
      _nameController.clear();
      _caloriesController.clear();
      _carbsController.clear();
      _proteinController.clear();
      _fatController.clear();
      _sodiumController.clear();
      _cholesterolController.clear();
      _sugarController.clear();
      _foodName = '';
      _isAddingManually = false;
      _isSaving = false; // 플래그 초기화
    });
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
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
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
