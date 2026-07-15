import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/camera/models/detected_ingredient.dart';
import 'package:frontend/features/camera/presentation/pages/camera_capture_page.dart';
import 'package:frontend/features/camera/providers/camera_provider.dart';
import 'package:frontend/features/camera/providers/photo_search_provider.dart';
import 'package:frontend/features/camera/services/camera_service.dart';
import 'package:frontend/features/camera/services/image_processing_service.dart';
import 'package:frontend/features/camera/services/photo_search_service.dart';
import 'package:frontend/core/api/api_client.dart';

void main() {
  test('low-confidence detections are not confirmed automatically', () {
    final service = PhotoSearchService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com',
        tokenProvider: () async => null,
        tenantSlug: 'ohorodnik-oleksandr',
        locale: 'uk',
      ),
    );

    final ingredients = service.parseDetectedIngredients(['томати'], 0.55);

    expect(ingredients.single.isConfirmed, isFalse);
  });

  test('camera notifier preserves permanently-denied state', () async {
    final notifier = CameraNotifier(
      cameraService:
          _FakeCameraService(CameraPermissionState.permanentlyDenied),
      imageProcessingService: ImageProcessingService(),
    );

    await notifier.initialize();

    expect(notifier.state.hasPermission, isFalse);
    expect(
      notifier.state.permissionState,
      CameraPermissionState.permanentlyDenied,
    );
  });

  testWidgets('permanently denied camera permission opens settings recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraProvider.overrideWith(
            (ref) => CameraNotifier(
              cameraService: _FakeCameraService(
                CameraPermissionState.permanentlyDenied,
              ),
              imageProcessingService: ImageProcessingService(),
            ),
          ),
          photoSearchProvider.overrideWith((ref) => _photoSearchNotifier()),
        ],
        child: const MaterialApp(home: CameraCapturePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Відкрити налаштування'), findsOneWidget);
    expect(find.text('Обрати з галереї'), findsOneWidget);
    expect(find.text('Дати доступ'), findsNothing);
  });

  testWidgets('camera permission recovery goldens at design breakpoints', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_cameraApp());
      await tester.pump();
      await expectLater(
        find.byType(CameraCapturePage),
        matchesGoldenFile('goldens/camera_permission_${width.toInt()}.png'),
      );
    }
  });

  test('weak detection must be confirmed before it enters recipe search', () {
    final ingredients = IngredientEditNotifier()
      ..setIngredients(const [
        DetectedIngredient(
          id: 'weak',
          name: 'невідомий продукт',
          confidence: 0.45,
          isConfirmed: false,
        ),
      ]);

    expect(ingredients.getConfirmedIngredientNames(), isEmpty);
    ingredients.toggleConfirmation('weak');
    expect(ingredients.getConfirmedIngredientNames(), ['невідомий продукт']);
  });
}

Widget _cameraApp() => ProviderScope(
      overrides: [
        cameraProvider.overrideWith(
          (ref) => CameraNotifier(
            cameraService: _FakeCameraService(
              CameraPermissionState.permanentlyDenied,
            ),
            imageProcessingService: ImageProcessingService(),
          ),
        ),
        photoSearchProvider.overrideWith((ref) => _photoSearchNotifier()),
      ],
      child: const MaterialApp(home: CameraCapturePage()),
    );

PhotoSearchNotifier _photoSearchNotifier() => PhotoSearchNotifier(
      photoSearchService: PhotoSearchService(
        apiClient: ApiClient(
          baseUrl: 'https://example.com',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ),
      ),
    );

class _FakeCameraService extends CameraService {
  _FakeCameraService(this._permissionState);

  final CameraPermissionState _permissionState;

  @override
  Future<bool> isCameraAvailable() async => true;

  @override
  Future<CameraPermissionState> cameraPermissionState() async =>
      _permissionState;

  @override
  Future<bool> requestCameraPermission() async =>
      _permissionState == CameraPermissionState.granted;
}
