#import "SDImagePlugin.h"
#import "SDWebImageManager.h"
@interface SDTexture : NSObject<FlutterTexture>
@property(nonatomic)CVPixelBufferRef target;
@end

@implementation SDTexture

- (CVPixelBufferRef)copyPixelBuffer {
    // 实现FlutterTexture协议的接口，每次flutter是直接读取我们映射了纹理的pixelBuffer对象
    return _target;
}

- (void)createCVBufferWith:(CVPixelBufferRef )target
{
    _target = target;
}

@end


@interface SDImagePlugin()
{
    NSMapTable <NSNumber *,SDTexture *> *_cacheMap;
}
@property(nonatomic, strong)NSObject <FlutterTextureRegistry> *textures;

@end

@implementation SDImagePlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"s_d_image"
                                     binaryMessenger:[registrar messenger]];
    ///FlutterTextureRegistry
    SDImagePlugin* instance = [[SDImagePlugin alloc] initWithTextures:registrar.textures];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype) initWithTextures:(NSObject<FlutterTextureRegistry> *)textures {
    if (self = [super init]) {
        _textures = textures;
        _cacheMap = [NSMapTable weakToWeakObjectsMapTable];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"getTexture" isEqualToString:call.method] && [call.arguments isKindOfClass:NSString.class]) {
        [self downloadImage:call.arguments result:result];
    }else if ([@"removeTexture" isEqualToString:call.method]) {
        NSNumber *index = call.arguments;
        if ([_cacheMap objectForKey:index]) {
            [self.textures unregisterTexture:index.intValue];
            [_cacheMap removeObjectForKey:index];
            result(@(1));
        }else {
            result([FlutterError errorWithCode:@"-1" message:@"纹理不存在" details:nil]);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)downloadImage:(NSString *)imageUrl result:(FlutterResult)result {
    
    NSURL *url = [NSURL URLWithString:imageUrl];
    if (!url) {
        result([FlutterError errorWithCode:@"-1" message:@"image url error" details:nil]);
        return;
    }
    
    SDTexture *sdTexture = [[SDTexture alloc] init];
    int64_t textureId = [_textures registerTexture:sdTexture];
    [_cacheMap setObject:sdTexture forKey:@(textureId)];
    result(@(textureId));
    [SDWebImageManager.sharedManager loadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        if (finished && !error) {
            [self showImage:image textureId:textureId];
        }
    }];
}

- (void)showImage:(UIImage *)image textureId:(int64_t)textureId{
    
    SDTexture *texture =  [_cacheMap objectForKey:@(textureId)];
    if (texture) {
        texture.target = [self CVPixelBufferRefFromUiImage:image];
        [self.textures textureFrameAvailable:textureId];
        NSLog(@"2--%lld",textureId);
    }
}


- (CVPixelBufferRef)CVPixelBufferRefFromUiImage:(UIImage *)img {

    CGImageRef image = [img CGImage];
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);

    NSDictionary *options = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey :  @YES,
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]
    };
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) options, &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;

    CGContextRef context = CGBitmapContextCreate(pxdata, frameWidth, frameHeight, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace, bitmapInfo);
    NSParameterAssert(context);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    return pxbuffer;
}


@end
