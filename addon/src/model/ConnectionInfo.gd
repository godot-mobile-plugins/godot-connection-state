#
# © 2025-present https://github.com/cengiz-pz
#

class_name ConnectionInfo extends RefCounted


# Connection Type Enums (Shared across platforms)
enum ConnectionType {
	UNKNOWN = 0,
	WIFI = 1,
	CELLULAR = 2,
	ETHERNET = 3,
	BLUETOOTH = 4,
	VPN = 5,
	LOOPBACK = 6
}

const CONNECTION_TYPE_PROPERTY: String = "connection_type"
const IS_ACTIVE_PROPERTY: String = "is_active"
const IS_METERED_PROPERTY: String = "is_metered"

var _data: Dictionary


func _init(a_data: Dictionary):
	_data = a_data


func get_connection_type() -> ConnectionType:
	return _data[CONNECTION_TYPE_PROPERTY] as ConnectionType if _data.has(CONNECTION_TYPE_PROPERTY) \
			else ConnectionType.UNKNOWN


func is_active() -> bool:
	return _data[IS_ACTIVE_PROPERTY] if _data.has(IS_ACTIVE_PROPERTY) else false


func is_metered() -> bool:
	return _data[IS_METERED_PROPERTY] if _data.has(IS_METERED_PROPERTY) else false
