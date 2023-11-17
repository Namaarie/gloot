extends "res://addons/gloot/core/constraints/inventory_constraint.gd"

const WeightConstraint = preload("res://addons/gloot/core/constraints/weight_constraint.gd")
const GridConstraint = preload("res://addons/gloot/core/constraints/grid_constraint.gd")

const KEY_STACK_SIZE: String = "stack_size"
const KEY_MAX_STACK_SIZE: String = "max_stack_size"

const DEFAULT_STACK_SIZE: int = 1
# TODO: Consider making the default max stack size 1
const DEFAULT_MAX_STACK_SIZE: int = 100

enum MergeResult {SUCCESS = 0, FAIL, PARTIAL}


# TODO: Check which util functions can be made private
# TODO: Consider making these util methods work with ItemCount
static func _get_free_stack_space(item: InventoryItem) -> int:
    assert(item != null, "item is null!")
    return get_item_max_stack_size(item) - get_item_stack_size(item)


static func _has_overridden_property(item: InventoryItem, property: String, value) -> bool:
    assert(item != null, "item is null!")
    if !item.is_property_overridden(property):
        return false
    if item.get_property(property) != value:
        return false
    return true


static func get_item_stack_size(item: InventoryItem) -> int:
    assert(item != null, "item is null!")
    return item.get_property(KEY_STACK_SIZE, DEFAULT_STACK_SIZE)


static func get_item_max_stack_size(item: InventoryItem) -> int:
    assert(item != null, "item is null!")
    return item.get_property(KEY_MAX_STACK_SIZE, DEFAULT_MAX_STACK_SIZE)


static func set_item_stack_size(item: InventoryItem, stack_size: int) -> bool:
    assert(item != null, "item is null!")
    assert(stack_size >= 0, "stack_size can't be negative!")
    if stack_size > get_item_max_stack_size(item):
        return false
    if stack_size == 0:
        var inventory: Inventory = item.get_inventory()
        if inventory != null:
            inventory.remove_item(item)
        item.free()
        return true
    item.set_property(KEY_STACK_SIZE, stack_size)
    return true


static func set_item_max_stack_size(item: InventoryItem, max_stack_size: int) -> void:
    assert(item != null, "item is null!")
    assert(max_stack_size > 0, "max_stack_size can't be less than 1!")
    item.set_property(KEY_MAX_STACK_SIZE, max_stack_size)


static func get_prototype_stack_size(protoset: ItemProtoset, prototype_id: String) -> int:
    assert(protoset != null, "protoset is null!")
    return protoset.get_prototype_property(prototype_id, KEY_STACK_SIZE, 1.0)


static func get_prototype_max_stack_size(protoset: ItemProtoset, prototype_id: String) -> int:
    assert(protoset != null, "protoset is null!")
    return protoset.get_prototype_property(prototype_id, KEY_MAX_STACK_SIZE, 1.0)


func get_mergable_items(item: InventoryItem) -> Array[InventoryItem]:
    assert(inventory != null, "Inventory not set!")
    assert(item != null, "item is null!")

    var result: Array[InventoryItem] = []

    for i in inventory.get_items():
        if i == item:
            continue
        if !items_mergable(i, item):
            continue

        result.append(i)
            
    return result


static func items_mergable(item_1: InventoryItem, item_2: InventoryItem) -> bool:
    # Two item stacks are mergable if they have the same prototype ID and neither of the two contain
    # overridden properties that the other one doesn't have (except for "stack_size", "max_stack_size",
    # "grid_position", or "weight").
    assert(item_1 != null, "item_1 is null!")
    assert(item_2 != null, "item_2 is null!")

    var ignore_properies: Array[String] = [
        KEY_STACK_SIZE,
        KEY_MAX_STACK_SIZE,
        WeightConstraint.KEY_WEIGHT
    ]

    if item_1.prototype_id != item_2.prototype_id:
        return false

    for property in item_1.get_overridden_properties():
        if property in ignore_properies:
            continue
        if !_has_overridden_property(item_2, property, item_1.get_property(property)):
            return false

    for property in item_2.get_overridden_properties():
        if property in ignore_properies:
            continue
        if !_has_overridden_property(item_1, property, item_2.get_property(property)):
            return false

    return true


func add_item_automerge(
    item: InventoryItem,
    ignore_properies: Array[String] = []
) -> bool:
    assert(item != null, "Item is null!")
    assert(inventory != null, "Inventory not set!")
    if !inventory._constraint_manager.has_space_for(item):
        return false

    var target_items = get_mergable_items(item)
    for target_item in target_items:
        if _merge_stacks(target_item, item) == MergeResult.SUCCESS:
            return true

    assert(inventory.add_item(item))
    return true


static func _merge_stacks(item_dst: InventoryItem, item_src: InventoryItem) -> int:
    assert(item_dst != null, "item_dst is null!")
    assert(item_src != null, "item_src is null!")

    var src_size: int = get_item_stack_size(item_src)
    assert(src_size > 0, "Item stack size must be greater than 0!")

    var dst_size: int = get_item_stack_size(item_dst)
    var dst_max_size: int = get_item_max_stack_size(item_dst)
    var free_dst_stack_space: int = dst_max_size - dst_size
    if free_dst_stack_space <= 0:
        return MergeResult.FAIL

    assert(set_item_stack_size(item_src, max(src_size - free_dst_stack_space, 0)))
    assert(set_item_stack_size(item_dst, min(dst_size + src_size, dst_max_size)))

    if free_dst_stack_space >= src_size:
        return MergeResult.SUCCESS

    return MergeResult.PARTIAL


static func split_stack(item: InventoryItem, new_stack_size: int) -> InventoryItem:
    assert(item != null, "item is null!")
    assert(new_stack_size >= 1, "New stack size must be greater or equal to 1!")

    var stack_size = get_item_stack_size(item)
    assert(stack_size > 1, "Size of the item stack must be greater than 1!")
    assert(
        new_stack_size < stack_size,
        "New stack size must be smaller than the original stack size!"
    )

    var new_item = item.duplicate()

    assert(set_item_stack_size(new_item, new_stack_size))
    assert(set_item_stack_size(item, stack_size - new_stack_size))
    return new_item


# TODO: Rename this
func split_stack_safe(item: InventoryItem, new_stack_size: int) -> InventoryItem:
    assert(inventory != null, "inventory is null!")
    assert(inventory.has_item(item), "The inventory does not contain the given item!")

    if !_can_split_stack(item, new_stack_size):
        return null

    var new_item = split_stack(item, new_stack_size)
    if new_item:
        assert(inventory.add_item(new_item))
        # Adding an item can result in the item being freed (e.g. when it's merged with another item stack)
        if !is_instance_valid(new_item):
            new_item = null
    return new_item


func _can_split_stack(item: InventoryItem, new_stack_size: int) -> bool:
    # The grid constraint could prevent us from splitting a stack
    var grid_constraint := inventory.get_grid_constraint()
    if grid_constraint:
        var item_size := grid_constraint.get_item_size(item)
        if !grid_constraint.find_free_space(item_size).success:
            return false
    return true


static func join_stacks(
    item_dst: InventoryItem,
    item_src: InventoryItem
) -> bool:
    if item_dst == null || item_src == null:
        return false

    if (!stacks_joinable(item_dst, item_src)):
        return false

    # TODO: Check if this can be an assertion
    _merge_stacks(item_dst, item_src)
    return true


static func stacks_joinable(
    item_dst: InventoryItem,
    item_src: InventoryItem
) -> bool:
    assert(item_dst != null, "item_dst is null!")
    assert(item_src != null, "item_src is null!")

    if not items_mergable(item_dst, item_src):
        return false

    var dst_free_space = _get_free_stack_space(item_dst)
    if dst_free_space < get_item_stack_size(item_src):
        return false

    return true


func join_stacks_autosplit(
    item_dst: InventoryItem,
    item_src: InventoryItem
) -> bool:
    assert(inventory != null, "inventory is null!")
    assert(item_dst != null, "item_dst is null!")
    assert(item_src != null, "item_src is null!")

    if not items_mergable(item_dst, item_src):
        return false

    var old_stack_size := get_item_stack_size(item_dst)
    _merge_stacks(item_dst, item_src)
    return old_stack_size != get_item_stack_size(item_dst)


func get_space_for(item: InventoryItem) -> ItemCount:
    return ItemCount.inf()


func has_space_for(item: InventoryItem) -> bool:
    return true


func get_free_stack_space_for(item: InventoryItem) -> ItemCount:
    assert(inventory != null, "Inventory not set!")

    var item_count = ItemCount.zero()
    var mergable_items = get_mergable_items(item)
    for mergable_item in mergable_items:
        var free_stack_space := _get_free_stack_space(mergable_item)
        item_count.add(ItemCount.new(free_stack_space))
    return item_count


func pack_item(item: InventoryItem) -> void:
    var free_stack_space := get_free_stack_space_for(item)
    if free_stack_space.eq(ItemCount.zero()):
        return
    var stacks_size := ItemCount.new(get_item_stack_size(item))
    if stacks_size.gt(free_stack_space):
        item = split_stack(item, free_stack_space.count)

    var mergable_items = get_mergable_items(item)
    for mergable_item in mergable_items:
        var merge_result := _merge_stacks(mergable_item, item)
        if merge_result == MergeResult.SUCCESS:
            return


class TransferAutosplitResult:
    var success: bool = false
    var new_item: InventoryItem = null

    func _init(success_: bool, new_item_: InventoryItem):
        success = success_
        new_item = new_item_


func transfer_autosplit(item: InventoryItem, destination: Inventory) -> TransferAutosplitResult:
    assert(inventory._constraint_manager.get_configuration() == destination._constraint_manager.get_configuration())
    if inventory.transfer(item, destination):
        if is_instance_valid(item):
            return TransferAutosplitResult.new(true, item)
        else:
            return TransferAutosplitResult.new(true, null)


    var stack_size := get_item_stack_size(item)
    if stack_size <= 1:
        return TransferAutosplitResult.new(false, null)

    var item_count := _get_space_for_single_item(destination, item)
    assert(!item_count.eq(ItemCount.inf()), "Item count shouldn't be infinite!")
    var count = item_count.count

    if count <= 0:
        return TransferAutosplitResult.new(false, null)

    var new_item: InventoryItem = split_stack(item, count)
    assert(new_item != null)
    assert(destination.add_item(new_item))
    if is_instance_valid(new_item):
        return TransferAutosplitResult.new(true, new_item)
    else:
        return TransferAutosplitResult.new(true, null)


func _get_space_for_single_item(inventory: Inventory, item: InventoryItem) -> ItemCount:
    var single_item: InventoryItem = item.duplicate()
    assert(set_item_stack_size(single_item, 1))
    var count := inventory._constraint_manager.get_space_for(single_item)
    single_item.free()
    return count


func transfer_autosplitmerge(item: InventoryItem, destination: Inventory) -> bool:
    assert(inventory._constraint_manager.get_configuration() == destination._constraint_manager.get_configuration())
    var transfer_autosplit_result := transfer_autosplit(item, destination)
    if !transfer_autosplit_result.success:
        return false
    if transfer_autosplit_result.new_item:
        destination.get_stacks_constraint().pack_item(transfer_autosplit_result.new_item)
    return true


func transfer_automerge(item: InventoryItem, destination: Inventory) -> bool:
    assert(inventory._constraint_manager.get_configuration() == destination._constraint_manager.get_configuration())
    if inventory.transfer(item, destination):
        # Item could have been packed already
        if item == null:
            return true
        destination.get_stacks_constraint().pack_item(item)
        return true
    return false

