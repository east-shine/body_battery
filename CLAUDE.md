# Body Battery 프로젝트 가이드

## 프로젝트 개요

갤럭시워치와 스마트폰에서 실행되는 바디배터리 앱 (가민 바디배터리 클론)

- Flutter 기반 통합 앱 (워치/폰 분리 실행)
- 워치: Health Services API로 직접 센서 데이터 수집
- 폰: 워치에서 수집한 데이터 수신 및 상세 분석
- 0-100% 에너지 레벨 추적

## 아키텍처 (개선된 구조)

### 디렉토리 구조

```bash
lib/
├── models/              # 데이터 모델
│   ├── body_battery.dart
│   └── health_data.dart
├── services/            # 비즈니스 로직
│   ├── wear_health_service.dart    # 워치용 Health Services API
│   ├── data_sync_service.dart      # 워치-폰 데이터 동기화
│   ├── watch_data_collector.dart   # 워치 데이터 수집 통합
│   ├── phone_data_receiver.dart    # 폰 데이터 수신 관리
│   ├── battery_calculator.dart     # 배터리 계산 알고리즘
│   └── health_service.dart         # 헬스커넥트 (레거시/백업용)
├── screens/             # 화면 UI
│   ├── watch_home_screen.dart      # 워치 전용 홈
│   ├── phone_home_screen.dart      # 폰 전용 홈
│   ├── home_screen.dart           # 기존 통합 홈 (레거시)
│   └── detail_screen.dart         # 상세 분석 화면
└── widgets/             # 재사용 위젯
    └── battery_gauge.dart

main.dart                # 플랫폼별 분기 처리
```

### 데이터 흐름

```text
[워치 앱]
Health Services API → WearHealthService → BatteryCalculator
                                            ↓
                          WatchDataCollector → DataSyncService
                                                    ↓
                                            [Wear Data Layer]
                                                    ↓
[폰 앱]                                    DataSyncService
                                                    ↓
                          PhoneDataReceiver → UI 업데이트
```

### 주요 컴포넌트

#### 워치 컴포넌트

- **WearHealthService**: Health Services API 직접 접근 (스트레스 포함)
- **WatchDataCollector**: 데이터 수집 및 전송 통합 관리
- **DataSyncService**: Wear Data Layer API 통신

#### 폰 컴포넌트

- **PhoneDataReceiver**: 워치 데이터 수신 및 캐싱
- **DataSyncService**: Wear Data Layer API 통신
- **DetailScreen**: 상세 분석 및 차트 표시

#### 공통 컴포넌트

- **BatteryCalculator**: 바디배터리 계산 알고리즘
- **Models**: 데이터 모델 정의

## 코딩 규칙

### Flutter/Dart 최신 문법 사용

#### 1. Deprecated API 대체

```dart
// ❌ 사용하지 마세요
color.withOpacity(0.5)

// ✅ 올바른 사용
color.withValues(alpha: 0.5)
```

#### 2. Super Parameters 사용

```dart
// ❌ 이전 방식
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
}

// ✅ 최신 방식
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
}
```

#### 3. 프로덕션 코드에서 print 대신 debugPrint 사용

```dart
// ❌ 사용하지 마세요
print('에러: $error');

// ✅ 올바른 사용
debugPrint('에러: $error');
```

#### 4. Health 패키지 열거형 상수

```dart
// ❌ 잘못된 상수
HealthWorkoutActivityType.CYCLING  // 존재하지 않음

// ✅ 올바른 상수
HealthWorkoutActivityType.BIKING   // 올바른 이름
```

### 워치/폰 감지

```dart
// 화면 크기로 워치 여부 판단
final isWatchSize = MediaQuery.of(context).size.width < 300;

// 원형 워치 감지
final size = MediaQuery.of(context).size;
final isRoundWatch = size.width == size.height;
```

## 데이터 수집 전략

### ❌ 사용하지 않는 것

- **Samsung Health SDK**: 파트너 앱만 사용 가능하므로 제외
- **헬스커넥트 (워치)**: Health Services API로 대체

### ✅ 현재 구현된 아키텍처

#### 워치 (주 데이터 수집 장치)

- **Health Services API** 사용
  - 모든 센서 데이터 직접 접근 (스트레스 포함)
  - 패시브 모니터링으로 배터리 효율화
  - 5분 주기 자동 동기화
  - 실시간 모니터링 옵션

#### 폰 (데이터 수신 및 분석)

- **Wear Data Layer API**로 워치 데이터 수신
  - 워치 연결 상태 자동 감지
  - 30초마다 재연결 시도
  - 수신 데이터 캐싱 및 히스토리 관리
  - 상세 분석 및 예측 기능

### 데이터 동기화 방식

```text
[자동 동기화]
워치: 5분마다 자동으로 배터리/헬스 데이터 전송

[수동 동기화]
폰: 동기화 버튼으로 전체 데이터 요청

[실시간 모드]
폰: 실시간 모니터링 시작 → 워치: 1분마다 데이터 전송
```

## 의존성 패키지

```yaml
dependencies:
  # 데이터 수집 및 통신
  health: ^13.1.3                      # 헬스커넥트 (백업/레거시용)
  wear: ^1.1.0                          # Wear OS 플랫폼 지원
  flutter_wear_os_connectivity: ^0.1.4  # 워치-폰 데이터 동기화
  
  # UI 및 저장소
  fl_chart: ^0.66.0                    # 차트 그리기
  shared_preferences: ^2.2.2           # 로컬 데이터 저장
  
  # 플랫폼 감지
  device_info_plus: ^10.1.0            # 디바이스 정보
```

## 헬스커넥트 권한

AndroidManifest.xml에 필요한 권한:

- `android.permission.health.READ_HEART_RATE`
- `android.permission.health.READ_SLEEP`
- `android.permission.health.READ_STEPS`
- `android.permission.health.READ_EXERCISE`
- `android.permission.health.READ_HEART_RATE_VARIABILITY`
- `android.permission.ACTIVITY_RECOGNITION`
- `android.permission.BODY_SENSORS`

## 빌드 및 실행

```bash
# 패키지 설치
flutter pub get

# 앱 실행
flutter run

# 워치에서 실행
flutter run -d <watch_device_id>
```

## 주의사항

1. **Import 정리**: 사용하지 않는 import는 반드시 제거
2. **Null Safety**: 모든 null 체크 철저히
3. **애니메이션**: 워치에서는 성능을 위해 간소화
4. **배터리 최적화**: 5분 주기 업데이트로 배터리 소모 최소화

## 네이티브 코드 구현 필요

### Android (Kotlin) - Health Services API

워치 앱에서 Health Services API를 사용하려면 다음 네이티브 코드 구현이 필요합니다:

```kotlin
// android/app/src/main/kotlin/.../HealthServicesPlugin.kt
class HealthServicesPlugin : MethodChannel.MethodCallHandler {
    // Health Services API 구현
    // - 센서 데이터 접근
    // - 스트레스 레벨 수집
    // - 패시브 모니터링
}
```

### 필요한 Android 권한 (워치)

```xml
<!-- Health Services API -->
<uses-permission android:name="android.permission.BODY_SENSORS" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="com.google.android.wearable.healthservices.permission.PASSIVE_DATA_COLLECTION" />
```

## 향후 개선사항

- [x] 워치-폰 데이터 동기화 (구현 완료)
- [x] Health Services API 통합 (서비스 레이어 완료, 네이티브 코드 필요)
- [ ] 워치 컴플리케이션 지원
- [ ] 백그라운드 서비스 구현
- [ ] 알림 기능 추가
- [ ] 네이티브 Health Services 플러그인 구현
