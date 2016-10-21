//
//  NSObject+netstats.h
//  netControl
//
//  Created by Ani Sinanaj on 03/10/16.
//  Copyright © 2016 Ani Sinanaj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetStats : NSObject

//@property NSMutableArray *apps;
//@property NSMutableArray *processes;
//@property NSMutableArray *sources;
//@property NSMutableArray *ignore;
//@property NSDictionary *mapping;

@property NSTimer *starter;
@property BOOL started;

@end

@interface AppRecord : NSObject

@property NSImage *icon;
@property NSString *name;
@property NSString *path;
@property double updated;
@property BOOL animate;

+ (AppRecord *)findByPath:(NSString *)path within:(NSArray *)array atIndex:(long *)index;

- (id)initWithPath:(NSString *)path;
@end

@interface SourceRecord : NSObject

@property void *source;
@property pid_t pid;
@property long up;
@property long down;
@property SourceRecord *next;

+ (SourceRecord *)findBySource:(void *)source within:(NSArray *)array atIndex:(long *)index;

- (id)initWithSource:(void *)source;
@end


@interface ProcessRecord : NSObject

@property int pid;
@property NSString *path;
@property AppRecord *app;
@property double updated;
@property BOOL animate;
@property BOOL running;
@property BOOL stillRunning;

+ (ProcessRecord *)findByPID:(int)pid within:(NSArray *)array atIndex:(long *)index;

- (id)initWithPID:(pid_t)pid;
@end
