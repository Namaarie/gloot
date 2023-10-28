@tool
extends Control

const GlootInventoryFieldGrid = preload("res://addons/gloot/ui/gloot_inventory_field_grid.gd")
const GlootInventoryItemRect = preload("res://addons/gloot/ui/gloot_inventory_item_rect.gd")

@export var inventory_path: NodePath :
    get:
        return inventory_path
    set(new_inv_path):
        inventory_path = new_inv_path
        inventory = get_node_or_null(inventory_path)

@export var field_grid_path: NodePath :
    get:
        return field_grid_path
    set(new_field_grid_path):
        field_grid_path = new_field_grid_path
        field_grid = get_node_or_null(field_grid_path)

var inventory: Inventory = null :
    get:
        return inventory
    set(new_inventory):
        if inventory == new_inventory:
            return

        if new_inventory == null:
            _disconnect_inventory_signals()
            inventory = null
            _clear()
            return

        inventory = new_inventory
        if inventory.is_node_ready():
            _refresh()
        _connect_inventory_signals()

var field_grid: GlootInventoryFieldGrid = null :
    get:
        return field_grid
    set(new_field_grid):
        if field_grid == new_field_grid:
            return

        if new_field_grid == null:
            field_grid.sort_children.disconnect(_update_item_rects)
            field_grid = null
            _clear()
            return

        field_grid = new_field_grid
        field_grid.sort_children.connect(_update_item_rects)
        _refresh()


@export var selection_style: StyleBox :
    get:
        return selection_style
    set(new_selection_style):
        selection_style = new_selection_style
        for gloot_inventory_item_rect in get_children():
            gloot_inventory_item_rect.selection_style = selection_style


var _selected_item_rect: GlootInventoryItemRect = null


func _connect_inventory_signals() -> void:
    if !inventory.is_node_ready():
        inventory.ready.connect(_refresh)
    inventory.contents_changed.connect(_refresh)
    inventory.protoset_changed.connect(_refresh)
    inventory.item_modified.connect(_on_item_modified)


func _disconnect_inventory_signals() -> void:
    if inventory.ready.is_connected(_refresh):
        inventory.ready.disconnect(_refresh)
    inventory.contents_changed.disconnect(_refresh)
    inventory.protoset_changed.disconnect(_refresh)
    inventory.item_modified.disconnect(_on_item_modified)


func _on_item_modified(item_: InventoryItem) -> void:
    _refresh()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if !inventory_path.is_empty():
        inventory = get_node_or_null(inventory_path)
    if !field_grid_path.is_empty():
        field_grid = get_node_or_null(field_grid_path)
    _refresh()

        
func _refresh() -> void:
    var selected_item := _selected_item()
    _clear()
    _populate(selected_item)


func _selected_item() -> InventoryItem:
    if inventory == null:
        return null
    if _selected_item_rect == null:
        return null
    if !is_instance_valid(_selected_item_rect.item):
        return null

    return _selected_item_rect.item


func _clear() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    custom_minimum_size = Vector2.ZERO


func _populate(selected_item: InventoryItem) -> void:
    if inventory == null || !inventory.is_node_ready() || field_grid == null:
        return

    var grid_constraint := inventory._constraint_manager.get_grid_constraint()
    if grid_constraint == null:
        return

    for item in inventory.get_items():
        var item_rect = _get_item_ui_rect(item)
        var gloot_inventory_item_rect := GlootInventoryItemRect.new()
        gloot_inventory_item_rect.position = item_rect.position
        gloot_inventory_item_rect.size = item_rect.size
        gloot_inventory_item_rect.texture = item.get_texture()
        gloot_inventory_item_rect.selection_style = selection_style
        gloot_inventory_item_rect.item = item
        gloot_inventory_item_rect.selected_status_changed.connect(_on_selected_status_changed.bind(gloot_inventory_item_rect))
        gloot_inventory_item_rect.selected = (item == selected_item)

        add_child(gloot_inventory_item_rect)

    custom_minimum_size = field_grid.size


func _on_selected_status_changed(gloot_inventory_item_rect: GlootInventoryItemRect) -> void:
    if gloot_inventory_item_rect.selected && (_selected_item_rect != null):
        _selected_item_rect.selected = false
    _selected_item_rect = gloot_inventory_item_rect


func get_selected_item() -> InventoryItem:
    if _selected_item_rect == null:
        return null
    return _selected_item_rect.item


func _update_item_rects() -> void:
    if inventory == null || !inventory.is_node_ready() || field_grid == null:
        return

    assert(inventory.get_item_count() == get_child_count())
    for item_index in range(inventory.get_items().size()):
        var item = inventory.get_items()[item_index]
        var item_rect = _get_item_ui_rect(item)
        var texture_rect = get_child(item_index)
        texture_rect.position = item_rect.position
        texture_rect.size = item_rect.size

    custom_minimum_size = field_grid.size


func _get_item_ui_rect(item: InventoryItem) -> Rect2:
    var grid_constraint := inventory._constraint_manager.get_grid_constraint()
    
    var item_field_rect := grid_constraint.get_item_rect(item)
    var top_left := field_grid.get_field_position(item_field_rect.position)
    var bottom_right := field_grid.get_field_position(item_field_rect.position + item_field_rect.size - Vector2i.ONE)
    bottom_right += field_grid.field_size

    return Rect2(top_left, bottom_right - top_left)
