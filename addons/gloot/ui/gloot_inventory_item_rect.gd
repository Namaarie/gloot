@tool
extends TextureRect

var item: InventoryItem = null
var _label_stack_size: Label = null


func _ready() -> void:
    _label_stack_size = Label.new()
    add_child(_label_stack_size)
    _update_stack_size_label()


func _update_stack_size_label() -> void:
    if _label_stack_size == null:
        return
    _label_stack_size.text = ""

    if item == null:
        return

    var inventory := item.get_inventory()
    if inventory == null:
        return

    var stacks_constraint = inventory._constraint_manager.get_stacks_constraint()
    if stacks_constraint == null:
        return

    var stack_size: int = stacks_constraint.get_item_stack_size(item)
    if stack_size <= 1:
        return
    _label_stack_size.text = str(stack_size)


func _get_drag_data(at_position: Vector2):
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_drag_preview(_get_drag_preview())
    return self


func _get_drag_preview() -> Control:
    var preview = TextureRect.new()
    preview.texture = texture
    preview.size = size
    return preview


func _notification(what) -> void:
    if what == NOTIFICATION_DRAG_END:
        _on_drag_end()
    elif what == NOTIFICATION_DRAG_BEGIN:
        var drag_data = get_viewport().gui_get_drag_data()
        if drag_data == null:
            return
        if drag_data.item == item:
            _on_drag_start()


func _on_drag_start() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    modulate = Color(1.0, 1.0, 1.0, 0.5)


func _on_drag_end() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    modulate = Color.WHITE

