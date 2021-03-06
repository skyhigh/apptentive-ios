//
//  ATTaskQueue.m
//  ApptentiveConnect
//
//  Created by Andrew Wooster on 3/21/11.
//  Copyright 2011 Apptentive, Inc.. All rights reserved.
//

#import "ATTaskQueue.h"
#import "ATBackend.h"
#import "ATTask.h"

#define kATTaskQueueCodingVersion 1
// Retry period in seconds.
//!!! Increase for production.
//TODO:
#define kATTaskQueueRetryPeriod 60.0

#define kMaxFailureCount 500

static ATTaskQueue *sharedTaskQueue = nil;

@interface ATTaskQueue (Private)
- (void)setup;
- (void)teardown;
- (void)archive;
- (void)unsetActiveTask;
@end

@implementation ATTaskQueue
+ (NSString *)taskQueuePath {
    return [[[ATBackend sharedBackend] supportDirectoryPath] stringByAppendingPathComponent:@"tasks.objects"];
}

+ (BOOL)serializedQueueExists {
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:[ATTaskQueue taskQueuePath]];
}


+ (ATTaskQueue *)sharedTaskQueue {
    @synchronized(self) {
        if (sharedTaskQueue == nil) {
            if ([ATTaskQueue serializedQueueExists]) {
                sharedTaskQueue = [[NSKeyedUnarchiver unarchiveObjectWithFile:[ATTaskQueue taskQueuePath]] retain];
            }
            if (!sharedTaskQueue) {
                sharedTaskQueue = [[ATTaskQueue alloc] init];
            }
        }
    }
    return sharedTaskQueue;
}

+ (void)releaseSharedTaskQueue {
    @synchronized(self) {
        if (sharedTaskQueue != nil) {
            [sharedTaskQueue archive];
            [sharedTaskQueue release];
            sharedTaskQueue = nil;
        }
    }
}

- (id)init {
    if ((self = [super init])) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        int version = [coder decodeIntForKey:@"version"];
        if (version == kATTaskQueueCodingVersion) {
            tasks = [[coder decodeObjectForKey:@"tasks"] retain];
        } else {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:kATTaskQueueCodingVersion forKey:@"version"];
    [coder encodeObject:tasks forKey:@"tasks"];
}

- (void)dealloc {
    [self teardown];
    [super dealloc];
}


- (void)addTask:(ATTask *)task {
    @synchronized(self) {
        [tasks addObject:task];
        [self archive];
    }
    [self start];
}

- (NSUInteger)count {
	NSUInteger count = 0;
	@synchronized(self) {
		count = [tasks count];
	}
	return count;
}

- (void)start {
    @synchronized(self) {
        if (activeTask) return;
        
        if ([tasks count]) {
            activeTask = [tasks objectAtIndex:0];
            [activeTask addObserver:self forKeyPath:@"finished" options:NSKeyValueObservingOptionNew context:NULL];
            [activeTask addObserver:self forKeyPath:@"failed" options:NSKeyValueObservingOptionNew context:NULL];
            [activeTask start];
        }
    }
}

- (void)stop {
    @synchronized(self) {
        [activeTask stop];
        [self unsetActiveTask];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    @synchronized(self) {
        if (object != activeTask) return;
		ATTask *task = (ATTask *)object;
        if ([keyPath isEqualToString:@"finished"] && [task finished]) {
            [self unsetActiveTask];
            [tasks removeObject:object];
            [self archive];
            [self start];
        } else if ([keyPath isEqualToString:@"failed"] && [task failed]) {
            [self stop];
			task.failureCount = task.failureCount + 1;
			if (task.failureCount > kMaxFailureCount) {
				NSLog(@"Task %@ failed too many times, removing from queue.", task);
				[self unsetActiveTask];
				[tasks removeObject:task];
				[self start];
			} else {
				// Put task on back of queue.
				[task retain];
				[tasks removeObject:task];
				[tasks addObject:task];
				[task release];
                [self archive];
				
				[self performSelector:@selector(start) withObject:nil afterDelay:kATTaskQueueRetryPeriod];
			}
        }
    }
}
@end

@implementation ATTaskQueue (Private)
- (void)setup {
    @synchronized(self) {
        tasks = [[NSMutableArray alloc] init];
    }
}

- (void)teardown {
    @synchronized(self) {
        [self stop];
        [tasks release];
        tasks = nil;
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
}

- (void)unsetActiveTask {
    @synchronized(self) {
        if (activeTask) {
            [activeTask removeObserver:self forKeyPath:@"finished"];
            [activeTask removeObserver:self forKeyPath:@"failed"];
            activeTask = nil;
        }
    }
}

- (void)archive {
    @synchronized(self) {
        [NSKeyedArchiver archiveRootObject:sharedTaskQueue toFile:[ATTaskQueue taskQueuePath]];
    }
}
@end

