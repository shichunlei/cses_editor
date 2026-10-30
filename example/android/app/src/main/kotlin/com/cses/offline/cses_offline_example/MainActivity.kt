package com.cses.offline.cses_offline_example

import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** 当前宿主的微信图片出口；只在用户点击目标后授予单张图片的临时读取权限。 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cses.offline/journal_image_share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val png = call.argument<ByteArray>("png")
                val target = call.argument<String>("target")
                if (png == null || target !in listOf("wechat", "timeline")) {
                    result.error("invalid", "分享图片或目标无效", null)
                    return@setMethodCallHandler
                }
                try {
                    packageManager.getPackageInfo("com.tencent.mm", 0)
                    val directory = File(cacheDir, "journal_share").apply { mkdirs() }
                    // 上次分享可能仍被微信读取，仅清理超过一天的临时图片。
                    directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000 }
                        ?.forEach { it.delete() }
                    val file = File(directory, "journal_${System.currentTimeMillis()}.png")
                    file.writeBytes(png)
                    val uri = FileProvider.getUriForFile(this, "$packageName.journal_share", file)
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "image/png"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri("分享图片", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        if (target == "timeline") {
                            component = ComponentName("com.tencent.mm", "com.tencent.mm.ui.tools.ShareToTimeLineUI")
                        } else {
                            setPackage("com.tencent.mm")
                        }
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
                    result.error("not_installed", "请先安装微信客户端", null)
                } catch (_: Exception) {
                    result.error("unavailable", "当前微信版本不支持此入口，请保存图片后在微信中分享", null)
                }
            }
    }
}
