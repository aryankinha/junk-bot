class_name AdsService extends Node
# No fabricated rewards: production code only grants from a provider's earned callback.
# The native plugin is optional; desktop/offline builds hide all placements.
signal reward_granted(placement: String)
signal availability_changed
signal dismissed
const TEST_APP_ANDROID := "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
var provider: Node
var pending := ""
func _ready() -> void:
	if OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMobRewardedAd"):
		var value: Node = load("res://src/services/admob_provider.gd").new()
		bind_provider(value)
		add_child(value)

func is_available() -> bool:
	return provider != null and provider.has_method("is_available") and provider.is_available()
func bind_provider(value: Node) -> void:
	provider = value
	if provider.has_signal("earned"):
		provider.earned.connect(_earned)
	if provider.has_signal("closed"):
		provider.closed.connect(func():
			pending = ""
			dismissed.emit())
	if provider.has_signal("availability_changed"):
		provider.availability_changed.connect(func(): availability_changed.emit())
	availability_changed.emit()
func show_rewarded(placement: String) -> bool:
	if not is_available() or not pending.is_empty():
		return false
	pending = placement
	provider.show_rewarded(TEST_REWARDED_ANDROID)
	return true
func _earned() -> void:
	if pending.is_empty():
		return
	var placement := pending
	pending = ""
	reward_granted.emit(placement)
