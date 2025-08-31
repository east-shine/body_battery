package net.fullstackhub.bodybattery

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 네이티브 플러그인 등록
        flutterEngine.plugins.add(HealthServicesPlugin())
        flutterEngine.plugins.add(WearDataLayerPlugin())
    }
}
