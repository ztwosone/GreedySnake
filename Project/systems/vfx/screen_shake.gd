class_name ScreenShake
extends Node

## 屏幕震动管理器。挂载到 GameWorld，提供通用震动接口。

var _camera: Camera2D
var _shake_tween: Tween


func setup(cam: Camera2D) -> void:
	_camera = cam


func shake(intensity: float, duration: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var original_offset: Vector2 = Vector2.ZERO
	_shake_tween = create_tween()
	var steps: int = int(duration / 0.03)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		_shake_tween.tween_property(_camera, "offset", offset, 0.03)
	_shake_tween.tween_property(_camera, "offset", original_offset, 0.03)
