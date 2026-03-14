#
# © 2025-present https://github.com/cengiz-pz
#

extends Node

@onready var connection_state_node: ConnectionState = $ConnectionState
@onready var get_connection_state_button := %GetStateButton as Button
@onready var _label := %RichTextLabel as RichTextLabel
@onready var _android_texture_rect := %AndroidTextureRect as TextureRect
@onready var _ios_texture_rect := %iOSTextureRect as TextureRect

var _active_texture_rect: TextureRect


func _ready() -> void:
	if OS.has_feature("ios"):
		_android_texture_rect.hide()
		_active_texture_rect = _ios_texture_rect
	else:
		_ios_texture_rect.hide()
		_active_texture_rect = _android_texture_rect


func _on_get_status_button_pressed() -> void:
	var __count: int = 0
	var __status_array: Array[ConnectionInfo] = connection_state_node.get_connection_state()
	for __connection_info in __status_array:
		__count += 1
		_print_to_screen(
			(
				"Connection #%d -- type: %s -- is_active: %s -- is_metered: %s"
				% [
					__count,
					ConnectionInfo.ConnectionType.keys()[__connection_info.get_connection_type()],
					str(__connection_info.is_active()),
					str(__connection_info.is_metered())
				]
			)
		)

	_print_to_screen("Total of %d available connections" % __count)


func _on_connection_state_connection_established(a_info: ConnectionInfo) -> void:
	_print_to_screen(
		(
			"Connection established -- type: %s -- is_active: %s -- is_metered: %s"
			% [
				ConnectionInfo.ConnectionType.keys()[a_info.get_connection_type()],
				str(a_info.is_active()),
				str(a_info.is_metered())
			]
		)
	)


func _on_connection_state_connection_lost(a_info: ConnectionInfo) -> void:
	_print_to_screen(
		(
			"Connection lost -- type: %s -- is_active: %s -- is_metered: %s"
			% [
				ConnectionInfo.ConnectionType.keys()[a_info.get_connection_type()],
				str(a_info.is_active()),
				str(a_info.is_metered())
			]
		)
	)


func _print_to_screen(a_message: String, a_is_error: bool = false) -> void:
	if a_is_error:
		_label.push_color(Color.CRIMSON)

	_label.add_text("%s\n\n" % a_message)

	if a_is_error:
		_label.pop()
		printerr("Demo app:: " + a_message)
	else:
		print("Demo app:: " + a_message)

	_label.scroll_to_line(_label.get_line_count() - 1)
