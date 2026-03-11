import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // OpenWeatherMap API (무료)
  static const String _apiKey = 'f608cb7df83190a1358c804402a543eb';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  // 기상청 단기예보 API (공공데이터)
  static const String _kmaBaseUrl = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0';
  static const String _kmaApiKey = ''; // 공공데이터 API 키

  // 제주도 기본 좌표
  static const double _jejuLat = 33.4996;
  static const double _jejuLng = 126.5312;

  // 현재 날씨 가져오기 (OpenWeatherMap)
  Future<WeatherData?> getCurrentWeather({
    double? lat,
    double? lng,
  }) async {
    final latitude = lat ?? _jejuLat;
    final longitude = lng ?? _jejuLng;

    // API 키가 없으면 더미 데이터 반환
    if (_apiKey.isEmpty) {
      return _getDummyWeather();
    }

    try {
      final url = '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&lang=kr';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromOpenWeatherMap(data);
      }
    } catch (e) {
      print('Weather API error: $e');
    }

    return _getDummyWeather();
  }

  // 제주도 날씨 (위치 기반)
  Future<WeatherData?> getJejuWeather() async {
    return getCurrentWeather(lat: _jejuLat, lng: _jejuLng);
  }

  // 더미 날씨 데이터 (API 키 없을 때)
  WeatherData _getDummyWeather() {
    final hour = DateTime.now().hour;

    // 시간대별 기본 날씨
    String condition;
    String icon;
    double temp;

    if (hour >= 6 && hour < 9) {
      condition = '맑음';
      icon = 'sunny';
      temp = 12.0;
    } else if (hour >= 9 && hour < 12) {
      condition = '맑음';
      icon = 'sunny';
      temp = 18.0;
    } else if (hour >= 12 && hour < 15) {
      condition = '구름조금';
      icon = 'partly_cloudy';
      temp = 22.0;
    } else if (hour >= 15 && hour < 18) {
      condition = '구름조금';
      icon = 'partly_cloudy';
      temp = 20.0;
    } else if (hour >= 18 && hour < 21) {
      condition = '맑음';
      icon = 'clear_night';
      temp = 16.0;
    } else {
      condition = '맑음';
      icon = 'clear_night';
      temp = 13.0;
    }

    return WeatherData(
      temperature: temp,
      feelsLike: temp - 2,
      humidity: 65,
      windSpeed: 3.5,
      condition: condition,
      icon: icon,
      description: '등산하기 좋은 날씨입니다',
      location: '제주도',
    );
  }

  // 등산 적합도 계산
  static HikingCondition getHikingCondition(WeatherData weather) {
    // 기온 체크
    if (weather.temperature < 0) {
      return HikingCondition(
        level: 'bad',
        message: '기온이 너무 낮습니다. 방한 준비를 철저히 하세요.',
        color: 0xFFE53935,
      );
    }
    if (weather.temperature > 33) {
      return HikingCondition(
        level: 'bad',
        message: '기온이 너무 높습니다. 열사병에 주의하세요.',
        color: 0xFFE53935,
      );
    }

    // 바람 체크
    if (weather.windSpeed > 10) {
      return HikingCondition(
        level: 'caution',
        message: '바람이 강합니다. 주의가 필요합니다.',
        color: 0xFFFF9800,
      );
    }

    // 비/눈 체크
    if (weather.condition.contains('비') || weather.condition.contains('눈')) {
      return HikingCondition(
        level: 'caution',
        message: '우천/강설 시 등산로가 미끄러울 수 있습니다.',
        color: 0xFFFF9800,
      );
    }

    // 좋은 날씨
    if (weather.temperature >= 10 && weather.temperature <= 25) {
      return HikingCondition(
        level: 'good',
        message: '등산하기 좋은 날씨입니다!',
        color: 0xFF4CAF50,
      );
    }

    return HikingCondition(
      level: 'normal',
      message: '등산 가능한 날씨입니다.',
      color: 0xFF2196F3,
    );
  }
}

class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String condition;
  final String icon;
  final String description;
  final String location;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.icon,
    required this.description,
    required this.location,
  });

  factory WeatherData.fromOpenWeatherMap(Map<String, dynamic> json) {
    final main = json['main'];
    final weatherList = json['weather'] as List?;
    final weather = (weatherList != null && weatherList.isNotEmpty) ? weatherList[0] : <String, dynamic>{};
    final wind = json['wind'];

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      condition: weather['description'] ?? '',
      icon: weather['icon'] ?? '',
      description: weather['description'] ?? '',
      location: json['name'] ?? '제주',
    );
  }

  // 날씨 아이콘 반환
  String get weatherIcon {
    if (condition.contains('맑') || icon.contains('clear') || icon == 'sunny') {
      return '☀️';
    } else if (condition.contains('구름') || icon.contains('cloud') || icon == 'partly_cloudy') {
      return '⛅';
    } else if (condition.contains('흐림') || icon.contains('overcast')) {
      return '☁️';
    } else if (condition.contains('비') || icon.contains('rain')) {
      return '🌧️';
    } else if (condition.contains('눈') || icon.contains('snow')) {
      return '❄️';
    } else if (condition.contains('안개') || icon.contains('fog')) {
      return '🌫️';
    } else if (icon.contains('night') || icon == 'clear_night') {
      return '🌙';
    }
    return '🌤️';
  }
}

class HikingCondition {
  final String level; // good, normal, caution, bad
  final String message;
  final int color;

  HikingCondition({
    required this.level,
    required this.message,
    required this.color,
  });
}
