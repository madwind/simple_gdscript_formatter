extends RefCounted

var trace: Array[int] = []
var second = record(2)
var first = record(1)
var property: int = 0:
    set(value):
        property = value + 1
    get:
        return property

enum State { IDLE, RUNNING, DONE }

class Inner:
    var value: int = 3
    func read() -> int:
        return value

func record(value: int) -> int:
    trace.append(value)
    return value

func evaluate() -> Array:
    var callbacks := [func(): return 1, func(): return 2]
    var outer := func(value: int):
        var inner := func(other: int):
            if other > 1:
                return other * 2
            return 0
        return inner.call(value)
    var grouped_callbacks := [
        func(value: int):
            return value + 1,
        func(value: int):
            return value * 2,
    ]
    var callback_map := {"run": func():
        return 7
    }
    var data: Dictionary[String, Array] = {"values": [1, 2, 3]}
    var total := 0
    for item: int in data["values"]:
        match item:
            1, 2 when item > 0:
                total += item
            _:
                total += 10
    while total < 15:
        total += 1
    property = 4
    var multiline := """first
  # literal content
last"""
    var continued := 1 + \
        2
    return [trace, outer.call(3), callbacks[0].call(), callbacks[1].call(),
        total, property, Inner.new().read(), data, multiline, continued,
        -2 ** 2, 2 ** 3 ** 2, not 1 in [2], 1 if true else 2, &"name", ^"../Node",
        grouped_callbacks[0].call(3), grouped_callbacks[1].call(3), callback_map["run"].call()]
