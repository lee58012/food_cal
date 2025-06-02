import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/models/food.dart';
import 'package:hoseo/providers/food_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  File? _capturedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analyzedFood;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      // 카메라 초기화 실패 처리
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('카메라 초기화 실패: $e')));
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final XFile file = await _controller!.takePicture();
      setState(() {
        _capturedImage = File(file.path);
      });
      _analyzeImage(File(file.path));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진 촬영 실패: $e')));
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
      });
      _analyzeImage(File(image.path));
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
      _analyzedFood = null;
    });

    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final result = await foodProvider.analyzeFoodImage(imageFile);

      setState(() {
        _analyzedFood = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('음식 분석 실패: $e')));
    }
  }

  Future<void> _saveFood() async {
    if (_analyzedFood == null) return;

    final food = Food(
      name: _analyzedFood!['name'],
      calories: _analyzedFood!['calories'],
      carbs: _analyzedFood!['carbs'],
      protein: _analyzedFood!['protein'],
      fat: _analyzedFood!['fat'],
      imageUrl: _capturedImage?.path,
      dateTime: DateTime.now(),
    );

    try {
      await Provider.of<FoodProvider>(context, listen: false).addFood(food);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('음식이 저장되었습니다!')));

        setState(() {
          _capturedImage = null;
          _analyzedFood = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음식 저장 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('식단 촬영'), centerTitle: true),
      body: _buildBody(),
      floatingActionButton: _capturedImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'gallery',
                  onPressed: _pickImageFromGallery,
                  tooltip: '갤러리에서 선택',
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'camera',
                  onPressed: _takePicture,
                  tooltip: '사진 촬영',
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_capturedImage == null) {
      // 카메라 프리뷰 화면
      if (_controller == null || !_controller!.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }

      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: CameraPreview(_controller!),
      );
    } else {
      // 촬영된 이미지 분석 화면
      return SingleChildScrollView(
        child: Column(
          children: [
            // 촬영된 이미지
            Image.file(_capturedImage!),

            const SizedBox(height: 20),

            if (_isAnalyzing)
              Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('음식을 분석 중입니다...'),
                ],
              )
            else if (_analyzedFood != null)
              // 분석 결과
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '음식명: ${_analyzedFood!['name']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('칼로리: ${_analyzedFood!['calories']} kcal'),
                    Text('탄수화물: ${_analyzedFood!['carbs']} g'),
                    Text('단백질: ${_analyzedFood!['protein']} g'),
                    Text('지방: ${_analyzedFood!['fat']} g'),

                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _capturedImage = null;
                              _analyzedFood = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('다시 촬영'),
                        ),
                        ElevatedButton(
                          onPressed: _saveFood,
                          child: const Text('저장하기'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const Text('이미지 분석에 실패했습니다. 다시 시도해주세요.'),
          ],
        ),
      );
    }
  }
}
