import re

filepath = r"C:\Users\Gabi.WIN-CD45QMUUPFF\Documents\GitHub\Lucky5-v7\godot\cabinet\scripts\cabinet_root.gd"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _ready function - add responsive metrics connection and call
old_ready = """	get_viewport().size_changed.connect(_update_crt_viewport_size)
	_update_crt_viewport_size()
	_create_press_audio_player()"""

new_ready = """	get_viewport().size_changed.connect(_update_crt_viewport_size)
	get_viewport().size_changed.connect(_apply_responsive_metrics)
	_update_crt_viewport_size()
	_apply_responsive_metrics()
	_create_press_audio_player()"""

content = content.replace(old_ready, new_ready)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated _ready function")