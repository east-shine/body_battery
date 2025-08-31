package net.fullstackhub.bodybattery

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 워치 화면 항상 켜짐 설정
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // 워치 앱이 백그라운드로 가지 않도록 설정
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 네이티브 플러그인 등록
        flutterEngine.plugins.add(HealthServicesPlugin())
        flutterEngine.plugins.add(WearDataLayerPlugin())
    }
    
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // 홈 버튼 눌렀을 때 앱을 백그라운드로 이동
        // 워치에서는 앱이 계속 실행되도록 함
    }
}
