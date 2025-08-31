package net.fullstackhub.bodybattery

import android.content.Context
import com.google.android.gms.wearable.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import com.google.android.gms.tasks.Task
import org.json.JSONObject
import kotlin.coroutines.CoroutineContext

class WearDataLayerPlugin : FlutterPlugin, MethodCallHandler, CoroutineScope,
    DataClient.OnDataChangedListener, MessageClient.OnMessageReceivedListener,
    CapabilityClient.OnCapabilityChangedListener {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var dataClient: DataClient
    private lateinit var messageClient: MessageClient
    private lateinit var nodeClient: NodeClient
    private lateinit var capabilityClient: CapabilityClient
    
    // Coroutine scope
    private val job = Job()
    override val coroutineContext: CoroutineContext
        get() = Dispatchers.Main + job
    
    private var connectedNodes = mutableSetOf<String>()
    
    companion object {
        private const val CHANNEL_NAME = "body_battery/wear_data"
        private const val DATA_PATH_PREFIX = "/body_battery"
        private const val BATTERY_PATH = "$DATA_PATH_PREFIX/battery"
        private const val HEALTH_PATH = "$DATA_PATH_PREFIX/health"
        private const val COMMAND_PATH = "$DATA_PATH_PREFIX/command"
        private const val SYNC_PATH = "$DATA_PATH_PREFIX/sync"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        // Wearable API 클라이언트 초기화
        dataClient = Wearable.getDataClient(context)
        messageClient = Wearable.getMessageClient(context)
        nodeClient = Wearable.getNodeClient(context)
        capabilityClient = Wearable.getCapabilityClient(context)
        
        // 리스너 등록
        dataClient.addListener(this)
        messageClient.addListener(this)
        capabilityClient.addListener(this, android.net.Uri.parse("wear://*/body_battery_app"), CapabilityClient.FILTER_REACHABLE)
        
        // 연결된 노드 찾기
        findConnectedNodes()
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        dataClient.removeListener(this)
        messageClient.removeListener(this)
        capabilityClient.removeListener(this)
        job.cancel()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "getConnectedDevices" -> getConnectedDevices(result)
            "sendMessage" -> sendMessage(call, result)
            "sendData" -> sendData(call, result)
            "requestSync" -> requestSync(result)
            "isConnected" -> isConnected(result)
            else -> result.notImplemented()
        }
    }
    
    private fun initialize(result: Result) {
        launch {
            try {
                findConnectedNodes()
                result.success(true)
            } catch (e: Exception) {
                result.error("INIT_ERROR", "Wear Data Layer 초기화 실패: ${e.message}", null)
            }
        }
    }
    
    private fun findConnectedNodes() {
        launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                connectedNodes.clear()
                nodes.forEach { node ->
                    connectedNodes.add(node.id)
                }
                
                // Flutter로 연결 상태 알림
                channel.invokeMethod("onConnectionChanged", mapOf(
                    "connected" to connectedNodes.isNotEmpty(),
                    "deviceCount" to connectedNodes.size,
                    "deviceIds" to connectedNodes.toList()
                ))
            } catch (e: Exception) {
                // 노드 찾기 실패
            }
        }
    }
    
    private fun getConnectedDevices(result: Result) {
        launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                val devices = nodes.map { node ->
                    mapOf(
                        "id" to node.id,
                        "displayName" to node.displayName,
                        "isNearby" to node.isNearby
                    )
                }
                result.success(devices)
            } catch (e: Exception) {
                result.success(emptyList<Map<String, Any>>())
            }
        }
    }
    
    private fun sendMessage(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")
        val path = call.argument<String>("path")
        val data = call.argument<String>("data")
        
        if (deviceId == null || path == null || data == null) {
            result.error("INVALID_ARGS", "필수 매개변수 누락", null)
            return
        }
        
        launch {
            try {
                val task = messageClient.sendMessage(deviceId, path, data.toByteArray())
                task.await()
                result.success(true)
            } catch (e: Exception) {
                result.error("SEND_ERROR", "메시지 전송 실패: ${e.message}", null)
            }
        }
    }
    
    private fun sendData(call: MethodCall, result: Result) {
        val path = call.argument<String>("path") ?: HEALTH_PATH
        val data = call.argument<String>("data")
        
        if (data == null) {
            result.error("INVALID_ARGS", "데이터 누락", null)
            return
        }
        
        launch {
            try {
                val putDataReq = PutDataMapRequest.create(path)
                val dataMap = putDataReq.dataMap
                
                // JSON 파싱 및 DataMap에 추가
                val jsonObject = JSONObject(data)
                jsonObject.keys().forEach { key ->
                    when (val value = jsonObject.get(key)) {
                        is Int -> dataMap.putInt(key, value)
                        is Long -> dataMap.putLong(key, value)
                        is Double -> dataMap.putDouble(key, value)
                        is Float -> dataMap.putFloat(key, value)
                        is String -> dataMap.putString(key, value)
                        is Boolean -> dataMap.putBoolean(key, value)
                    }
                }
                
                dataMap.putLong("timestamp", System.currentTimeMillis())
                
                val putDataRequest = putDataReq.asPutDataRequest()
                putDataRequest.setUrgent()
                
                val task = dataClient.putDataItem(putDataRequest)
                task.await()
                
                result.success(true)
            } catch (e: Exception) {
                result.error("DATA_ERROR", "데이터 전송 실패: ${e.message}", null)
            }
        }
    }
    
    private fun requestSync(result: Result) {
        // 모든 연결된 노드에 동기화 요청 전송
        launch {
            try {
                connectedNodes.forEach { nodeId ->
                    messageClient.sendMessage(nodeId, SYNC_PATH, "sync".toByteArray()).await()
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("SYNC_ERROR", "동기화 요청 실패: ${e.message}", null)
            }
        }
    }
    
    private fun isConnected(result: Result) {
        result.success(connectedNodes.isNotEmpty())
    }
    
    // DataClient.OnDataChangedListener 구현
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            when (event.type) {
                DataEvent.TYPE_CHANGED -> {
                    val dataItem = event.dataItem
                    val path = dataItem.uri.path
                    
                    when (path) {
                        BATTERY_PATH -> handleBatteryData(dataItem)
                        HEALTH_PATH -> handleHealthData(dataItem)
                        else -> handleGenericData(dataItem)
                    }
                }
                DataEvent.TYPE_DELETED -> {
                    // 데이터 삭제 처리
                }
            }
        }
    }
    
    private fun handleBatteryData(dataItem: DataItem) {
        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
        
        val batteryData = mapOf(
            "type" to "battery",
            "level" to dataMap.getInt("level", 0),
            "status" to dataMap.getString("status", "unknown"),
            "changeRate" to dataMap.getDouble("changeRate", 0.0),
            "recommendation" to dataMap.getString("recommendation", ""),
            "timestamp" to dataMap.getLong("timestamp", System.currentTimeMillis())
        )
        
        // Flutter로 데이터 전송
        channel.invokeMethod("onDataReceived", batteryData)
    }
    
    private fun handleHealthData(dataItem: DataItem) {
        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
        
        val healthData = mapOf(
            "type" to "health",
            "heartRate" to dataMap.getInt("heartRate", 0),
            "hrv" to dataMap.getDouble("hrv", 0.0),
            "steps" to dataMap.getInt("steps", 0),
            "stressLevel" to dataMap.getDouble("stressLevel", 0.0),
            "timestamp" to dataMap.getLong("timestamp", System.currentTimeMillis())
        )
        
        // Flutter로 데이터 전송
        channel.invokeMethod("onDataReceived", healthData)
    }
    
    private fun handleGenericData(dataItem: DataItem) {
        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
        val data = mutableMapOf<String, Any?>()
        
        dataMap.keySet().forEach { key ->
            data[key] = when {
                dataMap.containsKey(key) -> {
                    // DataMap에서 값 추출
                    try {
                        dataMap.getString(key) ?: dataMap.getInt(key)
                    } catch (e: Exception) {
                        null
                    }
                }
                else -> null
            }
        }
        
        channel.invokeMethod("onDataReceived", data)
    }
    
    // MessageClient.OnMessageReceivedListener 구현
    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val data = String(messageEvent.data)
        
        when (path) {
            COMMAND_PATH -> {
                // 명령 처리
                channel.invokeMethod("onCommandReceived", mapOf(
                    "command" to data,
                    "from" to messageEvent.sourceNodeId
                ))
            }
            SYNC_PATH -> {
                // 동기화 요청 처리
                channel.invokeMethod("onSyncRequested", mapOf(
                    "from" to messageEvent.sourceNodeId
                ))
            }
            else -> {
                // 기타 메시지
                channel.invokeMethod("onMessageReceived", mapOf(
                    "path" to path,
                    "data" to data,
                    "from" to messageEvent.sourceNodeId
                ))
            }
        }
    }
    
    // CapabilityClient.OnCapabilityChangedListener 구현
    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        val nodes = capabilityInfo.nodes
        connectedNodes.clear()
        nodes.forEach { node ->
            if (node.isNearby) {
                connectedNodes.add(node.id)
            }
        }
        
        // 연결 상태 업데이트
        channel.invokeMethod("onConnectionChanged", mapOf(
            "connected" to connectedNodes.isNotEmpty(),
            "deviceCount" to connectedNodes.size
        ))
    }
}