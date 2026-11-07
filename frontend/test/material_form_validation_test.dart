import 'dart:typed_data';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/presentation/material_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Uint8List _png() =>
    Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);
Uint8List _webp() => Uint8List.fromList(
    [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56]);

void main() {
  group('rules', () {
    test('photo format is decided by signature, not by extension', () {
      // A text file renamed to .jpg must be rejected.
      expect(
          validatePhoto(PickedPhoto(
              name: 'fake.jpg',
              bytes: Uint8List.fromList('hello world!!'.codeUnits))),
          isNotNull);
      // A real PNG with a misleading extension is accepted.
      expect(validatePhoto(PickedPhoto(name: 'x.txt', bytes: _png())), isNull);
      expect(validatePhoto(PickedPhoto(name: 'x.bin', bytes: _webp())), isNull);
      // RIFF container that is not WebP (e.g. WAV) is rejected.
      final wav = Uint8List.fromList(
          [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, 0x66]);
      expect(validatePhoto(PickedPhoto(name: 'a.webp', bytes: wav)), isNotNull);
    });

    test('photo size limit is exactly 10 MB', () {
      final atLimit = Uint8List(maxPhotoBytes)
        ..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      final over = Uint8List(maxPhotoBytes + 1)
        ..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      expect(validatePhoto(PickedPhoto(name: 'a.jpg', bytes: atLimit)), isNull);
      expect(validatePhoto(PickedPhoto(name: 'a.jpg', bytes: over)), isNotNull);
    });

    test('price: optional, zero allowed, negative and 3 decimals rejected', () {
      expect(validatePriceKgs(''), isNull);
      expect(validatePriceKgs('  '), isNull);
      expect(validatePriceKgs('0'), isNull);
      expect(validatePriceKgs('45,5'), isNull);
      expect(validatePriceKgs('-1'), isNotNull);
      expect(validatePriceKgs('1.234'), isNotNull);
      expect(validatePriceKgs('abc'), isNotNull);
    });

    test('mass: more than 3 decimals and 10 integer digits are rejected', () {
      expect(validateMassKg('1.2345'), isNotNull);
      expect(validateMassKg('1234567890'), isNotNull);
      expect(validateMassKg('-5'), isNotNull);
      expect(validateMassKg('1e3'), isNotNull);
    });

    // DOCUMENTED DIVERGENCE (api.md 18.4): the server accepts total_kg = "0"
    // for a draft; the mobile client is intentionally stricter (> 0) and
    // blocks it. If product decides drafts may have zero mass, this test must
    // be changed together with validateMassKg.
    test('client rejects zero mass although server allows it for drafts', () {
      for (final z in ['0', '0.0', '0,000', '00']) {
        expect(validateMassKg(z), 'Масса должна быть больше нуля.', reason: z);
      }
    });
  });

  group('create form', () {
    testWidgets('missing required fields are reported, no request is sent',
        (tester) async {
      final repo = RecordingRepo();
      await pumpScreen(
          tester, makeContainer(repo), const MaterialCreateScreen());
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(find.text('Укажите название партии.'), findsOneWidget);
      expect(find.text('Выберите тип материала.'), findsOneWidget);
      expect(find.text('Выберите состояние.'), findsOneWidget);
      expect(find.text('Укажите массу в кг.'), findsOneWidget);
      expect(find.text('Укажите город.'), findsOneWidget);
      expect(repo.totalCalls, 0);
    });

    testWidgets('zero mass is saved as a draft (api.md 19.6)', (tester) async {
      final repo = RecordingRepo();
      await pumpScreen(
          tester, makeContainer(repo), const MaterialCreateScreen());
      await fillCreateForm(tester, mass: '0');
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(find.text('Масса должна быть больше нуля.'), findsNothing);
      expect(repo.createCalls, 1);
      expect(repo.lastCreate!.toJson()['total_kg'], '0');
    });

    testWidgets('price is optional: create is sent without price_per_kg',
        (tester) async {
      final repo = RecordingRepo();
      await pumpScreen(
          tester, makeContainer(repo), const MaterialCreateScreen());
      await fillCreateForm(tester);
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pump();
      await tester.pump();
      expect(repo.createCalls, 1);
      final json = repo.lastCreate!.toJson();
      expect(json.containsKey('price_per_kg'), isFalse);
      // comma normalised, mass stays a string
      expect(json['total_kg'], '12.5');
    });

    testWidgets('selecting more than 5 photos keeps 5 and shows a notice',
        (tester) async {
      final photos = [
        for (var i = 0; i < 6; i++)
          PickedPhoto(name: 'p$i.jpg', bytes: jpegBytes(i))
      ];
      final repo = RecordingRepo();
      await pumpScreen(tester, makeContainer(repo, picker: StubPicker(photos)),
          const MaterialCreateScreen(),
          size: const Size(400, 2400));
      await tester.tap(find.text('Добавить фото'));
      await tester.pumpAndSettle();
      expect(find.textContaining('не более 5 фото'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.text('p$i.jpg'), findsOneWidget);
      }
      expect(find.text('p5.jpg'), findsNothing);
      // At the limit the add button is disabled.
      final btn = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Добавить фото'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('fake .jpg and oversize files are rejected, valid one kept',
        (tester) async {
      final big = Uint8List(maxPhotoBytes + 1)
        ..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      final photos = [
        PickedPhoto(
            name: 'fake.jpg', bytes: Uint8List.fromList(List.filled(20, 65))),
        PickedPhoto(name: 'big.jpg', bytes: big),
        PickedPhoto(name: 'ok.png', bytes: _png()),
      ];
      await pumpScreen(
          tester,
          makeContainer(RecordingRepo(), picker: StubPicker(photos)),
          const MaterialCreateScreen(),
          size: const Size(400, 2400));
      await tester.tap(find.text('Добавить фото'));
      await tester.pumpAndSettle();
      expect(find.textContaining('«fake.jpg»: допустимы только JPEG'),
          findsOneWidget);
      expect(find.textContaining('«big.jpg»: больше 10 МБ'), findsOneWidget);
      expect(find.text('ok.png'), findsOneWidget);
      expect(find.text('fake.jpg'), findsNothing);
    });

    testWidgets('server 422 is shown under the matching field only',
        (tester) async {
      final repo = RecordingRepo()
        ..createError = const ApiException(
          code: 'VALIDATION_ERROR',
          message: 'Проверьте заполненные поля.',
          statusCode: 422,
          details: {
            'errors': [
              {
                'field': 'city',
                'code': 'too_long',
                'message': 'Слишком длинный город.'
              },
              {
                'field': 'total_kg',
                'code': 'too_many_decimals',
                'message': 'Не более 3 знаков после точки.'
              },
            ]
          },
        );
      await pumpScreen(
          tester, makeContainer(repo), const MaterialCreateScreen());
      await fillCreateForm(tester);
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();

      Finder errorUnder(String label, String text) => find.descendant(
          of: find.ancestor(
              of: find.text(label), matching: find.byType(InputDecorator)),
          matching: find.text(text));
      expect(errorUnder('Город', 'Слишком длинный город.'), findsOneWidget);
      expect(errorUnder('Масса', 'Не более 3 знаков после точки.'),
          findsOneWidget);
      // Typed values are kept so the user can fix them.
      expect(find.widgetWithText(TextFormField, 'Хлопковые обрезки'),
          findsOneWidget);
      // No raw error codes in the UI.
      expect(find.textContaining('too_long'), findsNothing);
      expect(find.textContaining('VALIDATION_ERROR'), findsNothing);
    });
  });
}
