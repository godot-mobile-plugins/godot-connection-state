#
# © 2025-present https://github.com/cengiz-pz
#

@tool
@icon("icon.png")
class_name ConnectionState extends Node


signal connection_established(a_info: ConnectionInfo)
signal connection_lost(a_info: ConnectionInfo)


const PLUGIN_SINGLETON_NAME: String = "@pluginName@"


var _plugin_singleton: Object


func _ready() -> void:
	_update_plugin()


func _notification(a_what: int) -> void:
	if a_what == NOTIFICATION_APPLICATION_RESUMED:
		_update_plugin()


func _update_plugin() -> void:
	if _plugin_singleton == null:
		if Engine.has_singleton(PLUGIN_SINGLETON_NAME):
			_plugin_singleton = Engine.get_singleton(PLUGIN_SINGLETON_NAME)
			_connect_signals()
		elif not OS.has_feature("editor_hint"):
			ConnectionState.log_error("%s singleton not found on this platform!" % PLUGIN_SINGLETON_NAME)


func _connect_signals() -> void:
	_plugin_singleton.connect("connection_established", _on_connection_established)
	_plugin_singleton.connect("connection_lost", _on_connection_lost)


# Returns an Array of ConnectionInfo objects
func get_connection_state() -> Array[ConnectionInfo]:
	var __result: Array[ConnectionInfo] = []

	if _plugin_singleton:
		var __connections: Array = _plugin_singleton.get_connection_state()

		for __connection in __connections:
			__result.append(ConnectionInfo.new(__connection))
	else:
		ConnectionState.log_error("%s plugin not initialized" % PLUGIN_SINGLETON_NAME)

	return __result


func _on_connection_established(a_info: Dictionary) -> void:
	connection_established.emit(ConnectionInfo.new(a_info))


func _on_connection_lost(a_info: Dictionary) -> void:
	connection_lost.emit(ConnectionInfo.new(a_info))


static func log_error(a_description: String) -> void:
	push_error("%s: %s" % [PLUGIN_SINGLETON_NAME, a_description])


static func log_warn(a_description: String) -> void:
	push_warning("%s: %s" % [PLUGIN_SINGLETON_NAME, a_description])


static func log_info(a_description: String) -> void:
	print_rich("[color=lime]%s: INFO: %s[/color]" % [PLUGIN_SINGLETON_NAME, a_description])
