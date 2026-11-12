package com.example.time_line_demo

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale

/**
 * 原生能力通道（不引入第三方插件，全部用系统 API）：
 *  timeline/audio    录音播放（MediaPlayer）
 *  timeline/media    视频时长 / 首帧缩略图（MediaMetadataRetriever）
 *  timeline/file     PDF 页数 / 逐页渲染（PdfRenderer）
 *  timeline/location 当前位置 + 反查省市区（LocationManager + Geocoder）
 *  timeline/nav      唤起导航 App（高德 / 百度 / 系统 geo:）
 */
class MainActivity : FlutterActivity() {

    private var player: MediaPlayer? = null
    private var audioChannel: MethodChannel? = null
    private var pendingLocationResult: MethodChannel.Result? = null

    private val LOCATION_REQUEST = 1001
    private val locationHandler = Handler(Looper.getMainLooper())
    private var singleUpdateListener: LocationListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // -------- 语音播放 --------
        audioChannel = MethodChannel(messenger, "timeline/audio")
        audioChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("ARG", "path is empty", null)
                    } else {
                        try {
                            releasePlayer()
                            player = MediaPlayer().apply {
                                setDataSource(path)
                                setOnCompletionListener {
                                    audioChannel?.invokeMethod("completed", null)
                                    releasePlayer()
                                }
                                setOnErrorListener { _, _, _ ->
                                    audioChannel?.invokeMethod("completed", null)
                                    true
                                }
                                prepare()
                                start()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            releasePlayer()
                            result.error("PLAY", e.message, null)
                        }
                    }
                }
                "stop" -> {
                    releasePlayer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ------------- 视频 -------------
        MethodChannel(messenger, "timeline/media").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (path.isNullOrEmpty()) {
                result.error("ARG", "path is empty", null)
                return@setMethodCallHandler
            }
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(path)
                when (call.method) {
                    "duration" -> {
                        val ms = retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            ?.toLongOrNull() ?: 0L
                        result.success(ms.toInt())
                    }
                    "thumb" -> {
                        val width = call.argument<Int>("width") ?: 320
                        val frame = retriever.getFrameAtTime(
                            0,
                            MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                        )
                        if (frame == null) {
                            result.success(null)
                        } else {
                            val ratio = frame.height.toFloat() / frame.width.toFloat()
                            val h = (width * ratio).toInt().coerceAtLeast(1)
                            val scaled = Bitmap.createScaledBitmap(frame, width, h, true)
                            val out = ByteArrayOutputStream()
                            scaled.compress(Bitmap.CompressFormat.PNG, 90, out)
                            result.success(out.toByteArray())
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("MEDIA", e.message, null)
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
            }
        }

        // ------------- PDF -------------
        MethodChannel(messenger, "timeline/file").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (path.isNullOrEmpty()) {
                result.error("ARG", "path is empty", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "pdfPages", "pdfRender" -> {
                    var pfd: ParcelFileDescriptor? = null
                    var renderer: PdfRenderer? = null
                    try {
                        pfd = ParcelFileDescriptor.open(
                            File(path), ParcelFileDescriptor.MODE_READ_ONLY
                        )
                        renderer = PdfRenderer(pfd)
                        if (call.method == "pdfPages") {
                            result.success(renderer.pageCount)
                        } else {
                            val index = call.argument<Int>("index") ?: 0
                            val width = call.argument<Int>("width") ?: 1000
                            if (index < 0 || index >= renderer.pageCount) {
                                result.error("INDEX", "page out of range", null)
                                return@setMethodCallHandler
                            }
                            renderer.openPage(index).use { page ->
                                val h = (width.toFloat() * page.height / page.width)
                                    .toInt().coerceAtLeast(1)
                                val bmp = Bitmap.createBitmap(
                                    width, h, Bitmap.Config.ARGB_8888
                                )
                                bmp.eraseColor(Color.WHITE)
                                page.render(
                                    bmp, null, null,
                                    PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                                )
                                val out = ByteArrayOutputStream()
                                bmp.compress(Bitmap.CompressFormat.PNG, 90, out)
                                bmp.recycle()
                                result.success(out.toByteArray())
                            }
                        }
                    } catch (e: Exception) {
                        result.error("PDF", e.message, null)
                    } finally {
                        try {
                            renderer?.close()
                        } catch (_: Exception) {
                        }
                        try {
                            pfd?.close()
                        } catch (_: Exception) {
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ------------- 定位 -------------
        MethodChannel(messenger, "timeline/location").setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> handleLocation(result)
                else -> result.notImplemented()
            }
        }

        // ------------- 导航 -------------
        MethodChannel(messenger, "timeline/nav").setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val lat = call.argument<Double>("lat") ?: 0.0
            val lng = call.argument<Double>("lng") ?: 0.0
            val name = call.argument<String>("name") ?: "目的地"
            val encoded = Uri.encode(name)
            // 有经纬度就直接导航到该点；只有“省+市”文字时用关键字搜索
            val hasPoint = !(lat == 0.0 && lng == 0.0)
            val candidates =
                if (hasPoint)
                    listOf(
                        "androidamap://viewMap?sourceApplication=timeline&poiname=$encoded&lat=$lat&lon=$lng&dev=0",
                        "baidumap://map/marker?location=$lat,$lng&title=$encoded&content=$encoded&src=timeline",
                        "geo:$lat,$lng?q=$lat,$lng($encoded)"
                    )
                else
                    listOf(
                        "androidamap://keywordNavi?sourceApplication=timeline&keyword=$encoded&style=2",
                        "baidumap://map/place/search?query=$encoded&src=timeline",
                        "geo:0,0?q=$encoded"
                    )
            for (url in candidates) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                    return@setMethodCallHandler
                } catch (_: Exception) {
                    // 换下一个方案
                }
            }
            result.success(false)
        }
    }

    // ---------------- 定位实现 ----------------

    private fun hasLocationPermission(): Boolean {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED ||
            coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun handleLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            pendingLocationResult = result
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LOCATION_REQUEST
            )
            return
        }
        resolveLocation(result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_REQUEST) return
        val pending = pendingLocationResult
        pendingLocationResult = null
        if (pending == null) return
        if (hasLocationPermission()) {
            resolveLocation(pending)
        } else {
            pending.error("PERM", "用户拒绝了定位权限", null)
        }
    }

    private fun resolveLocation(result: MethodChannel.Result) {
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        var best: Location? = null
        for (provider in listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )) {
            try {
                val l = lm.getLastKnownLocation(provider)
                if (l != null && (best == null || l.time > best!!.time)) best = l
            } catch (_: Exception) {
            }
        }
        if (best != null) {
            result.success(buildLocationMap(best!!))
            return
        }
        // 没有历史位置：同时请求 GPS 与网络定位，最多等 12 秒
        var finished = false
        fun cleanup() {
            try {
                singleUpdateListener?.let { lm.removeUpdates(it) }
            } catch (_: Exception) {
            }
            singleUpdateListener = null
        }
        fun finish(loc: Location?) {
            if (finished) return
            finished = true
            cleanup()
            if (loc == null) {
                result.error("LOC", "暂时拿不到当前位置，请稍后重试或手动填写", null)
            } else {
                result.success(buildLocationMap(loc))
            }
        }
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = finish(location)
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        singleUpdateListener = listener
        var requested = 0
        for (provider in listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER
        )) {
            try {
                if (lm.isProviderEnabled(provider)) {
                    lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
                    requested++
                }
            } catch (_: Exception) {
            }
        }
        if (requested == 0) {
            finish(null)
            return
        }
        locationHandler.postDelayed({ finish(null) }, 12000)
    }

    private fun buildLocationMap(loc: Location): Map<String, Any> {
        val map = HashMap<String, Any>()
        map["lat"] = loc.latitude
        map["lng"] = loc.longitude
        var province = ""
        var city = ""
        try {
            val geocoder = Geocoder(this, Locale.CHINA)
            val list: List<Address>? = geocoder.getFromLocation(loc.latitude, loc.longitude, 1)
            if (!list.isNullOrEmpty()) {
                val a = list[0]
                province = a.adminArea ?: ""
                city = a.locality ?: (a.subAdminArea ?: "")
            }
        } catch (_: Exception) {
        }
        if (province.isEmpty() && city.isEmpty()) {
            province = "当前位置"
        }
        map["province"] = province
        map["city"] = city
        return map
    }

    private fun releasePlayer() {
        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {
        }
        player = null
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}
