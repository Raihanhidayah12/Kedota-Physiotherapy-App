import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _googleLogoSvg,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.13 13.72 17.6 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.5 24c0-1.54-.15-3.02-.43-4.45H24v8.43h12.94c-.56 2.96-2.2 5.47-4.69 7.17l7.3 5.66C43.87 37.65 46.5 31.42 46.5 24z"/>
  <path fill="#FBBC05" d="M10.54 28.41a14.35 14.35 0 0 1 0-8.82l-7.98-6.19A23.98 23.98 0 0 0 0 24c0 3.86.92 7.5 2.56 10.78l7.98-6.19z"/>
  <path fill="#34A853" d="M24 47.5c6.47 0 11.9-2.14 15.87-5.8l-7.3-5.66c-2.03 1.36-4.63 2.17-8.57 2.17-6.4 0-11.87-4.22-13.86-9.91l-7.98 6.19C6.51 42.62 14.62 47.5 24 47.5z"/>
</svg>
''';
