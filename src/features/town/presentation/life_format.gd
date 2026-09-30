class_name LifeFormat
extends RefCounted


static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


static func money(value: int) -> String:
	if value >= 1000000:
		return number(floorf(value / 100000.0) / 10.0) + "m"
	if value >= 10000:
		return number(floorf(value / 100.0) / 10.0) + "k"
	return str(value)
