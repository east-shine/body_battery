package net.fullstackhub.bodybattery

import android.content.Context
import androidx.health.services.client.HealthServices
import androidx.health.services.client.HealthServicesClient
import androidx.health.services.client.PassiveListenerService
import androidx.health.services.client.data.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import com.google.android.gms.tasks.Task
import kotlin.coroutines.CoroutineContext

class HealthServicesPlugin : FlutterPlugin, MethodCallHandler, CoroutineScope {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var healthServicesClient: HealthServicesClient
    
    // Coroutine scope
    private val job = Job()
    override val coroutineContext: CoroutineContext
        get() = Dispatchers.Main + job
    
    // 실시간 데이터 저장
    private var lastHeartRate: Int? = null
    private var lastSteps: Int? = null
    private var lastCalories: Double? = null
    private var lastDistance: Double? = null
    private var lastSpeed: Double? = null
    private var lastHeartRateVariability: Double? = null
    
    companion object {
        private const val CHANNEL_NAME = "com.body_battery/health_services"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        healthServicesClient = HealthServices.getClient(context)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        job.cancel()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "hasCapabilities" -> hasCapabilities(result)
            "requestPermissions" -> requestPermissions(result)
            "getCurrentData" -> getCurrentData(result)
            "getHeartRate" -> getHeartRate(result)
            "getSteps" -> getSteps(result)
            "getCalories" -> getCalories(result)
            "getDistance" -> getDistance(result)
            "getSpeed" -> getSpeed(result)
            "getHeartRateVariability" -> getHeartRateVariability(result)
            "getStressLevel" -> getStressLevel(result)
            "getSleepData" -> getSleepData(result)
            "getActivityData" -> getActivityData(result)
            "startPassiveMonitoring" -> startPassiveMonitoring(result)
            "stopPassiveMonitoring" -> stopPassiveMonitoring(result)
            "subscribeToDataUpdates" -> subscribeToDataUpdates(result)
            else -> result.notImplemented()
        }
    }
    
    private fun initialize(result: Result) {
        launch {
            try {
                // Health Services는 실제 워치에서만 작동
                // 개발 중에는 Mock 데이터 사용
                val initData = mapOf(
                    "success" to true,
                    "supportedTypes" to listOf(
                        "HEART_RATE_BPM",
                        "STEPS_DAILY", 
                        "CALORIES_DAILY",
                        "DISTANCE_DAILY"
                    )
                )
                
                result.success(initData)
            } catch (e: Exception) {
                result.error("INIT_ERROR", "Health Services 초기화 실패: ${e.message}", null)
            }
        }
    }
    
    private fun hasCapabilities(result: Result) {
        // 실제 워치에서는 capabilities API 사용
        // 개발 중에는 true 반환
        result.success(true)
    }
    
    private fun requestPermissions(result: Result) {
        // Health Services는 별도의 권한 요청이 필요 없음 (AndroidManifest에서 처리)
        result.success(true)
    }
    
    private fun getCurrentData(result: Result) {
        launch {
            try {
                val dataMap = mutableMapOf<String, Any?>()
                
                // Mock 데이터 사용 (실제 워치에서는 센서 데이터)
                lastHeartRate = 70 + (Math.random() * 30).toInt()
                dataMap["heartRate"] = lastHeartRate
                
                lastSteps = 5000 + (Math.random() * 5000).toInt()
                dataMap["steps"] = lastSteps
                
                // 심박변이도 (HRV)
                lastHeartRateVariability = calculateMockHRV()
                dataMap["heartRateVariability"] = lastHeartRateVariability
                
                // 타임스탬프
                dataMap["timestamp"] = System.currentTimeMillis()
                
                result.success(dataMap)
            } catch (e: Exception) {
                result.error("DATA_ERROR", "데이터 수집 실패: ${e.message}", null)
            }
        }
    }
    
    private fun getHeartRate(result: Result) {
        result.success(lastHeartRate ?: 70)
    }
    
    private fun getSteps(result: Result) {
        result.success(lastSteps ?: 0)
    }
    
    private fun getCalories(result: Result) {
        result.success(lastCalories ?: 0.0)
    }
    
    private fun getDistance(result: Result) {
        result.success(lastDistance ?: 0.0)
    }
    
    private fun getSpeed(result: Result) {
        result.success(lastSpeed ?: 0.0)
    }
    
    private fun getHeartRateVariability(result: Result) {
        result.success(lastHeartRateVariability ?: calculateMockHRV())
    }
    
    private fun getStressLevel(result: Result) {
        // 스트레스 레벨 계산 (HRV 기반)
        val hrv = lastHeartRateVariability ?: calculateMockHRV()
        val stressLevel = calculateStressFromHRV(hrv)
        result.success(stressLevel)
    }
    
    private fun getSleepData(result: Result) {
        // Mock 수면 데이터
        val sleepData = mapOf(
            "startTime" to (System.currentTimeMillis() - 8 * 60 * 60 * 1000),
            "endTime" to System.currentTimeMillis(),
            "deepSleepMinutes" to 90,
            "remSleepMinutes" to 120,
            "lightSleepMinutes" to 210,
            "awakeMinutes" to 60,
            "quality" to 75.0
        )
        result.success(sleepData)
    }
    
    private fun getActivityData(result: Result) {
        // Mock 활동 데이터
        val activities = listOf(
            mapOf(
                "type" to "walking",
                "durationMinutes" to 30,
                "intensity" to 40.0,
                "caloriesBurned" to 120
            )
        )
        result.success(activities)
    }
    
    private fun startPassiveMonitoring(result: Result) {
        // 실제 구현에서는 PassiveListenerService 등록
        // 개발 중에는 성공 반환
        result.success(true)
    }
    
    private fun stopPassiveMonitoring(result: Result) {
        // 실제 구현에서는 PassiveListenerService 해제
        result.success(true)
    }
    
    private fun subscribeToDataUpdates(result: Result) {
        // 실시간 데이터 업데이트 구독 시뮬레이션
        launch {
            while (true) {
                delay(5000) // 5초마다 업데이트
                
                // Mock 데이터 생성
                lastHeartRate = 70 + (Math.random() * 30).toInt()
                sendDataToFlutter("heartRate", lastHeartRate!!)
                
                lastSteps = (lastSteps ?: 0) + (Math.random() * 10).toInt()
                sendDataToFlutter("steps", lastSteps!!)
            }
        }
        
        result.success(true)
    }
    
    private fun sendDataToFlutter(type: String, value: Any) {
        channel.invokeMethod("onDataUpdate", mapOf(
            "type" to type,
            "value" to value,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    private fun calculateMockHRV(): Double {
        // Mock HRV 계산
        return 40.0 + Math.random() * 40.0
    }
    
    private fun calculateStressFromHRV(hrv: Double): Double {
        // HRV 기반 스트레스 계산
        return when {
            hrv < 20 -> 80.0
            hrv < 40 -> 60.0
            hrv < 60 -> 40.0
            else -> 20.0
        }
    }
}

// 패시브 데이터 수신 서비스 (실제 구현 시 필요)
class PassiveDataService : PassiveListenerService() {
    override fun onNewDataPointsReceived(dataPoints: DataPointContainer) {
        // 실제 구현에서는 여기서 데이터 처리
    }
}