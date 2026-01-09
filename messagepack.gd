class_name Messagepack
## Messagepack implementation for Godot 4 in GDScript
##
## You can find the full spec at: https://github.com/msgpack/msgpack/blob/master/spec.md

const FIRST3 = 0xe0
const FIRST4 = 0xf0
const LAST4 = 0x0f
const LAST5 = 0x1f

const types = {
	"nil": 0xc0,
	"false": 0xc2,
	"true": 0xc3,
	"positive_fixint": [0x00, 0x7f],
	"negative_fixint": [0xe0, 0xff],
	"uint_8": 0xcc,
	"uint_16": 0xcd,
	"uint_32": 0xce,
	"uint_64": 0xcf,
	"int_8": 0xd0,
	"int_16": 0xd1,
	"int_32": 0xd2,
	"int_64": 0xd3,
	"float_32": 0xca,
	"float_64": 0xcb,
	"fixstr": [0xa0, 0xbf],
	"str_8": 0xd9,
	"str_16": 0xda,
	"str_32": 0xdb,
	"fixarray": [0x90, 0x9f],
	"array_16": 0xdc,
	"array_32": 0xdd,
	"fixmap": [0x80, 0x8f],
	"map_16": 0xde,
	"map_32": 0xdf,
	"bin_8": 0xc4,
	"bin_16": 0xc5,
	"bin_32": 0xc6
}

## This function takes a Variant and encodes it according to the Messagepack spec
##
## Parameters:
##   - value: Variant to be encoded
##
## Returns:
##   A dictionary containing the status of the encoding and the value as a PackedByteArray
static func encode(value) -> Dictionary:
	var buffer = StreamPeerBuffer.new()
	buffer.set_big_endian(true)
	var err = _encode_message(buffer, value)
	return {
		value = buffer.data_array,
		status = err
	}

static func _encode_message(buffer: StreamPeerBuffer, value):
	match typeof(value):
		TYPE_NIL:
			buffer.put_u8(types["nil"])

		TYPE_BOOL:
			if value == true:
				buffer.put_u8(types["true"])
			else:
				buffer.put_u8(types["false"])

		TYPE_INT:
			if - (1 << 5) <= value and value <= (1 << 7) - 1:
				buffer.put_8(value)
			elif - (1 << 7) <= value and value <= (1 << 7):
				buffer.put_u8(types["int_8"])
				buffer.put_8(value)
			elif 0 <= value and value <= (1 << 8) - 1:
				buffer.put_u8(types["uint_8"])
				buffer.put_u8(value)
			elif - (1 << 15) <= value and value <= (1 << 15):
				buffer.put_u8(types["int_16"])
				buffer.put_16(value)
			elif 0 <= value and value <= (1 << 16) - 1:
				buffer.put_u8(types["uint_16"])
				buffer.put_u16(value)
			elif - (1 << 31) <= value and value <= (1 << 31):
				buffer.put_u8(types["int_32"])
				buffer.put_32(value)
			elif 0 <= value and value <= (1 << 32) - 1:
				buffer.put_u8(types["uint_32"])
				buffer.put_u32(value)
			elif - (1 << 63) <= value and value <= (1 << 63):
				buffer.put_u8(types["int_64"])
				buffer.put_64(value)
			else:
				buffer.put_u8(types["uint_64"])
				buffer.put_u64(value)

		TYPE_FLOAT:
			buffer.put_u8(types["float_32"])
			buffer.put_float(value)

		TYPE_STRING:
			var bytes = value.to_utf8_buffer()
			var size = bytes.size()
			if size <= (1 << 5) - 1:
				buffer.put_u8(types["fixstr"][0]|size)
			elif size <= (1 << 8) - 1:
				buffer.put_u8(types["str_8"])
				buffer.put_u8(size)
			elif size <= (1 << 16) - 1:
				buffer.put_u8(types["str_16"])
				buffer.put_u16(size)
			elif size <= (1 << 32) - 1:
				buffer.put_u8(types["str_32"])
				buffer.put_u32(size)
			else:
				printerr("Unsupported string: string is too big")
				return ERR_INVALID_DATA

			buffer.put_data(bytes)

		TYPE_ARRAY:
			var size = value.size()
			if size <= 15:
				buffer.put_u8(types["fixarray"][0]|size)
			elif size <= (1 << 16) - 1:
				buffer.put_u8(types["array_16"])
				buffer.put_u16(size)
			elif size <= (1 << 32) - 1:
				buffer.put_u8(types["array_32"])
				buffer.put_u32(size)
			else:
				printerr("Unsupported array: array is too long")
				return ERR_INVALID_DATA
			
			for obj in value:
				_encode_message(buffer, obj)

		TYPE_DICTIONARY:
			var size = value.size()
			if size <= 15:
				buffer.put_u8(types["fixmap"][0]|size)
			elif size <= (1 << 16) - 1:
				buffer.put_u8(types["map_16"])
				buffer.put_u16(size)
			elif size <= (1 << 32) - 1:
				buffer.put_u8(types["map_32"])
				buffer.put_u32(size)
			else:
				printerr("Unsupported dictionary: dictionary is too big")
				return ERR_INVALID_DATA
			
			for key in value:
				_encode_message(buffer, key)
				_encode_message(buffer, value[key])
		
		TYPE_PACKED_BYTE_ARRAY:
			var size = value.size()
			if size <= (1 << 8) - 1:
				buffer.put_u8(types["bin_8"])
				buffer.put_u8(size)
			elif size <= (1 << 16) - 1:
				buffer.put_u8(types["bin_16"])
				buffer.put_u16(size)
			elif size <= (1 << 32) - 1:
				buffer.put_u8(types["bin_32"])
				buffer.put_u32(size)
			else:
				printerr("Unsupported packed byte array: packed byte array is too big")
				return ERR_INVALID_DATA
			
			buffer.put_data(value)

		_:
			printerr("Unsupported data type: %s" % typeof(value))
			return ERR_UNAVAILABLE


## This function takes a PackedByteArray and decodes it according to the Messagepack spec
##
## Parameters:
##   - bytes: PackedByteArray to be decoded
##
## Returns:
##   A dictionary containing the status of the decoding and the value as Godot Variants
static func decode(bytes: PackedByteArray):
	var buffer = StreamPeerBuffer.new()
	buffer.set_big_endian(true)
	buffer.set_data_array(bytes)
	
	var err = {
		error = null
	}
	var message = _decode_message(buffer, err)
	return {
		value = message,
		status = err.error
	}

static func _decode_message(buffer: StreamPeerBuffer, err: Dictionary):
	var buffer_size = buffer.get_size()
	var first_byte = buffer.get_u8()
	
	if first_byte & 0x80 == 0: # positive fixint
		return first_byte
		
	elif first_byte & FIRST4 == 0x80: # fixmap
		var size = first_byte & 0x0f
		var dict = {}
		for _x in range(size):
			var key = _decode_message(buffer, err)
			var val = _decode_message(buffer, err)
			dict[key] = val
		return dict
			
	elif first_byte & FIRST4 == 0x90: # fixarray
		var size = first_byte & 0x0f
		var array = []
		for _x in range(size):
			var val = _decode_message(buffer, err)
			array.append(val)
		return array
		
	elif first_byte & FIRST3 == 0xa0: # fixstr
		var size = first_byte & 0x1f
		return buffer.get_utf8_string(size)
		
	elif first_byte == types["nil"]: # nil
		print("null size:%s"%buffer_size)
		return null
		
	elif first_byte == types["false"]: # false
		print("false size:%s"%buffer_size)		
		return false
		
	elif first_byte == types["true"]: # true
		return true
		
	elif first_byte == types["bin_8"]: # bin 8
		var length = buffer.get_u8()
		return buffer.get_partial_data(length)
		
	elif first_byte == types["bin_16"]: # bin 16
		var length = buffer.get_u16()
		return buffer.get_partial_data(length)
		
	elif first_byte == types["bin_32"]: # bin 32
		var length = buffer.get_u32()
		return buffer.get_partial_data(length)
		
	elif first_byte == 0xc7: # ext 8
		print("Ext 8 type not implemented")
		return null

	elif first_byte == 0xc8: # ext 16
		print("Ext 16 type not implemented")
		return null

	elif first_byte == 0xc9: # ext 32
		print("Ext 32 type not implemented")
		return null
		
	elif first_byte == types["float_32"]: # float 32
		return buffer.get_float()
		
	elif first_byte == types["float_64"]: # float 64
		return buffer.get_double()
		
	elif first_byte == types["uint_8"]: # uint 8
		return buffer.get_u8()
		
	elif first_byte == types["uint_16"]: # uint 16
		return buffer.get_u16()
		
	elif first_byte == types["uint_32"]: # uint 32
		return buffer.get_u32()
		
	elif first_byte == types["uint_64"]: # uint 64
		return buffer.get_u64()
		
	elif first_byte == types["int_8"]: # int 8
		return buffer.get_8()
		
	elif first_byte == types["int_16"]: # int 16
		return buffer.get_16()
		
	elif first_byte == types["int_32"]: # int 32
		return buffer.get_32()
		
	elif first_byte == types["int_64"]: # int 64
		return buffer.get_64()
		
	elif first_byte == 0xd4: # fixext 1
		print("Fixext 1 type not implemented")
		err.error = ERR_UNAVAILABLE
		return null

	elif first_byte == 0xd5: # fixext 2
		print("Fixext 2 type not implemented")
		err.error = ERR_UNAVAILABLE
		return null

	elif first_byte == 0xd6: # fixext 4
		print("Fixext 4 type not implemented")
		err.error = ERR_UNAVAILABLE
		return null

	elif first_byte == 0xd7: # fixext 8
		print("Fixext 8 type not implemented")
		err.error = ERR_UNAVAILABLE
		return null

	elif first_byte == 0xd8: # fixext 16
		print("Fixext 16 type not implemented")
		err.error = ERR_UNAVAILABLE
		return null
		
	elif first_byte == types["str_8"]: # str 8
		var size = buffer.get_u8()
		return buffer.get_utf8_string(size)
		
	elif first_byte == types["str_16"]: # str 16
		var size = buffer.get_u16()
		return buffer.get_utf8_string(size)
		
	elif first_byte == types["str_32"]: # str 32
		var size = buffer.get_u32()
		return buffer.get_utf8_string(size)
		
	elif first_byte == types["array_16"]: # array 16
		var length = buffer.get_u16()
		var array = []
		for _x in range(length):
			var val = _decode_message(buffer, err)
			array.append(val)
		return array
		
	elif first_byte == types["array_32"]: # array 32
		var length = buffer.get_u32()
		var array = []
		for _x in range(length):
			var val = _decode_message(buffer, err)
			array.append(val)
		return array
		
	elif first_byte == types["map_16"]: # map 16
		var length = buffer.get_u16()
		var dict = {}
		for _x in range(length):
			var key = _decode_message(buffer, err)
			var val = _decode_message(buffer, err)
			dict[key] = val
		return dict
		
	elif first_byte == types["map_32"]: # map 32
		var length = buffer.get_u32()
		var dict = {}
		for _x in range(length):
			var key = _decode_message(buffer, err)
			var val = _decode_message(buffer, err)
			dict[key] = val
		return dict
		
	elif first_byte & FIRST3 == 0xe0: # negative fixint
		return first_byte - 256
	else:
		printerr("Unknown header")
		err.error = ERR_UNAVAILABLE
		return null
