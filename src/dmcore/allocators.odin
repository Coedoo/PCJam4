package dmcore

import "core:math"
import "core:mem"
import "core:fmt"

/// Free List Allocator

FreeListHeader :: struct {
    blockSize: uint,
    padding: uint,
}

FreeListNode :: struct {
    next: ^FreeListNode,
    blockSize: uint,
}

FreeList :: struct {
    data: []u8,
    used: uint,

    head: ^FreeListNode,
}

FreeListFreeAll :: proc(list: ^FreeList) {
    list.used = 0
    list.head = cast(^FreeListNode) raw_data(list.data)
    list.head.blockSize = len(list.data)
    list.head.next = nil
}

FreeListInit :: proc(list: ^FreeList, data: []u8) {
    list.data = data
    FreeListFreeAll(list)
}

CalcPaddingWithHeader :: proc(ptr, aligment: uintptr, headerSize: uint) -> uint {
    modulo := ptr & (aligment - 1) // (ptr % aligment) as it assumes alignment is a power of two

    padding: uintptr
    if modulo != 0 {
        padding = aligment - modulo
    }

    neededSpace := uintptr(headerSize)

    if padding < neededSpace {
        neededSpace -= padding

        if (neededSpace & (aligment - 1)) != 0 {
            padding += aligment * (1 + (neededSpace / aligment))
        }
        else {
            padding += aligment * (neededSpace / aligment)
        }
    }

    return uint(padding)
}

FreeListFindFirst :: proc(list: ^FreeList, size: uint, aligment: uint) -> 
    (node:^FreeListNode, prevNode: ^FreeListNode, padding: uint)
{
    node = list.head

    for node != nil {
        nodePtr := uintptr(rawptr(node))
        padding = CalcPaddingWithHeader(nodePtr, uintptr(aligment), size_of(FreeListHeader))

        requiredSpace := size + padding
        if node.blockSize >= requiredSpace {
            break
        }

        prevNode = node
        node = node.next
    }

    return
}

FreeListAlloc :: proc(list: ^FreeList, size, aligment: uint) -> uintptr {

    aligment := aligment
    if aligment < 8 {
        aligment = 8
    }

    size := size
    if size < size_of(FreeListNode) {
        size = size_of(FreeListNode)
    }

    node, prevNode, padding := FreeListFindFirst(list, size, aligment)
    if node == nil {
        panic("Out of memory")
    }

    aligmentPadding := padding - size_of(FreeListHeader)
    requiredSpace := size + padding
    remaining := node.blockSize - requiredSpace

    nodePtr := uintptr(rawptr(node))

    if remaining > 0 {
        newNode := cast(^FreeListNode) (nodePtr + uintptr(requiredSpace))
        newNode.blockSize = remaining
        FreeListNodeInsert(&list.head, node, newNode)
    }

    FreeListNodeRemove(&list.head, prevNode, node)

    headerPtr := cast(^FreeListHeader)(nodePtr + uintptr(aligmentPadding))
    headerPtr.blockSize = requiredSpace
    headerPtr.padding = aligmentPadding

    list.used += requiredSpace

    return uintptr(rawptr(headerPtr)) + size_of(FreeListHeader)
}

FreeListFree :: proc(list: ^FreeList, ptr: rawptr) {
    if ptr == nil {
        return
    }

    header := cast(^FreeListHeader) (uintptr(ptr) - size_of(FreeListHeader))
    freeNode := cast(^FreeListNode) header
    freeNode.blockSize = header.blockSize + header.padding
    freeNode.next = nil

    prevNode: ^FreeListNode
    node := list.head
    for node != nil {
        // when we find the first next node after the one
        // we just freed, insert new free node between that
        // and the previous one
        if ptr < rawptr(node) {
            FreeListNodeInsert(&list.head, prevNode, freeNode)
            break
        }

        prevNode = node
        node = node.next
    }

    list.used -= freeNode.blockSize
    FreeListCoalescence(list, prevNode, freeNode)
}

FreeListCoalescence :: proc(list: ^FreeList, prevNode, freeNode: ^FreeListNode) {
    if freeNode.next != nil && 
        uintptr(rawptr(freeNode)) + uintptr(freeNode.blockSize) == uintptr(freeNode.next)
    {
        freeNode.blockSize += freeNode.next.blockSize
        FreeListNodeRemove(&list.head, freeNode, freeNode.next)
    }

    if prevNode != nil &&
        prevNode.next != nil && 
        uintptr(rawptr(prevNode)) + uintptr(prevNode.blockSize) == uintptr(freeNode)
    {
        prevNode.blockSize += prevNode.next.blockSize
        FreeListNodeRemove(&list.head, prevNode, freeNode)
    }
}

FreeListNodeInsert :: proc(head: ^^FreeListNode, prevNode, newNode: ^FreeListNode) {
    if prevNode == nil {
        newNode.next = head^
        head^ = newNode
    }
    else {
        if prevNode.next == nil {
            prevNode.next = newNode
            newNode.next = nil
        }
        else {
            newNode.next = prevNode.next
            prevNode.next = newNode
        }
    }
}

FreeListNodeRemove :: proc(head: ^^FreeListNode, prev, deleted: ^FreeListNode) {
    if prev == nil {
        head^ = deleted.next
    }
    else {
        prev.next = deleted.next
    }
}

FreeListAllocator :: proc "contextless" (list: ^FreeList) -> (allocator: mem.Allocator) {
    allocator.procedure = FreeListAllocatorProc
    allocator.data = list
    return
}

FreeListAllocatorProc :: proc(allocatorData: rawptr, mode: mem.Allocator_Mode, 
        size, alignment: int, 
        old_memory: rawptr, old_size: int, 
        location := #caller_location) -> ([]byte, mem.Allocator_Error)
{
    list := cast(^FreeList)allocatorData
    switch mode {
        case .Alloc, .Alloc_Non_Zeroed: {
            memory := FreeListAlloc(list, uint(size), uint(alignment))
            if mode == .Alloc {
                mem.zero(rawptr(memory), size)
            }

            offset := memory - uintptr(raw_data(list.data))
            // fmt.println("Allocating", size, "bytes at", rawptr(offset), "from:", location)
            // fmt.println("Used memory:", list.used, "Free Memory:", uint(len(list.data)) - list.used)
            return ([^]byte)(memory)[:size], .None
        }

        case .Free: {
            // fmt.println("Freeing", size, "bytes at", uintptr(old_memory) - uintptr(raw_data(list.data)))
            FreeListFree(list, old_memory)
            // fmt.println("Used memory:", list.used, "Free Memory:", uint(len(list.data)) - list.used)

            return nil, .None
        }

        case .Free_All: {
            FreeListFreeAll(list)
            return nil, .None
        }

        case .Resize, .Resize_Non_Zeroed: {
            dest := cast(rawptr) FreeListAlloc(list, uint(size), uint(alignment))
            mem.zero(dest, size)
            
            mem.copy(dest, old_memory, old_size)

            FreeListFree(list, old_memory)

            // fmt.println("Resizing. Removed", old_size, "bytes at", old_memory, ". Allocating", size, "at", dest)
            return ([^]byte)(dest)[:size], .None
        }

        case .Query_Features: {
            set := (^mem.Allocator_Mode_Set)(old_memory)
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All, .Query_Features}
            }
            return nil, .None
        }

        case .Query_Info: {
            return nil, .Mode_Not_Implemented
        }
    }

    return nil, nil
}