#import <Cocoa/Cocoa.h>

// Don't ask, just trust me on this one
void focusWindow() {
	NSWindow *window = [NSApp mainWindow];
	[window setLevel:NSPopUpMenuWindowLevel];
	[window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient];
	// [window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}

void setupWindow() {
	NSWindow *window = [NSApp mainWindow];
	[window setLevel:NSFloatingWindowLevel];
	[window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient];
	[NSApp activateIgnoringOtherApps:YES];
}

void setupWindow2() {
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

void loseFocus() {
	NSWindow *window = [NSApp mainWindow];
	[window setLevel:NSFloatingWindowLevel];
	[window orderOut:nil];
	[window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient];
	[[NSApplication sharedApplication] hide:nil];
}