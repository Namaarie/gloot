@tool
@icon("res://addons/gloot/images/icon_ctrl_item_slot.svg")
class_name CtrlItemSlot
extends Control
## A control node representing an inventory slot (`ItemSlot`).
##
## A control node representing an inventory slot (`ItemSlot`).


const CtrlDraggableInventoryItem = preload("res://addons/gloot/ui/ctrl_draggable_inventory_item.gd")
const CtrlDropZone = preload("res://addons/gloot/ui/ctrl_drop_zone.gd")
const CtrlDraggable = preload("res://addons/gloot/ui/ctrl_draggable.gd")
const Utils = preload("res://addons/gloot/core/utils.gd")

## Reference to the item slot that is being displayed.
@export var item_slot: ItemSlot :
    set(new_item_slot):
        if new_item_slot == item_slot:
            return

        _disconnect_item_slot_signals()
        item_slot = new_item_slot
        _connect_item_slot_signals()
        
        _refresh()

## If set to `true`, the item icon is displayed.
@export var item_texture_visible: bool = true :
    set(new_item_texture_visible):
        if item_texture_visible == new_item_texture_visible:
            return
        item_texture_visible = new_item_texture_visible
        if is_instance_valid(_ctrl_draggable_inventory_item):
            _ctrl_draggable_inventory_item.visible = item_texture_visible
## If set to `true`, the item name label is displayed.
@export var label_visible: bool = true :
    set(new_label_visible):
        if label_visible == new_label_visible:
            return
        label_visible = new_label_visible
        if is_instance_valid(_label):
            _label.visible = label_visible

@export_group("Icon Behavior", "icon_")
## Controls the item icon behavior when resizing the node's bounding rectangle.
@export var icon_stretch_mode: TextureRect.StretchMode = TextureRect.StretchMode.STRETCH_KEEP_CENTERED :
    set(new_icon_stretch_mode):
        if icon_stretch_mode == new_icon_stretch_mode:
            return
        icon_stretch_mode = new_icon_stretch_mode
        if is_instance_valid(_ctrl_draggable_inventory_item):
            _ctrl_draggable_inventory_item.stretch_mode = icon_stretch_mode

@export_group("Text Behavior", "label_")
## Controls the label's horizontal alignment.
@export var label_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER :
    set(new_label_horizontal_alignment):
        if label_horizontal_alignment == new_label_horizontal_alignment:
            return
        label_horizontal_alignment = new_label_horizontal_alignment
        if is_instance_valid(_label):
            _label.horizontal_alignment = label_horizontal_alignment
## Controls the label's vertical alignment.
@export var label_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER :
    set(new_label_vertical_alignment):
        if label_vertical_alignment == new_label_vertical_alignment:
            return
        label_vertical_alignment = new_label_vertical_alignment
        if is_instance_valid(_label):
            _label.vertical_alignment = label_vertical_alignment
## Sets the clipping behavior when the text exceeds the node's bounding rectangle.
@export var label_text_overrun_behavior: TextServer.OverrunBehavior :
    set(new_label_text_overrun_behavior):
        if label_text_overrun_behavior == new_label_text_overrun_behavior:
            return
        label_text_overrun_behavior = new_label_text_overrun_behavior
        if is_instance_valid(_label):
            _label.text_overrun_behavior = label_text_overrun_behavior
## If `true`, the label only shows the text that fits inside its bounding rectangle and will clip text horizontally.
@export var label_clip_text: bool :
    set(new_label_clip_text):
        if label_clip_text == new_label_clip_text:
            return
        label_clip_text = new_label_clip_text
        if is_instance_valid(_label):
            _label.clip_text = label_clip_text

@export_group("Custom Styles")
## The slot background style.
@export var slot_style: StyleBox :
    set(new_slot_style):
        slot_style = new_slot_style
        _refresh()
## The slot background style when the mouse cursor hovers over the slot.
@export var slot_highlighted_style: StyleBox :
    set(new_slot_highlighted_style):
        slot_highlighted_style = new_slot_highlighted_style
        _refresh()

var _background_panel: Panel
var _hbox_container: HBoxContainer
var _ctrl_draggable_inventory_item: CtrlDraggableInventoryItem
var _label: Label
var _ctrl_drop_zone: CtrlDropZone


func _connect_item_slot_signals() -> void:
    if !is_instance_valid(item_slot):
        return
    Utils.safe_connect(item_slot.item_equipped, _refresh)
    Utils.safe_connect(item_slot.cleared, _refresh)


func _disconnect_item_slot_signals() -> void:
    if !is_instance_valid(item_slot):
        return
    Utils.safe_disconnect(item_slot.item_equipped, _refresh)
    Utils.safe_disconnect(item_slot.cleared, _refresh)


func _ready():
    if Engine.is_editor_hint():
        # Clean up, in case it is duplicated in the editor
        for c in get_children():
            remove_child(c)
            c.queue_free()

    _hbox_container = HBoxContainer.new()
    _hbox_container.size_flags_horizontal = SIZE_EXPAND_FILL
    _hbox_container.size_flags_vertical = SIZE_EXPAND_FILL
    add_child(_hbox_container)
    _hbox_container.resized.connect(func(): size = _hbox_container.size)

    _ctrl_draggable_inventory_item = CtrlDraggableInventoryItem.new()
    _ctrl_draggable_inventory_item.visible = item_texture_visible
    _ctrl_draggable_inventory_item.size_flags_horizontal = SIZE_EXPAND_FILL
    _ctrl_draggable_inventory_item.size_flags_vertical = SIZE_EXPAND_FILL
    _ctrl_draggable_inventory_item.icon_stretch_mode = icon_stretch_mode
    _hbox_container.add_child(_ctrl_draggable_inventory_item)

    _ctrl_drop_zone = CtrlDropZone.new()
    _ctrl_drop_zone.draggable_dropped.connect(_on_draggable_dropped)
    _ctrl_drop_zone.size = size
    resized.connect(func(): _ctrl_drop_zone.size = size)
    CtrlDraggable.draggable_grabbed.connect(_on_any_draggable_grabbed)
    CtrlDraggable.draggable_dropped.connect(_on_any_draggable_dropped)
    add_child(_ctrl_drop_zone)
    _ctrl_drop_zone.deactivate()

    _label = Label.new()
    _label.visible = label_visible
    _label.size_flags_horizontal = SIZE_EXPAND_FILL
    _label.size_flags_vertical = SIZE_EXPAND_FILL
    _label.horizontal_alignment = label_horizontal_alignment
    _label.vertical_alignment = label_vertical_alignment
    _label.text_overrun_behavior = label_text_overrun_behavior
    _label.clip_text = label_clip_text
    _hbox_container.add_child(_label)

    _hbox_container.size = size
    resized.connect(func():
        _hbox_container.size = size
        if is_instance_valid(_background_panel):
            _background_panel.size = size
    )

    _refresh()


func _on_draggable_dropped(draggable: CtrlDraggable, drop_position: Vector2) -> void:
    var item = (draggable.metadata as CtrlDraggableInventoryItem).item

    if !item:
        return
    if !is_instance_valid(item_slot):
        return
        
    if !item_slot.can_hold_item(item):
        return

    if item == item_slot.get_item():
        return

    if _join_stacks(item_slot.get_item(), item):
        return

    if _swap_items(item_slot.get_item(), item):
        return
        
    if item_slot.get_item() == null:
        item_slot.equip(item)


func _join_stacks(item_dst: InventoryItem, item_src: InventoryItem) -> bool:
    if item_dst == null:
        return false
    if !is_instance_valid(item_dst.get_inventory()):
        return false
    return Inventory.merge_stacks(item_dst, item_src)


func _swap_items(item1: InventoryItem, item2: InventoryItem) -> bool:
    if item_slot.get_item() == null:
        return false

    return InventoryItem.swap(item1, item2)


func _on_any_draggable_grabbed(draggable: CtrlDraggable, grab_position: Vector2):
    _ctrl_drop_zone.activate()


func _on_any_draggable_dropped(draggable: CtrlDraggable, zone: CtrlDropZone, drop_position: Vector2):
    _ctrl_drop_zone.deactivate()


func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        _ctrl_drop_zone.deactivate()


func _refresh() -> void:
    _clear()

    _update_background()

    if !is_instance_valid(item_slot):
        return

    var item = item_slot.get_item()
    if !is_instance_valid(item):
        return
        
    if is_instance_valid(_label):
        _label.text = item.get_property(InventoryItem.KEY_NAME, item.get_title())
    if is_instance_valid(_ctrl_draggable_inventory_item):
        _ctrl_draggable_inventory_item.item = item


func _clear() -> void:
    if is_instance_valid(_label):
        _label.text = ""
    if is_instance_valid(_ctrl_draggable_inventory_item):
        _ctrl_draggable_inventory_item.item = null


func _update_background() -> void:
    if !is_instance_valid(_background_panel):
        _background_panel = Panel.new()
        add_child(_background_panel)
        move_child(_background_panel, 0)
        
    _background_panel.size = size
    _background_panel.show()
    if slot_style:
        _set_panel_style(_background_panel, slot_style)
    else:
        _background_panel.hide()


func _set_panel_style(panel: Panel, style: StyleBox) -> void:
    panel.remove_theme_stylebox_override("panel")
    if style != null:
        panel.add_theme_stylebox_override("panel", style)


func _input(event) -> void:
    if event is InputEventMouseMotion:
        if !is_instance_valid(_background_panel):
            return

        if get_global_rect().has_point(get_global_mouse_position()) && slot_highlighted_style:
            _set_panel_style(_background_panel, slot_highlighted_style)
            return
        
        if slot_style:
            _set_panel_style(_background_panel, slot_style)
        else:
            _background_panel.hide()
