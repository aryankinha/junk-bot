@tool
extends SceneTree
func _initialize() -> void:
	call_deferred("configure")
func configure() -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings == null:
		printerr("Run with --editor")
		quit(1)
		return
	settings.set_setting("export/android/java_sdk_path", "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home")
	settings.set_setting("export/android/android_sdk_path", "/Users/aryankinha/Library/Android/sdk")
	print("Configured installed JDK 17 and Android SDK")
	quit()
