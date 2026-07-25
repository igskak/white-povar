import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/images/remote_image.dart';

const _object =
    'https://qnlfvpqmkmbvzmzqgjpo.supabase.co/storage/v1/object/public';
const _render =
    'https://qnlfvpqmkmbvzmzqgjpo.supabase.co/storage/v1/render/image/public';

void main() {
  test('rewrites a public object URL to the render endpoint', () {
    expect(
      sizedRemoteImageUrl('$_object/recipe-images/Beetroot.png', width: 640),
      '$_render/recipe-images/Beetroot.png?width=640&quality=70',
    );
  });

  test('keeps the percent-encoded object path byte-for-byte', () {
    expect(
      sizedRemoteImageUrl('$_object/recipe-images/Capreze%202.0.png',
          width: 640),
      '$_render/recipe-images/Capreze%202.0.png?width=640&quality=70',
    );
  });

  test('replaces the query the storage client appends to brand assets', () {
    expect(
      sizedRemoteImageUrl('$_object/studio-brand-assets/brands/a/b.webp?',
          width: 320),
      '$_render/studio-brand-assets/brands/a/b.webp?width=320&quality=70',
    );
  });

  test('leaves non-Supabase and malformed URLs alone', () {
    const external = 'https://cdn.example.com/photo.jpg';
    expect(sizedRemoteImageUrl(external, width: 640), external);
    expect(sizedRemoteImageUrl('$_object/', width: 640), '$_object/');
  });

  test('snaps requested widths to shared cache buckets', () {
    expect(renderWidthFor(1), 160);
    expect(renderWidthFor(400), 480);
    expect(renderWidthFor(640), 640);
    expect(renderWidthFor(641), 960);
    expect(renderWidthFor(9000), 2000);
  });
}
