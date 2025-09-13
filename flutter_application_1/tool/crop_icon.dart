import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final inPath = 'assets/icon/icon.png';
  final outPath = 'assets/icon/icon_cropped.png';
  final bytes = await File(inPath).readAsBytes();
  final img = decodeImage(bytes);
  if (img == null) {
    print('Failed to decode image');
    return;
  }
  // find non-transparent bounds
  int left = img.width, right = 0, top = img.height, bottom = 0;
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p = img.getPixel(x, y);
      final a = getAlpha(p);
      if (a > 10) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  if (left > right || top > bottom) {
    print('Image appears fully transparent');
    return;
  }
  final w = right - left + 1;
  final h = bottom - top + 1;
  final cropped = copyCrop(img, left, top, w, h);
  // create a 1024x1024 canvas and draw the cropped image scaled to "cover"
  const int size = 1024;
  final canvas = Image(size, size);
  // transparent background
  fill(canvas, 0);

  // scale cropped image so it covers the square (cover behavior)
  final scale = (size / cropped.width).ceilToDouble() > (size / cropped.height).ceilToDouble()
      ? (size / cropped.width)
      : (size / cropped.height);
  final targetW = (cropped.width * scale).round();
  final targetH = (cropped.height * scale).round();
  final resized = copyResize(cropped, width: targetW, height: targetH, interpolation: Interpolation.average);

  final dx = ((size - resized.width) / 2).round();
  final dy = ((size - resized.height) / 2).round();
  drawImage(canvas, resized, dstX: dx, dstY: dy);

  // Instead of making corners transparent, sample a background color from the
  // center of the image and paint any pixel outside the circle with that
  // color. This removes the visible white/transparent corners in launcher
  // icons while keeping the circular appearance when the launcher masks it.
  final cx = size ~/ 2;
  final cy = size ~/ 2;
  final r = size ~/ 2;

  // sample background color from center pixel (fall back to white)
  int sample = canvas.getPixel(cx, cy);
  int sampleA = getAlpha(sample);
  int sampleR = getRed(sample);
  int sampleG = getGreen(sample);
  int sampleB = getBlue(sample);
  if (sampleA < 16) {
    // if center is transparent, try a small neighborhood
    bool found = false;
    for (int yy = cy - 4; yy <= cy + 4 && !found; yy++) {
      for (int xx = cx - 4; xx <= cx + 4 && !found; xx++) {
        if (xx < 0 || yy < 0 || xx >= size || yy >= size) continue;
        final p = canvas.getPixel(xx, yy);
        if (getAlpha(p) > 16) {
          sample = p;
          sampleA = getAlpha(p);
          sampleR = getRed(p);
          sampleG = getGreen(p);
          sampleB = getBlue(p);
          found = true;
        }
      }
    }
  }

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx1 = x - cx;
      final dy1 = y - cy;
      if (dx1 * dx1 + dy1 * dy1 > r * r) {
        // paint outside-circle pixel with sampled background color (opaque)
        canvas.setPixelRgba(x, y, sampleR, sampleG, sampleB, 255);
      }
    }
  }

  await File(outPath).writeAsBytes(encodePng(canvas));
  print('Cropped and padded icon written to $outPath');
}
