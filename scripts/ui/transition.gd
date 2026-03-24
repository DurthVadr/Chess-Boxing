extends CanvasLayer

## Scene transition overlay with fade effect

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Start transparent
	color_rect.color = Color(0, 0, 0, 0)

func fade_out(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.3) -> void:
	color_rect.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
