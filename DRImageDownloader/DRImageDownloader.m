//
// Created by Dariusz Rybicki on 31/03/15.
// Copyright (c) 2015 Darrarski. All rights reserved.
//

#import "DRImageDownloader.h"

NSUInteger const DRImageDownloaderDefaultMemoryCacheSize = 10 * 1024 * 1024;

@interface DRImageDownloader ()

@property (nonatomic, strong) NSCache *cache;

@end

@implementation DRImageDownloader

+ (instancetype)sharedInstance
{
    static DRImageDownloader *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _useSharedCache = YES;
    }
    return self;
}

- (NSUInteger)memoryCacheSize
{
    return self.cache.totalCostLimit;
}

- (void)setMemoryCacheSize:(NSUInteger)memoryCacheSize
{
    self.cache.totalCostLimit = memoryCacheSize;
}

#pragma mark - Fetching image

- (void)getImageWithUrl:(NSURL *)url loadCompletion:(void (^)(UIImage *))completion
{
    __weak typeof(self) welf = self;
    void (^taskCompletionHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        completion(image);
        if (image) {
            [welf.cache setObject:image forKey:url.absoluteString cost:data.length];
        }
    };
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:taskCompletionHandler] resume];
}

- (void)getImageWithUrl:(NSURL *)url fromCacheCompletion:(void (^)(UIImage *))completion
{
    completion([self.cache objectForKey:url.absoluteString]);
}

- (void)getImageWithUrl:(NSURL *)url fromCacheElseLoadCompletion:(void (^)(UIImage *))completion
{
    [self getImageWithUrl:url fromCacheCompletion:^(UIImage *cachedImage) {
        if (cachedImage) {
            completion(cachedImage);
        }
        else {
            [self getImageWithUrl:url loadCompletion:^(UIImage *loadedImage) {
                completion(loadedImage);
            }];
        }
    }];
}

- (void)getImageWithUrl:(NSURL *)url fromCacheThenLoadCompletion:(void (^)(UIImage *))completion
{
    [self getImageWithUrl:url fromCacheCompletion:^(UIImage *cachedImage) {
        if (cachedImage) {
            completion(cachedImage);
        }
        [self getImageWithUrl:url loadCompletion:^(UIImage *loadedImage) {
            if (loadedImage || !cachedImage) {
                completion(loadedImage);
            }
        }];
    }];
}

#pragma mark -

- (NSCache *)sharedCache
{
    static NSCache *sharedCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[NSCache alloc] init];
        sharedCache.totalCostLimit = DRImageDownloaderDefaultMemoryCacheSize;
    });
    return sharedCache;
}

- (NSCache *)cache
{
    if (self.isUsingSharedCache) {
        _cache = nil;
        return [self sharedCache];
    }
    if (!_cache) {
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = DRImageDownloaderDefaultMemoryCacheSize;
    }
    return _cache;
}

@end