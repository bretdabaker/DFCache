/*
 The MIT License (MIT)
 
 Copyright (c) 2013 Alexander Grebenyuk (github.com/kean).
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "DFCache+Extensions.h"
#import "DFCache+Tests.h"
#import "DFTesting.h"
#import <XCTest/XCTest.h>

@interface TDFCache_Extensions : XCTestCase

@end

@implementation TDFCache_Extensions {
    DFCache *_cache;
}

- (void)setUp {
    [super setUp];
    
    static NSUInteger _index = 0;
    
    NSString *cacheName = [NSString stringWithFormat:@"_dt_extenstions_testcase_%i", _index];
    _cache = [[DFCache alloc] initWithName:cacheName];
    _index++;
}

- (void)tearDown {
    [super tearDown];
    
    [_cache removeAllObjects];
    _cache = nil;
}

#pragma mark - NSData

- (void)testCachedDataForKeyAsynchronous {
    NSString *object = @"value";
    NSString *key = @"key";
    
    [_cache storeObject:object forKey:key cost:0 encode:DFCacheEncodeNSCoding];
    
    __block BOOL isWaiting = YES;
    [_cache cachedDataForKey:key completion:^(NSData *data) {
        XCTAssertEqualObjects(object, DFCacheDecodeNSCoding(data));
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

- (void)testCachedDataForKeySynchronous {
    NSString *object = @"value";
    NSString *key = @"key";
    
    [_cache storeObject:object forKey:key cost:0 encode:DFCacheEncodeNSCoding];
    NSData *data = [_cache cachedDataForKey:key];
    XCTAssertEqualObjects(object, DFCacheDecodeNSCoding(data));
}

- (void)testStoreDataForKey {
    size_t dataSize = 10000;
    int *buffer = malloc(dataSize);
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:dataSize];
    
    [_cache storeData:data forKey:@"key"];
    NSData *cachedData = [_cache cachedDataForKey:@"key"];
    XCTAssertTrue([data length] == [cachedData length]);
}

- (void)testCachedDataForMultipleKeys {
    NSDictionary *strings;
    [_cache storeStringsWithCount:5 strings:&strings];
    NSArray *keys = [strings allKeys];
    
    __block BOOL isWaiting = YES;
    [_cache cachedDataForKeys:keys completion:^(NSDictionary *data) {
        for (NSString *key in keys) {
            XCTAssertNotNil(data[key]);
        }
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

#pragma mark - Objects

- (void)testCachedObjectsForKeys {
    NSDictionary *strings;
    [_cache storeStringsWithCount:5 strings:&strings];
    NSArray *keys = [strings allKeys];
    
    __block BOOL isWaiting = YES;
    [_cache cachedObjectsForKeys:keys decode:DFCacheDecodeNSCoding cost:nil completion:^(NSDictionary *objects) {
        for (NSString *key in keys) {
            XCTAssertTrue([objects[key] isEqualToString:strings[key]]);
        }
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

- (void)testCachedObjectsForKeysFromDisk {
    NSDictionary *strings;
    NSArray *keys;
    _cache.memoryCache = nil;
    
    [_cache storeStringsWithCount:5 strings:&strings];
    keys = [strings allKeys];
    
    __block BOOL isWaiting = YES;
    [_cache cachedObjectsForKeys:keys decode:DFCacheDecodeNSCoding cost:nil completion:^(NSDictionary *objects) {
        for (NSString *key in keys) {
            XCTAssertTrue([objects[key] isEqualToString:strings[key]]);
        }
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

- (void)testCachedObjectForAnyKey {
    NSDictionary *strings;
    [_cache storeStringsWithCount:5 strings:&strings];
    NSArray *keys = [strings allKeys];
    
    [_cache removeObjectForKey:keys[0]];
    
    __block BOOL isWaiting = YES;
    [_cache cachedObjectForAnyKey:keys decode:DFCacheDecodeNSCoding cost:nil completion:^(id object, NSString *key) {
        XCTAssertTrue([key isEqualToString:keys[1]]);
        XCTAssertTrue([object isEqualToString:strings[keys[1]]]);
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

- (void)testCachedObjectForAnyKeyFromDisk {
    NSDictionary *strings;
    NSArray *keys;
    _cache.memoryCache = nil;
    
    [_cache storeStringsWithCount:5 strings:&strings];
    keys = [strings allKeys];

    [_cache removeObjectForKey:keys[0]];
    
    __block BOOL isWaiting = YES;
    [_cache cachedObjectForAnyKey:keys decode:DFCacheDecodeNSCoding cost:nil completion:^(id object, NSString *key) {
        XCTAssertTrue([key isEqualToString:keys[1]]);
        XCTAssertTrue([object isEqualToString:strings[keys[1]]]);
        isWaiting = NO;
    }];
    
    DWARF_TEST_WAIT_WHILE(isWaiting, 10.f);
}

#pragma mark - Helpers

- (void)_assertContainsObjectsForKeys:(NSArray *)keys objects:(NSDictionary *)objects {
    for (NSString *key in keys) {
        {
            NSString *object = [_cache.memoryCache objectForKey:key];;
            XCTAssertNotNil(object, @"Memory cache: no object for key %@", key);
            XCTAssertEqualObjects(objects[key], object);
        }
        
        {
            id object = [_cache cachedObjectForKey:key decode:DFCacheDecodeNSCoding cost:nil];
            XCTAssertNotNil(object, @"Disk cache: no object for key %@", key);
            XCTAssertEqualObjects(objects[key], object);
        }
    }
}

- (void)_assertDoesntContainObjectsForKeys:(NSArray *)keys objects:(NSDictionary *)objects {
    for (NSString *key in keys) {
        {
            NSString *object = [_cache.memoryCache objectForKey:key];
            XCTAssertNil(object, @"Memory cache: contains object for key %@", key);
        }
        
        {
            id object = [_cache cachedObjectForKey:key decode:DFCacheDecodeNSCoding cost:nil];
            XCTAssertNil(object, @"Disk cache: contains object for key %@", key);
        }
    }
}
 
@end