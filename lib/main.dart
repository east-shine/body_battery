import 'package:flutter/material.dart';
import 'screens/watch_home_screen.dart';
import 'screens/phone_home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Body Battery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          // 화면 크기로 플랫폼 판단
          final size = MediaQuery.of(context).size;
          final isWearOS = size.width < 300 && size.width == size.height;

          if (isWearOS) {
            // 워치 앱 - 주 데이터 수집 및 표시
            return const WatchHomeScreen();
          } else {
            // 폰 앱 - 워치 데이터 수신 및 상세 표시
            return const PhoneHomeScreen();
          }
        },
      ),
    );
  }
}
