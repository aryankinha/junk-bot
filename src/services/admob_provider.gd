extends Node
signal earned
signal closed
signal availability_changed
var ad: RewardedAd
var ready_to_show := false
var loading := false
func _ready() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("PoingGodotAdMobRewardedAd"):
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status):
		TelemetryLog.log_event({"t": "ads_initialized"})
		preload_rewarded()
	MobileAds.initialize(listener)
func is_available() -> bool:
	return ready_to_show and ad != null
func preload_rewarded() -> void:
	if loading:
		return
	loading = true
	var callbacks := RewardedAdLoadCallback.new()
	callbacks.on_ad_loaded = func(value: RewardedAd):
		ad = value
		loading = false
		ready_to_show = true
		var fullscreen := FullScreenContentCallback.new()
		fullscreen.on_ad_dismissed_full_screen_content = _dismissed
		fullscreen.on_ad_failed_to_show_full_screen_content = func(_error): _dismissed()
		ad.full_screen_content_callback = fullscreen
		availability_changed.emit()
		TelemetryLog.log_event({"t": "ad_loaded"})
	callbacks.on_ad_failed_to_load = func(_error):
		loading = false
		ready_to_show = false
		availability_changed.emit()
		TelemetryLog.log_event({"t": "ad_load_failed"})
		if is_inside_tree():
			get_tree().create_timer(30).timeout.connect(preload_rewarded, CONNECT_ONE_SHOT)
	RewardedAdLoader.new().load(AdsService.TEST_REWARDED_ANDROID, AdRequest.new(), callbacks)
func show_rewarded(_unit: String) -> void:
	if not is_available():
		return
	ready_to_show = false
	availability_changed.emit()
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_reward):
		TelemetryLog.log_event({"t": "ad_watched"})
		earned.emit()
	ad.show(listener)
func _dismissed() -> void:
	if ad != null:
		ad.destroy()
		ad = null
	ready_to_show = false
	closed.emit()
	availability_changed.emit()
	preload_rewarded()
func _exit_tree() -> void:
	if ad != null:
		ad.destroy()
		ad = null
