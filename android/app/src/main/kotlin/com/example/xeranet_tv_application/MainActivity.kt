package com.example.xeranet_tv_application

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.panaccess.android.drm.*
import org.json.JSONObject
import java.util.HashMap

class MainActivity: FlutterActivity() {

    private val CHANNEL = "xeranet_drm"
    private val TAG = "PanExoMainActivity"

    private var drm: IPanaccessDrm? = null
    private var methodChannel: MethodChannel? = null

    // Login credentials (stored locally for async flow)
    private var usernameStored = ""
    private var passwordStored = ""
    private var licenseStored = ""
    private var pinStored = ""
    private var loginWithMAC = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        drm = PanaccessDrm.getInst()
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native_video_player",
            NativePlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        methodChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                "initDrm" -> {
                    val company = call.argument<String>("company") ?: "RCUBE"
                    val brand = call.argument<String>("brand") ?: android.os.Build.BRAND
                    val appVersion = call.argument<String>("appVersion") ?: "1.0.0r"
                    val osVersion = call.argument<String>("osVersion") ?: "Android12"
                    val hint = call.argument<Int>("hint") ?: 0

                    if (drm!!.isInitialized) {
                        result.success("DRM Already Initialized")
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            Log.i(TAG, "Starting PanaccessDrm.init(), serial: ${drm!!.boxSerial}")
                            drm!!.init(
                                applicationContext,
                                company,
                                brand,
                                appVersion,
                                osVersion,
                                hint
                            )
                            
                            // Set Message Listener (Standard in reference MainActivity.java)
                            drm!!.setCVMessageListener(object : ICVMessageListener {
                                override fun onMessage(jsonObject: JSONObject?) {
                                    Log.i(TAG, "CV Message: $jsonObject")
                                }
                            }, 0)

                            Log.i(TAG, "PanaccessDrm.init() finished. Waiting for user login...")
                            
                            runOnUiThread { result.success("DRM Initialized") }
                        } catch (e: Exception) {
                            Log.e(TAG, "Init error: ${e.message}")
                            runOnUiThread { result.error("DRM_INIT_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "login" -> {
                    usernameStored = call.argument<String>("username") ?: ""
                    passwordStored = call.argument<String>("password") ?: ""
                    licenseStored = call.argument<String>("license") ?: ""
                    pinStored = call.argument<String>("pin") ?: ""
                    loginWithMAC = call.argument<Boolean>("useMAC") ?: false

                    if (!drm!!.isInitialized) {
                        result.error("DRM_ERROR", "DRM not initialized", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val success = performSynchronousLogin()
                            runOnUiThread {
                                if (success) {
                                    result.success("LOGIN_SUCCESS")
                                } else {
                                    result.error("LOGIN_FAILED", "Login verification failed", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Login error: ${e.message}")
                            runOnUiThread { result.error("LOGIN_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "getStreamUrl" -> {
                    val urlParamRaw = call.argument<Any>("streamUrl")
                    val urlParam = urlParamRaw?.toString() ?: ""
                    Thread {
                        try {
                            Log.i(TAG, "Requesting Stream URL for: $urlParam")
                            
                            val isDrmInit = drm?.isInitialized ?: false
                            val sessionId = drm?.sessionId ?: "NONE"
                            Log.i(TAG, "DRM Status — Init: $isDrmInit, Session: $sessionId")

                            if (!isDrmInit) {
                                runOnUiThread { result.error("DRM_NOT_INIT", "DRM not initialized", null) }
                                return@Thread
                            }

                            // HELPER: Try different ways to get the URL
                            fun resolveUrl(p: String): String? {
                                // 1. Try as direct input (it might already be an ID or a valid resolved URL)
                                var u = drm!!.getTopLevelStreamM3u8Url(p)
                                
                                // 2. Try REGEX extraction if it looks like a Panaccess gateway URL
                                if (u == null) {
                                    // Handles: streamId=123, streamId-123, streamld-123, streamld=123 (case insensitive)
                                    val regex = Regex("(?:stream[Ii]d|streamld)[=-](\\d+)")
                                    val matchResult = regex.find(p)
                                    val extractedId = matchResult?.groupValues?.get(1)
                                    
                                    if (extractedId != null) {
                                        Log.i(TAG, "Regex matched ID: $extractedId from source: $p")
                                        u = drm!!.getTopLevelStreamM3u8Url(extractedId)
                                    }
                                }
                                
                                // 3. Try parsing as Int fallback
                                if (u == null && p.all { it.isDigit() }) {
                                    try {
                                        val idInt = p.toInt()
                                        u = drm!!.getTopLevelStreamM3u8Url(idInt.toString())
                                    } catch (ignored: Exception) {}
                                }
                                return u
                            }

                            var url = resolveUrl(urlParam)

                            // RETRY: If session is null or resolution failed, wait 300ms and try again (Optimized for instant playback)
                            if (url == null && sessionId == "NONE") {
                                Log.w(TAG, "Session is NONE, waiting 300ms for stabilization...")
                                Thread.sleep(300)
                                url = resolveUrl(urlParam)
                            }
                            
                            runOnUiThread {
                                if (url != null) {
                                    Log.i(TAG, "Stream URL resolved successfully: $url")
                                    result.success(url)
                                } else {
                                    Log.e(TAG, "Stream URL resolution failed for: $urlParam. Falling back to original.")
                                    result.success(urlParam)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Stream error: ${e.message}")
                            runOnUiThread { result.error("STREAM_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "getCatchupUrl" -> {
                    val catchupIdRaw = call.argument<Any>("catchupId")
                    val catchupId = when (catchupIdRaw) {
                        is Int -> catchupIdRaw
                        is String -> catchupIdRaw.toIntOrNull() ?: 0
                        else -> 0
                    }
                    Thread {
                        try {
                            Log.i(TAG, "Requesting Catchup URL for ID: $catchupId")
                            val url = drm!!.getTopLevelCatchupM3u8Url(catchupId)
                            runOnUiThread {
                                if (url != null) {
                                    Log.i(TAG, "Catchup URL success: $url")
                                    result.success(url)
                                } else {
                                    Log.e(TAG, "Catchup URL returned null for ID: $catchupId")
                                    result.error("CATCHUP_ERROR", "Catchup URL null", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Catchup error: ${e.message}")
                            runOnUiThread { result.error("CATCHUP_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "getVodUrl" -> {
                    val vodIdRaw = call.argument<Any>("vodId")
                    val vodId = when (vodIdRaw) {
                        is Int -> vodIdRaw
                        is String -> vodIdRaw.toIntOrNull() ?: 0
                        else -> 0
                    }
                    Thread {
                        try {
                            Log.i(TAG, "Requesting VOD URL for ID: $vodId")
                            val url = drm!!.getTopLevelVodM3u8Url(vodId)
                            runOnUiThread {
                                if (url != null) {
                                    Log.i(TAG, "VOD URL success: $url")
                                    result.success(url)
                                } else {
                                    Log.e(TAG, "VOD URL returned null for ID: $vodId")
                                    result.error("VOD_ERROR", "VOD URL null", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "VOD error: ${e.message}")
                            runOnUiThread { result.error("VOD_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "getDrmInfo" -> {
                    try {
                        val map: MutableMap<String, Any?> = HashMap()
                        map["initialized"] = drm!!.isInitialized
                        map["personalized"] = drm!!.isPersonalized
                        map["version"] = drm!!.version
                        map["boxMAC"] = drm!!.boxMAC
                        map["sessionId"] = drm!!.sessionId
                        map["boxSerial"] = drm!!.boxSerial
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("DRM_INFO_ERROR", e.message, null)
                    }
                }

                "callCasFunction" -> {
                    val functionName = call.argument<String>("functionName") ?: ""
                    val paramsRaw = call.argument<Map<String, String>>("params") ?: emptyMap()
                    val params = HashMap<String, String>()
                    params.putAll(paramsRaw)

                    Thread {
                        try {
                            Log.i(TAG, "Calling CAS function: $functionName with params: $params")
                            drm!!.callCasFunction(object : ICasFunctionCaller {
                                override fun onFailure(casError: CasError) {
                                    Log.e(TAG, "CAS Function $functionName failed: ${casError.code}: ${casError.message}")
                                    runOnUiThread {
                                        result.error("CAS_ERROR", "Error ${casError.code}: ${casError.message}", casError.tag)
                                    }
                                }

                                override fun onSuccess(jsonObject: JSONObject?) {
                                    Log.i(TAG, "CAS Function $functionName success")
                                    runOnUiThread {
                                        result.success(jsonObject?.toString())
                                    }
                                }

                                override fun onTimeout() {
                                    Log.e(TAG, "CAS Function $functionName timed out")
                                    runOnUiThread {
                                        result.error("CAS_TIMEOUT", "Function call timed out", null)
                                    }
                                }
                            }, functionName, params, null, -1, 30000, false)
                        } catch (e: Exception) {
                            Log.e(TAG, "CAS Function $functionName exception: ${e.message}")
                            runOnUiThread {
                                result.error("CAS_EXCEPTION", e.message, null)
                            }
                        }
                    }.start()
                }

                "getBouquets" -> {
                    if (!drm!!.isInitialized) {
                        result.error("DRM_ERROR", "DRM not initialized", null)
                        return@setMethodCallHandler
                    }

                    val sessionId = drm!!.sessionId ?: ""
                    val params = HashMap<String, String>()
                    params["sessionId"] = sessionId

                    Thread {
                        try {
                            Log.i(TAG, "Fetching Bouquets with sessionId: $sessionId")
                            drm!!.callCasFunction(object : ICasFunctionCaller {
                                override fun onFailure(casError: CasError) {
                                    Log.e(TAG, "Get Bouquets failed: ${casError.code}: ${casError.message}")
                                    runOnUiThread {
                                        result.error("BOUQUETS_ERROR", "Error ${casError.code}: ${casError.message}", casError.tag)
                                    }
                                }

                                override fun onSuccess(jsonObject: JSONObject?) {
                                    Log.i(TAG, "Get Bouquets success: $jsonObject")
                                    runOnUiThread {
                                        result.success(jsonObject?.toString())
                                    }
                                }

                                override fun onTimeout() {
                                    Log.e(TAG, "Get Bouquets timed out")
                                    runOnUiThread {
                                        result.error("BOUQUETS_TIMEOUT", "Bouquets fetch timed out", null)
                                    }
                                }
                            }, "getBouquets", params, null, -1, 30000, false)
                        } catch (e: Exception) {
                            Log.e(TAG, "Get Bouquets exception: ${e.message}")
                            runOnUiThread {
                                result.error("BOUQUETS_EXCEPTION", e.message, null)
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Replicates the synchronous login flow from Panaccess version _7
     * Returns true if login is successful, false otherwise.
     */
    private fun performSynchronousLogin(): Boolean {
        Log.i(TAG, "Starting synchronous login flow...")
        if (drm == null || !drm!!.isInitialized) {
            Log.e(TAG, "DRM not initialized for login")
            return false
        }

        // FIX #1: ALWAYS use username/password — NEVER use MAC login.
        // boxMAC: -wrong_size error means the MAC is not registered/valid on this device.
        // Forcing credential-based login bypasses the MAC issue entirely.
        val useMac = false
        if (loginWithMAC) {
            Log.w(TAG, "MAC login was requested but DISABLED to avoid boxMAC:-wrong_size issue. Using credentials instead.")
        }

        // 2. Pass login credentials (setBoxLogin) - Blocking call
        try {
            if (useMac) {
                Log.i(TAG, "Performing MAC-based login (setBoxLogin(true, null, null))")
                drm!!.setBoxLogin(true, null, null)
            } else {
                Log.i(TAG, "Performing credential-based login for user: $usernameStored (setBoxLogin(false, u, p))")
                drm!!.setBoxLogin(false, usernameStored, passwordStored)
            }
        } catch (e: DrmException) {
            Log.e(TAG, "Error setting box login: ${e.message}")
            return false
        }

        var isLoginVerified = false
        val lock = java.lang.Object()

        // 3. Verify login credentials - The library says they are blocking calls,
        // but we still use the callback interface if required by the SDK.
        // If it's truly blocking, it will finish on this thread.
        synchronized(lock) {
            drm!!.verifyLoginCredentials(object : ICasFunctionCaller {
                override fun onFailure(casError: CasError) {
                    Log.e(TAG, "Login failed callback: ${casError.code}: ${casError.message}")
                    synchronized(lock) {
                        isLoginVerified = false
                        lock.notify()
                    }
                }

                override fun onSuccess(jsonObject: JSONObject?) {
                    Log.i(TAG, "Login success callback! Session ID: ${drm?.sessionId}")
                    try {
                        // Blocking call as per version _7
                        drm?.configureAppBehaviorService(true, 100)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to configure app behavior: ${e.message}")
                    }
                    // Optimized: Proceed immediately without artificial delay
                    synchronized(lock) {
                        isLoginVerified = true
                        lock.notify()
                    }
                }

                override fun onTimeout() {
                    Log.e(TAG, "Login verification timed out callback")
                    synchronized(lock) {
                        isLoginVerified = false
                        lock.notify()
                    }
                }
            }, "", 0, 0)
            
            // Wait for the synchronous result if the SDK doesn't block the thread itself
            lock.wait(30000) 
        }

        return isLoginVerified
    }
}