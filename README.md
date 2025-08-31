# Body Battery - Galaxy Watch Health Tracker

A Flutter-based health monitoring app for Samsung Galaxy Watch and smartphones, inspired by Garmin's Body Battery feature.

## Features

- **Real-time Body Battery Tracking**: Monitor your energy levels from 0-100%
- **Smart Watch Integration**: Primary data collection on Galaxy Watch using Health Services API
- **Phone Companion App**: Detailed analytics and historical data visualization
- **Health Metrics**: Heart rate, HRV, steps, stress levels, sleep quality
- **Predictive Analytics**: Energy level predictions based on activity patterns
- **Automatic Sync**: Seamless data synchronization between watch and phone

## Architecture

### Watch (Primary Data Collector)
- Direct sensor access via Health Services API
- Passive monitoring for battery efficiency
- Real-time stress level calculation from HRV
- 5-minute automatic sync intervals

### Phone (Data Receiver & Analyzer)
- Receives data via Wear Data Layer API
- Advanced charting and analytics
- Historical data storage
- Predictive algorithms for energy forecasting

## Tech Stack

- **Framework**: Flutter 3.x
- **Languages**: Dart, Kotlin
- **APIs**: 
  - Health Services API (Wear OS)
  - Wear Data Layer API (Watch-Phone communication)
  - Health Connect (Backup/Legacy)
- **UI**: Material Design 3, Custom battery gauge widget

## Installation

### Prerequisites
- Flutter SDK ^3.8.0
- Android Studio
- Samsung Galaxy Watch (Wear OS 3+)
- Android Phone (API 30+)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/fullstack-hub/body_battery.git
cd body_battery
```

2. Install dependencies:
```bash
flutter pub get
```

3. Build and run:
```bash
# For watch
flutter run -d <watch_device_id>

# For phone
flutter run -d <phone_device_id>
```

## Project Structure

```
lib/
├── models/              # Data models
├── services/            # Business logic
│   ├── wear_health_service.dart    # Watch Health Services API
│   ├── data_sync_service.dart      # Watch-Phone sync
│   └── battery_calculator.dart     # Energy calculations
├── screens/             # UI screens
│   ├── watch_home_screen.dart      # Watch UI
│   └── phone_home_screen.dart      # Phone UI
└── widgets/             # Reusable components
```

## Native Implementation

The app includes native Kotlin plugins for:
- **HealthServicesPlugin**: Direct access to Wear OS health sensors
- **WearDataLayerPlugin**: Bidirectional watch-phone communication

## Permissions

Required Android permissions:
- Body sensors access
- Activity recognition
- Health Services data collection
- Wear OS standalone app capability

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created by FullStack Hub

## Acknowledgments

- Inspired by Garmin Body Battery
- Built with Flutter and Wear OS Health Services