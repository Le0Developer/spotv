module main

#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#flag -framework CoreFoundation -framework CoreGraphics

type C.kCGEventKeyDown = int

fn C.CGEventMaskBit(int) int
fn C.CGEventTapCreate(int, int, int, int, voidptr, voidptr) voidptr
fn C.CGEventTapEnable(voidptr, bool)

type C.kCGSessionEventTap = int
type C.kCGHeadInsertEventTap = int
type C.kCGEventTapOptionDefault = int

type C.CGEventRef = voidptr
type C.CGEventTapProxy = voidptr
type C.CGEventType = int

type C.kCGKeyboardEventKeycode = int

fn C.CGEventGetIntegerValueField(event C.CGEventRef, field int) int
fn C.CGEventGetFlags(event C.CGEventRef) int

type C.kCGEventFlagMaskCommand = int
type C.kCGEventFlagMaskControl = int
type C.kVK_Space = int
type C.kVK_Tab = int

fn event_callback(proxy C.CGEventTapProxy, typ C.CGEventType, event C.CGEventRef, refcon voidptr) C.CGEventRef {
	if typ == C.kCGEventKeyDown {
		key_code := C.CGEventGetIntegerValueField(event, C.kCGKeyboardEventKeycode)
		flags := C.CGEventGetFlags(event)
		// println('Event captured: ${int(typ)} Keycode: ${key_code} Flags: ${flags}')

		mut app := unsafe { &App(refcon) }
		cmd_pressed := (flags & C.kCGEventFlagMaskCommand) != 0
		// cmd_pressed := (flags & C.kCGEventFlagMaskControl) != 0
		if cmd_pressed {
			match key_code {
				C.kVK_Space {
					app.was_hotkey_pressed = true
				}
				C.kVK_Tab {
					app.should_hide = true
				}
				else {}
			}
		}
	} else {
		println('Other event type: ${int(typ)}')
	}

	return event
}

fn register_callback(app &App) ?voidptr {
	event_mask := C.CGEventMaskBit(C.kCGEventKeyDown)
	event_tap := C.CGEventTapCreate(C.kCGSessionEventTap, C.kCGHeadInsertEventTap, C.kCGEventTapOptionDefault,
		event_mask, event_callback, app)

	if event_tap == 0 {
		return none
	}

	C.CGEventTapEnable(event_tap, true)
	return event_tap
}

fn C.CFMachPortCreateRunLoopSource(voidptr, voidptr, int) voidptr
fn C.CFRunLoopGetCurrent() voidptr
fn C.CFRunLoopAddSource(voidptr, voidptr, voidptr)
fn C.CFRunLoopRun()

type C.kCFRunLoopCommonModes = int

fn run_event_loop(event_tap voidptr) {
	run_loop_source := C.CFMachPortCreateRunLoopSource(0, event_tap, 0)
	run_loop := C.CFRunLoopGetCurrent()
	C.CFRunLoopAddSource(run_loop, run_loop_source, C.kCFRunLoopCommonModes)
	C.CFRunLoopRun()
}
