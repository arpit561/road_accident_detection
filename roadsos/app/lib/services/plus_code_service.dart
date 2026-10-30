
/// Pure-Dart Open Location Code (OLC / Google Plus Code) encoder.
/// Generates full 10-character Plus Codes without external packages.
class PlusCodeService {
  static const String _alphabet = '23456789CFGHJMPQRVWX';
  static const String _separator = '+';
  static const int _separatorPosition = 8;
  static const int _pairCodeLength = 10;

  static const double _latMax = 90.0;
  static const double _lngMax = 180.0;

  // Open Location Code pair resolutions, from largest to smallest.
  static const List<double> _pairResolutions = [
    20.0,
    1.0,
    0.05,
    0.0025,
    0.000125,
  ];

  /// Encodes latitude and longitude into a full 10-character Plus Code.
  static String encode(
    double latitude,
    double longitude, {
    int codeLength = _pairCodeLength,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) {
      throw ArgumentError('Latitude and longitude must be finite numbers.');
    }

    if (latitude < -_latMax || latitude > _latMax) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be between -90 and 90.');
    }

    if (longitude < -_lngMax || longitude > _lngMax) {
      throw ArgumentError.value(longitude, 'longitude', 'Must be between -180 and 180.');
    }

    if (codeLength < 2 || codeLength > 10 || codeLength.isOdd) {
      throw ArgumentError.value(
        codeLength,
        'codeLength',
        'Must be an even number between 2 and 10.',
      );
    }

    // The north pole is exclusive in OLC, so move it slightly inward.
    latitude = latitude.clamp(-_latMax, _latMax - 1e-12).toDouble();

    // Normalize longitude to [-180, 180).
    longitude = (longitude + _lngMax) % 360.0;
    if (longitude < 0) longitude += 360.0;
    longitude -= _lngMax;

    double lat = latitude + _latMax;
    double lng = longitude + _lngMax;

    final StringBuffer code = StringBuffer();

    final int pairLength = codeLength < _pairCodeLength
        ? codeLength
        : _pairCodeLength;

    for (int i = 0; i < pairLength ~/ 2; i++) {
      final double resolution = _pairResolutions[i];

      int latDigit = (lat / resolution).floor();
      int lngDigit = (lng / resolution).floor();

      latDigit = latDigit.clamp(0, 19);
      lngDigit = lngDigit.clamp(0, 19);

      code.write(_alphabet[latDigit]);
      code.write(_alphabet[lngDigit]);

      lat -= latDigit * resolution;
      lng -= lngDigit * resolution;
    }

    final String pairCode = code.toString();

    if (pairCode.length < _separatorPosition) {
      return '${pairCode.padRight(_separatorPosition, '0')}$_separator';
    }

    return '${pairCode.substring(0, _separatorPosition)}'
        '$_separator'
        '${pairCode.substring(_separatorPosition)}';
  }

  /// Returns coordinates and their Plus Code in a readable format.
  static String formatLocation(double lat, double lng) {
    final String plus = encode(lat, lng);

    final String latStr = lat >= 0
        ? '${lat.toStringAsFixed(5)}°N'
        : '${lat.abs().toStringAsFixed(5)}°S';

    final String lngStr = lng >= 0
        ? '${lng.toStringAsFixed(5)}°E'
        : '${lng.abs().toStringAsFixed(5)}°W';

    return '$latStr, $lngStr  |  $plus';
  }
}






// /// Pure-Dart Open Location Code (OLC / Google Plus Code) encoder.
// /// Implements the full OLC 20-character alphabet encoding algorithm.
// /// No external packages required — runs fully offline.
// ///
// /// Reference: https://github.com/google/open-location-code
// class PlusCodeService {
//   static const String _alphabet = '23456789CFGHJMPQRVWX';
//   static const int _pairCodeLength = 10;
//   static const int _gridCodeLength = 5;
//   static const double _latMax = 90.0;
//   static const double _lngMax = 180.0;
//   static const int _encodingBase = 20;

//   /// Encodes a lat/lng into a full-precision (10-char) Plus Code.
//   /// Example: (12.9716, 77.5946) → "7J4VXQCG+Q4"
//   static String encode(double latitude, double longitude, {int codeLength = 10}) {
//     // Clip latitude and normalize longitude
//     latitude = latitude.clamp(-_latMax + 1e-9, _latMax);
//     longitude = (longitude + _lngMax) % (2 * _lngMax) - _lngMax;

//     // Shift to positive range
//     double lat = latitude + _latMax;
//     double lng = longitude + _lngMax;

//     final StringBuffer code = StringBuffer();

//     // Encode pair section (alternating lat/lng pairs)
//     int pLen = codeLength < _pairCodeLength ? codeLength : _pairCodeLength;
//     int step = _encodingBase * _encodingBase;

//     for (int i = 0; i < (pLen / 2).ceil(); i++) {
//       final int latDigit = (lat / step).floor() % _encodingBase;
//       final int lngDigit = (lng / step).floor() % _encodingBase;
//       code.write(_alphabet[latDigit]);
//       code.write(_alphabet[lngDigit]);
//       step = (step / _encodingBase).floor();
//       if (code.length == 8) code.write('+');
//     }

//     // Pad if requested code length is < 8
//     while (code.length < 9) {
//       code.write('0');
//       if (code.length == 8) code.write('+');
//     }

//     return code.toString();
//   }

//   /// Returns a formatted string with both coordinates and Plus Code.
//   static String formatLocation(double lat, double lng) {
//     final plus = encode(lat, lng);
//     final latStr = lat >= 0 ? '${lat.toStringAsFixed(5)}°N' : '${lat.abs().toStringAsFixed(5)}°S';
//     final lngStr = lng >= 0 ? '${lng.toStringAsFixed(5)}°E' : '${lng.abs().toStringAsFixed(5)}°W';
//     return '$latStr, $lngStr  |  📍 $plus';
//   }
// }
