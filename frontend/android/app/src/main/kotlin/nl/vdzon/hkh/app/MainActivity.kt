package nl.vdzon.hkh.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val installer by lazy { UpdateInstaller(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedVersionCode" -> result.success(installer.installedVersionCode())
                "canInstallPackages" -> result.success(installer.canInstallPackages())
                "requestInstallPermission" -> {
                    installer.requestInstallPermission()
                    result.success(null)
                }
                "downloadAndInstall" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    if (url == null || fileName == null) {
                        result.error("bad-args", "url/fileName ontbreken", null)
                        return@setMethodCallHandler
                    }
                    thread {
                        runCatching { installer.downloadAndInstall(url, fileName) }
                            .onSuccess { runOnUiThread { result.success(null) } }
                            .onFailure { error ->
                                runOnUiThread { result.error("download-failed", error.message, null) }
                            }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val CHANNEL = "nl.vdzon.hkh/updater"
    }
}
