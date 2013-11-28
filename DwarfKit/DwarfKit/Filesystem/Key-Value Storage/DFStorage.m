/*
 The MIT License (MIT)
 
 Copyright (c) 2013 Alexander Grebenyuk (github.com/kean).
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "DFCrypto.h"
#import "DFStorage.h"
#import "dwarf_private.h"


@implementation DFStorage {
    dispatch_queue_t _ioQueue;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    DWARF_DISPATCH_RELEASE(_ioQueue);
}

- (id)initWithPath:(NSString *)path {
    if (self = [super init]) {
        if (!path.length) {
            [NSException raise:@"DFCache" format:@"Attempting to initialize cache without root folder path"];
        }
        _path = path;
        
        [self _createRootFolder];
        
        _ioQueue = dispatch_queue_create("_df_storage_io_queue", DISPATCH_QUEUE_SERIAL);
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(applicationWillResignActive:) name:DFApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

#pragma mark - Read

- (void)readDataForKey:(NSString *)key completion:(void (^)(NSData *))completion {
    if (!completion) {
        return;
    }
    if (!key) {
        _dwarf_callback(completion, nil);
        return;
    }
    dispatch_async(_ioQueue, ^{
        NSData *data = [self _dataForKey:key];
        _dwarf_callback(completion, data);
    });
}

- (NSData *)readDataForKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    __block NSData *data;
    dispatch_sync(_ioQueue, ^{
        data = [self _dataForKey:key];
        
    });
    return data;
}

- (void)readBatchForKeys:(NSArray *)keys completion:(void (^)(NSDictionary *))completion {
    if (!completion) {
        return;
    }
    if (!keys.count) {
        _dwarf_callback(completion, nil);
        return;
    }
    dispatch_async(_ioQueue, ^{
        NSMutableDictionary *batch = [NSMutableDictionary new];
        for (NSString *key in keys) {
            NSData *data = [self _dataForKey:key];
            if (data) {
                batch[key] = batch;
            }
        }
        _dwarf_callback(completion, batch);
    });
}

- (BOOL)containsDataForKey:(NSString *)key {
    if (!key) {
        return NO;
    }
    return [self _fileExistsForKey:key];
}

#pragma mark - Write

- (void)writeData:(NSData *)data forKey:(NSString *)key {
    if (!data || !key) {
        return;
    }
    dispatch_async(_ioQueue, ^{
        [self _writeData:data forKey:key];
    });
}

- (void)writeDataSynchronously:(NSData *)data forKey:(NSString *)key {
    if (!data || !key) {
        return;
    }
    dispatch_sync(_ioQueue, ^{
        [self _writeData:data forKey:key];
    });
}

- (void)writeBatch:(NSDictionary *)batch {
    if (!batch.count) {
        return;
    }
    dispatch_async(_ioQueue, ^{
        [batch enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [self _writeData:obj forKey:key];
        }];
    });
}

#pragma mark - Remove

- (void)removeDataForKeys:(NSArray *)keys {
    if (!keys) {
        return;
    }
    dispatch_async(_ioQueue, ^{
        for (NSString *key in keys) {
            [self _deleteDataForKey:key];
        }
    });
}

- (void)removeDataForKey:(NSString *)key {
    if (key) {
        [self removeDataForKeys:@[key]];
    }}

- (void)removeAllData {
    dispatch_async(_ioQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
        [self _createRootFolder];
    });
}

#pragma mark - Disk I/O

- (void)_createRootFolder {
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:_path]) {
        [manager createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (NSString *)_pathWithKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    NSString *hash = dwarf_md5([key UTF8String]);
    return [_path stringByAppendingPathComponent:hash];
}

- (NSData *)_dataForKey:(NSString *)key {
    NSString *filepath = [self _pathWithKey:key];
    // TODO: Uncached?
    NSData *data = [NSData dataWithContentsOfFile:filepath options:NSDataReadingUncached error:nil];
    if (data && _diskCapacity != DFStorageDiskCapacityUnlimited) {
        [self _touchFileForKey:key];
    }
    return data;
}

- (void)_touchFileForKey:(NSString *)key {
    NSString *filepath = [self _pathWithKey:key];
    NSURL *url = [NSURL fileURLWithPath:filepath];
    [url setResourceValue:[NSDate date] forKey:NSURLAttributeModificationDateKey error:nil];
}

- (void)_writeData:(NSData *)data forKey:(NSString *)key {
    NSString *filepath = [self _pathWithKey:key];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createFileAtPath:filepath contents:data attributes:nil];
}

- (BOOL)_fileExistsForKey:(NSString *)key {
    NSString *filepath = [self _pathWithKey:key];
    return [[NSFileManager defaultManager] fileExistsAtPath:filepath];
}

- (void)_deleteDataForKey:(NSString *)key {
    NSString *filepath = [self _pathWithKey:key];
    [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
}

#pragma mark - Maintenance

- (_dwarf_bytes)contentsSize {
    _dwarf_bytes contentsSize = 0;
    NSArray *contents = [self contentsWithResourceKeys:@[NSURLFileAllocatedSizeKey]];
    for (NSURL *fileURL in contents) {
        NSNumber *fileSize;
        [fileURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:NULL];
        contentsSize += [fileSize unsignedLongLongValue];
    }
    return contentsSize;
}

- (NSArray *)contentsWithResourceKeys:(NSArray *)keys {
    NSURL *rootURL = [NSURL fileURLWithPath:_path isDirectory:YES];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtURL:rootURL includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
}

- (void)cleanup {
    if (_diskCapacity == DFStorageDiskCapacityUnlimited) {
        return;
    }
    dispatch_async(_ioQueue, ^{
        [self _cleanup];
    });
}

- (void)_cleanup {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *resourceKeys = @[ NSURLContentModificationDateKey, NSURLFileAllocatedSizeKey ];
    NSArray *contents = [self contentsWithResourceKeys:resourceKeys];
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    _dwarf_bytes currentSize = 0;
    for (NSURL *fileURL in contents) {
        NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
        if (resourceValues) {
            files[fileURL] = resourceValues;
            NSNumber *fileSize = resourceValues[NSURLFileAllocatedSizeKey];
            currentSize += [fileSize unsignedLongLongValue];
        }
    }
    if (currentSize < _diskCapacity) {
        return;
    }
    const _dwarf_bytes desiredSize = _diskCapacity * _cleanupRate;
    NSArray *sortedFiles = [files keysSortedByValueWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
    }];
    for (NSURL *fileURL in sortedFiles) {
        if (currentSize < desiredSize) {
            break;
        }
        if ([manager removeItemAtURL:fileURL error:nil]) {
            NSNumber *fileSize = files[fileURL][NSURLFileAllocatedSizeKey];
            currentSize -= [fileSize unsignedLongLongValue];
        }
    }
}

#pragma mark - Application Notifications

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self cleanup];
}

@end
