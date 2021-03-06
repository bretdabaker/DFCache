/*
 The MIT License (MIT)
 
 Copyright (c) 2013 Alexander Grebenyuk (github.com/kean).
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "DFCache.h"
#import <XCTest/XCTest.h>

@interface TDFCache_UIImage : XCTestCase

@end

@implementation TDFCache_UIImage {
    DFCache *_cache;
}

- (void)setUp {
    [super setUp];
    
    static NSUInteger _index = 0;
    
    NSString *cacheName = [NSString stringWithFormat:@"_dt_testcase_%lu", (unsigned long)_index];
    _cache = [[DFCache alloc] initWithName:cacheName];
    _index++;
}

- (void)tearDown {
    [super tearDown];
    
    [_cache removeAllObjects];
    _cache = nil;
}

#pragma mark - UIImage

- (void)testWriteWithoutDataAndReadAsync {
    UIImage *image = [self _testImage];
    NSString *key = @"key";
    
    [_cache storeObject:image forKey:key];
    [_cache.memoryCache removeAllObjects];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"read"];
    [_cache cachedObjectForKey:key completion:^(id object) {
        [self _assertImage:image isEqualImage:object];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:3.0 handler:nil];
}

- (void)testWriteWithDataAndReadSync {
    UIImage *image = [self _testImage];
    NSData *data = UIImagePNGRepresentation(image);
    NSString *key = @"key";
    
    [_cache storeObject:image forKey:key data:data];
    [_cache.memoryCache removeAllObjects];
    
    UIImage *cachedImage = [_cache cachedObjectForKey:key];
    [self _assertImage:image isEqualImage:cachedImage];
}

#pragma mark - Helpers

- (UIImage *)_testImage {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"zebrainpastelfield" ofType:@"png"];
    return [UIImage imageWithContentsOfFile:path];
}

- (void)_assertImage:(UIImage *)img1 isEqualImage:(UIImage *)img2 {
    XCTAssertNotNil(img1);
    XCTAssertNotNil(img2);
    XCTAssertTrue(img1.size.width * img1.scale ==
                  img2.size.width * img2.scale);
    XCTAssertTrue(img1.size.height * img1.scale ==
                  img2.size.height * img2.scale);
}

@end
