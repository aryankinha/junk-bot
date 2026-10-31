@tool
extends EditorExportPlugin
func _get_name() -> String:
	return "ScrapDragonTestAds"
func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid
func _get_export_options(_platform: EditorExportPlatform) -> Array[Dictionary]:
	return [{"option": {"name": "scrapdragon/rewarded_test_ads", "type": TYPE_BOOL}, "default_value": false}]
func enabled() -> bool:
	return bool(get_option("scrapdragon/rewarded_test_ads"))
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	if not enabled():
		return []
	var variant := "debug" if debug else "release"
	return PackedStringArray(["res://addons/admob/android/bin/ads/libs/poing-godot-admob-ads-%s.aar" % variant, "res://addons/admob/android/bin/ads/libs/poing-godot-admob-core-%s.aar" % variant])
func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0", "androidx.constraintlayout:constraintlayout:2.2.0"]) if enabled() else PackedStringArray()
func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713" />' if enabled() else ""
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://addons/admob/assets/") or path.begins_with("res://addons/admob/internal/mock/") or path.begins_with("res://addons/admob/android/"):
		skip()
