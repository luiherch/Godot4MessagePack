<p align="center">
    <img width="128" height="128" src="GodotMessagePackIcon.png">
</p>

# Godot 4 MessagePack implementation

MessagePack is a binary serialization format. Similar to JSON but lighter and faster. You can read the specification [here](https://github.com/msgpack/msgpack/blob/master/spec.md).

`messagepack.gd` contains an implementation of the spec written in pure GDScript for Godot 4.

## Installation

Copy the `messagepack.gd` file into your project to start using it with the `Messagepack` class.

## Usage

The `Messagepack` class contains two main static methods for serialization: `encode` and `decode`:

#### `encode(variant: Variant) -> Dictionary`
Converts a Godot Variant into MessagePack binary format.

**Returns**:

A dictionary with:
- `status (bool)`: `true` if successful, `false` on error
- `value (PackedByteArray)`: Encoded binary data


#### `decode(data: PackedByteArray) -> Dictionary`
Converts MessagePack binary data back into Godot Variants.

**Returns**:

A dictionary with:
- `status (bool)`: `true` if successful, `false` on error
- `value (Variant)`: Decoded data

### Example

Both methods are static so you can simply call them with `Messagepack.encode()` and `Messagepack.decode()`.

```gdscript
# Encoding
var to_encode = {
    "hp": 200,
    "speed": 8.5,
    "is_invincible": false,
    "actions": ["jump","dash","attack"]
}
var encoded = Messagepack.encode(to_encode)
if encoded.status != null: # Check for status to verify encoding issues
    printerr(encoded.status)
else:
    print(encoded.value)

# Decoding
var to_decode = encoded.value
var decoded = Messagepack.decode(to_decode)
if decoded.status != null: # Check for status to verify decoding issues
    printerr(decoded.status)
else:
    print(decoded.value)
```

## Acknowledgements & Attribution

This implementation is based on the work by [xtpor](https://github.com/xtpor/godot-msgpack).

The project is distributed under the [MIT license](./LICENSE).
