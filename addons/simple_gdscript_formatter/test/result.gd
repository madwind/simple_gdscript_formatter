@tool
@icon("/")
@static_unload
extends Node

signal sig

# Enum
enum State {
	IDLE,
	WALKING,
	RUNNING,
}
# Enum
enum State2 { IDLE }
enum SIDE {
	TOP,
	LEFT,
	BOTTOM,
	RIGHT,
	ANY,
}

const _private_const := 2

# Export
@export var example_var := 1

#export range
@export_range(-90.0, 0.0, 0.1, "range")
var _range: float = -PI / 2

# Multiline string
var weird_multiline_str := """ 
abcde \"\"\"""more
text
"""

var weird_colon := 42

# one line
var _my_dictionary = { key = "value" }

@onready var r1 = 2

@onready var _r2 = 1


# Static
static func do_static_thing() -> void:
	pass


func _init() -> void:
	pass


@abstract class AWeirdlyFormattedClass:

	var a = 1


	func block():
		while(
				true
				and false
		):
			pass


	func block2():
		while(
				true
				and false
		):
			pass


	@abstract func abs() -> void


# Test ops: ** << >> == != >= <= && || += -= *= /= %= **= &= ^= |= ~= <<= >>= := -> & | ^ - + / * > < %
func run_all_ops(val1: int, val2: float = 1.0):
	var a = 10
	var b = 5
	var result = 0
#top level comment in func
	var arr = [1, 2, 3]
	if arr[0] != arr[3] and a > -1:
		a = (a + b) / (b - a)
		a = (a + b) / (b - a)
		a = -90
	if true and false:
		pass
	# Arithmetic
	result = a + b
	result = a - b
	result = a * b
	result = a / b
	result = a % b
	result = a ** b

	# Bitwise
	result = a & b
	result = a | b
	result = a ^ b
	result = ~a
	result = a << b
	result = a >> b

	# Comparison
	var eq = a == b
	var neq = a != b
	var gt = a > b
	var lt = a < b
	var gte = a >= b
	var lte = a <= b

	# Logical
	var anded = a > 0 && b > 0
	var ored = a > 0 || b < 0

	# Assignment
	a += b
	a -= b
	a *= b
	a /= b
	a %= b
	a **= b
	a &= b
	a |= b
	a ^= b
	a <<= b
	a >>= b

	# Dictionary
	var d := {
		"hello": "world"
	}

	# func-as-var
	var cb := func() -> void:
		print("callback")

	# Instancing
	var obj = WeirdlyFormattedClass.new()

	# Signal
	sig.emit()


# Return
func get_it() -> int:
	return 123


#func disable():
	#pass
# Match, loops, await, nested func
func test_misc():
	var val := 3
	# if-nesting
	if (
			1 > 0
			and 2 == 2
			and (3 != 4 and 5 < 6)
	):
		pass
	match val:
		1:
			print("one")
		2, 3:
			print("two or three")
		_:
			print("default")

	for i in range(0, 5):
		print(i)

	while val > 0:
		val -= 1
		if val == 2: continue
		if val == 0:
			break

	await get_tree().create_timer(0.1).timeout

	sig.connect(func() -> void:
			sig.connect(func() -> void:
					if (
							1 > 0
							and 2 == 2
							and (3 != 4 and 5 < 6)
					):
						pass
			)
			if true:
				print("inline")
			# if-nesting
			if (
					1 > 0
					and 2 == 2
					and (3 != 4 and 5 < 6)
			):
				pass
			match val:
				1:
					print("one")
				2, 3:
					print("two or three")
				_:
					print("default")
			#unique value
			match val:
				1:
					%abc.enbale = true
				2, 3:
					1 - %abc.num
				_:
					1 % 3 + 1
	)

	# if-nesting
	if (
			1 > 0
			and 2 == 2
			and (3 != 4 and 5 < 6)
	):
		pass


func block():
	while(
			true
			and false
	):
		pass


@warning_ignore("assert_always_false")
class WeirdlyFormattedClass extends AWeirdlyFormattedClass:


	func abs() -> void:
		pass
