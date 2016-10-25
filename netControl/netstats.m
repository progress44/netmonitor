//
//  NSObject+netstats.m
//  netControl
//
//  Created by Ani Sinanaj on 03/10/16.
//  Copyright © 2016 Ani Sinanaj. All rights reserved.
//

#import "netstats.h"

@implementation NetStats

@synthesize started;
@synthesize starter;
@synthesize sources;

extern void *kNStatSrcKeyPID;
extern void *kNStatSrcKeyTxBytes;
extern void *kNStatSrcKeyRxBytes;

void *NStatManagerCreate(CFAllocatorRef allocator, dispatch_queue_t queue, void (^)(void *));
void NStatManagerDestroy(void *manager);

void NStatSourceSetRemovedBlock(void *source, void (^)());
void NStatSourceSetCountsBlock(void *source, void (^)(CFDictionaryRef));
void NStatSourceSetDescriptionBlock(void *source, void (^)(CFDictionaryRef));

void NStatSourceQueryDescription(void *source);
void NStatManagerQueryAllSources(void *manager, void (^)());

void NStatManagerAddAllTCP(void *manager);
void NStatManagerAddAllUDP(void *manager);

dispatch_queue_t queue;
dispatch_source_t timer;
__weak SourceRecord *prev_source;
void *manager;

- (void) monitor {
    
    // block functions
    
    // 1. managerCallback
    void (^managerCallback)(void *source) = ^(void *source) {
        // binding source to a SourceRecord object
        SourceRecord *source2 = [[SourceRecord alloc] initWithSource:source];
        long source_index;
        [SourceRecord findBySource:source within:sources atIndex:&source_index];
        [sources insertObject:source2 atIndex:source_index];
        
        
        // setting source description
        NStatSourceSetDescriptionBlock(source, ^(CFDictionaryRef desc) {
            SourceRecord *source2;
            
            if (prev_source != nil && prev_source.next != nil && prev_source.next.source == source) {
                source2 = prev_source.next;
            } else {
                long source_index;
                source2 = [SourceRecord findBySource:source within:sources atIndex:&source_index];
                if (prev_source != nil) prev_source.next = source2;
            }
            
            if (source2 != nil) {
                prev_source = source2;
                source2.pid = (pid_t)[(NSNumber *)CFDictionaryGetValue(desc, kNStatSrcKeyPID) integerValue];
            }
        }); //end source description
        
        // updating sources when one is removed from NStat
        NStatSourceSetRemovedBlock(source, ^() {
            long source_index;
            SourceRecord *source2 = [SourceRecord findBySource:source within:sources atIndex:&source_index];
            if (source2 != nil) {
                source2.next = nil;
                prev_source = nil;
                [sources removeObjectAtIndex:source_index];
            }
        });
        
        // the most interesting part now
        NStatSourceSetCountsBlock(source, ^(CFDictionaryRef desc) {
            SourceRecord *source2;
            
            // setting source2
            if (prev_source != nil && prev_source.next != nil && prev_source.next.source == source) {
                source2 = prev_source.next;
            } else {
                long source_index;
                source2 = [SourceRecord findBySource:source within:sources atIndex:&source_index];
                if (prev_source != nil) prev_source.next = source2;
            }
            
            // return if source2 is nil
            if (!(source2 != nil)) return;
            
            // returning if pid is not set (0) after querying description
            if (source2.pid == 0) {
                NStatSourceQueryDescription(source);
                return;
            }
            
            // getting download and upload values
            long up = [(NSNumber *)CFDictionaryGetValue(desc, kNStatSrcKeyTxBytes) integerValue];
            long down = [(NSNumber *)CFDictionaryGetValue(desc, kNStatSrcKeyRxBytes) integerValue];
            
            // getting app data - Making use of "Loading" classe AppRecord (same goes for SourceRecord)
            // AppRecord *app = nil;
            
            
            printf("\n\nDownload / upload finally %ld / %ld \n", up, down);
            
            
        });
        
        
        //printf("\nLogging network %d - %ld, %ld", source2.pid, source2.up, source2.down);
    };
    
    
    
    // continue with procedural code
    
    if (manager != nil) {
        NSLog(@"Event listener failed. Restarting...");
        NStatManagerDestroy(manager);
    }
    
    if (sources == nil) sources = [[NSMutableArray alloc] initWithCapacity:0];
    
    manager = NStatManagerCreate(kCFAllocatorDefault, queue, managerCallback);
    NStatManagerAddAllTCP(manager);
    NStatManagerAddAllUDP(manager);
}

- (void) start {
    queue = dispatch_queue_create("com.caffeina.netControl", DISPATCH_QUEUE_SERIAL);
    starter = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(monitor) userInfo:nil repeats:YES];
    [self monitor];
    
    printf("Setting timer");
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        NStatManagerQueryAllSources(manager, NULL);
        //NStatManagerQueryAllSourcesDescriptions( manager, NULL );
    });
    dispatch_resume(timer);
}

@end

@implementation SourceRecord

@synthesize source;
@synthesize pid;
@synthesize up;
@synthesize down;
@synthesize next;

+ (SourceRecord *)findBySource:(void *)source within:(NSArray *)array atIndex:(long *)index {
    // if the array is empty, set the insertion point to the first item in the array
    if (array == nil || [array count] == 0) {
        *index = 0;
        return nil;
    }
    
    long low = 0, high = [array count] - 1, mid;
    
    while (low < high) {
        mid = low + ((high - low) / 2);
        if (source > ((SourceRecord *)[array objectAtIndex:mid]).source)
            low = mid + 1;
        else
            high = mid;
    }
    
    *index = low;
    if (*index < [array count] && source > ((SourceRecord *)[array objectAtIndex:*index]).source) (*index)++;
    if (*index < [array count] && source == ((SourceRecord *)[array objectAtIndex:*index]).source) return [array objectAtIndex:*index];
    
    return nil;
}

- (id)initWithSource:(void *)source2 {
    if ((self = [super init])) {
        source = source2;
        pid = 0;
    }
    return self;
}

@end


@implementation ProcessRecord

@synthesize pid;
@synthesize path;
@synthesize app;
@synthesize updated;
@synthesize running;
@synthesize stillRunning;
@synthesize animate;

+ (ProcessRecord *)findByPID:(int)pid within:(NSArray *)array atIndex:(long *)index {
    // if the array is empty, set the insertion point to the first item in the array
    if (array == nil || [array count] == 0) {
        *index = 0;
        return nil;
    }
    
    long low = 0, high = [array count] - 1, mid;
    
    while (low < high) {
        mid = low + ((high - low) / 2);
        if (pid > ((ProcessRecord *)[array objectAtIndex:mid]).pid)
            low = mid + 1;
        else
            high = mid;
    }
    
    *index = low;
    if (*index < [array count] && pid > ((ProcessRecord *)[array objectAtIndex:*index]).pid) (*index)++;
    if (*index < [array count] && pid == ((ProcessRecord *)[array objectAtIndex:*index]).pid) {
        // if the process is no longer running and there's another process with the same PID, return the running one!
        ProcessRecord *process = [array objectAtIndex:*index];
        if (!process.running) {
            for (long index2 = *index + 1; index2 < [array count]; index2++) {
                ProcessRecord *process2 = [array objectAtIndex:index2];
                if (process2.pid != process.pid) break;
                if (process2.running) {
                    *index = index2;
                    return process2;
                }
            }
        }
        
        return process;
    }
    
    return nil;
}

- (id)initWithPID:(pid_t)pid2 {
    if ((self = [super init])) {
        pid = pid2;
        app = nil;
        path = nil;
        updated = 0.0;
        animate = YES;
        running = YES;
        stillRunning = YES;
    }
    return self;
}

@end


@implementation AppRecord

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize updated;
@synthesize animate;

+ (AppRecord *)findByPath:(NSString *)path within:(NSArray *)array atIndex:(long *)index {
    // if the array is empty, set the insertion point to the first item in the array
    if (array == nil || [array count] == 0 || path == nil) {
        *index = 0;
        return nil;
    }
    
    long low = 0, high = [array count] - 1, mid;
    
    while (low < high) {
        mid = low + ((high - low) / 2);
        if ([path compare:((AppRecord *)[array objectAtIndex:mid]).path] == NSOrderedDescending)
            low = mid + 1;
        else
            high = mid;
    }
    
    *index = low;
    if (*index < [array count] && [path compare:((AppRecord *)[array objectAtIndex:*index]).path] == NSOrderedDescending) (*index)++;
    if (*index < [array count] && [path compare:((AppRecord *)[array objectAtIndex:*index]).path] == NSOrderedSame) return ((AppRecord *)[array objectAtIndex:*index]);
    
    return nil;
}

- (id)initWithPath:(NSString *)path2 {
    if ((self = [super init])) {
        self.updated = 0.0;
        self.path = path2;
        self.icon = nil;
        self.animate = YES;
        
        if ([path2 isEqualToString:@"System"]) {
            self.name = @"System";
            
        } else {
            self.name = @"Unknown";
            
            NSBundle *bundle = [NSBundle bundleWithPath:path];
            if (bundle != nil) {
                NSString *app_name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                if (app_name == nil) app_name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
                if (app_name == nil) {
                    // use the file name, minus the .app extension
                    app_name = [[path lastPathComponent] stringByDeletingPathExtension];
                }
                if (app_name != nil) self.name = app_name;
                
                NSString *icon_name, *icon_path;
                if ((icon_name = [bundle objectForInfoDictionaryKey:@"CFBundleIconFile"]) &&
                    (icon_path = [[[bundle resourcePath] stringByAppendingString:@"/"] stringByAppendingString:icon_name])) {
                    if ([[icon_path pathExtension] length] == 0) icon_path = [icon_path stringByAppendingPathExtension:@"icns"];
                }
            }
            
            if (self.icon == nil) {
                // see if we can magically determine the correct icon for it
                NSString *icon_path = nil;
                
                // so far only Notification Center is supported
                if ([self.path hasPrefix:@"/System/Library/CoreServices/NotificationCenter.app"])
                    icon_path = @"/System/Library/PreferencePanes/Notifications.prefPane/Contents/Resources/Notifications.icns";
            }
        }
    }
    return self;
}

+ (AppRecord *) initWithSource: (SourceRecord *)sr {
//    long process_index;
//    pid_t pid = sr.pid;
//    ProcessRecord *process = [ProcessRecord findByPID:pid within:processes atIndex:&process_index];
//    
//    // if the process is no longer running, but the path is the same, merge the processes
//    // and/or maybe show non-running processes as light gray?
//    
//    if (process != nil && !process.running) {
//        char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
//        NSString *path = nil;
//        if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) > 0) {
//            path = [NSString stringWithUTF8String:pathbuf];
//            if ([process.path isEqualToString:path]) process.running = YES;
//        }
//    }
//    
//    if (process == nil || !process.running) {
//        process = [[ProcessRecord alloc] initWithPID:pid];
//        [processes insertObject:process atIndex:process_index];
//        
//        // add a new app if needed
//    check_PID:;
//        long app_index;
//        AppRecord *app = nil;
//        
//        char [PROC_PIDPATHINFO_MAXSIZE];
//        NSString *path = nil;
//        if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) > 0) {
//            path = [NSString stringWithUTF8String:pathbuf];
//            
//            if (process.path == nil)
//                process.path = path;
//            
//            if (path != nil && ![path hasPrefix:@"/System/Library/CoreServices/SystemUIServer.app"]) {
//                // find the parent app
//                
//                // Looks like there are a few simple rules:
//                
//                // 1. first check the manual mapping from processes to apps
//                NSString *path2 = nil;
//                
//                for (id prefix in mapping) {
//                    if ([path hasPrefix:prefix]) {
//                        path2 = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[mapping objectForKey:prefix]];
//                        if (path2 != nil) break;
//                    }
//                }
//                
//                if (path2 != nil) {
//                    app = [AppRecord findByPath:path2 within:apps atIndex:&app_index];
//                    if (app == nil) {
//                        // add this app!
//                        app = [[AppRecord alloc] initWithPath:path2];
//                        app.animate = ![self isPathIgnored:app.path];
//                        [apps insertObject:app atIndex:app_index];
//                    }
//                }
//                
//                // 2. then check for the first occurrence of ".app/" within the process' path
//                if (app == nil) {
//                    NSRange range = [path rangeOfString:@".app/" options:NSBackwardsSearch];
//                    if (range.location != NSNotFound) {
//                        path = [path substringWithRange:NSMakeRange(0, range.location + range.length - 1)];
//                        app = [AppRecord findByPath:path within:apps atIndex:&app_index];
//                        if (app == nil) {
//                            // add this app!
//                            app = [[AppRecord alloc] initWithPath:path];
//                            app.animate = ![self isPathIgnored:app.path];
//                            [apps insertObject:app atIndex:app_index];
//                        }
//                    }
//                }
//                
//                // 3. if that doesn't work either, get the parent process (works for Dock subprocesses and XcodeDeviceMonitor)
//                if (app == nil && pid > 1) {
//                    int new_pid = parent_PID(pid);
//                    if (new_pid != pid) {
//                        pid = new_pid;
//                        goto check_PID;
//                    }
//                }
//                
//                // 4. if all of those things fail, count it as a System process
//                
//            }
//        }
//        
//        if (app == nil) {
//            // set the parent process to the "System" app
//            app = [AppRecord findByPath:@"System" within:apps atIndex:&app_index];
//        }
//        
//        process.animate = ![self isPathIgnored:process.path];
//        process.app = app;
//    }
//    
//    process.stillRunning = YES;
//    
//    if (sr.up < up || sr.down < down) {
//        sr.up = up;
//        sr.down = down;
//        process.updated = CFAbsoluteTimeGetCurrent();
//        
//        // when Loading first launches we have no way of knowing which apps used the network recently,
//        // so give it five seconds to use the network again or it goes straight to the Loaded section
//        if (!started)
//            process.updated -= (LOADED_TIME - 5 * 60);
//        
//        if (process.app != nil)
//            process.app.updated = process.updated;
//    }
//    
    return nil;
}

@end
